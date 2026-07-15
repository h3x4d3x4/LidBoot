# Lid Boot — UI/UX Design Handoff (pass 3)

**Date:** 2026-07-15 · **App state:** v0.2.0, shipped and live (see `STATUS.md`). **Nothing in this document is implemented.** This is a researched audit + implementation guide for the agent doing the design pass. Two functional audits already happened (`HANDOFF.md`, historical) — this one is purely visual/UX, grounded in research on best-in-class comparable apps and the macOS 26 design language.

## Read first

1. `docs/STATUS.md` — what's proven, what's open, the safety invariants. **The "don't reopen" decisions there bind this pass too.**
2. This file, fully, before touching code. The research digest resolves several conflicts (e.g. "Cindori dark" vs "Tahoe glass") — don't re-derive those choices.

## How to see what you're changing (tooling that already works)

- Build/run: `xcodegen generate && xcodebuild -project LidBoot.xcodeproj -scheme LidBoot -configuration Debug -derivedDataPath ./build build`. Tests: `swift test` (35, <1s).
- **Screenshot a single window** without capturing the user's screen: compile the CGWindowList helper in the session scratchpad (or re-create: list windows, filter owner, `screencapture -x -o -l <id>`). **Gotcha: the window owner name is now `"Lid Boot"` (with space)** — a `"LidBoot"` filter finds nothing; this burned an hour once already.
- **Light mode per-app:** `defaults write com.lidboot.LidBoot NSRequiresAquaSystemAppearance -bool yes` → relaunch → screenshot → `defaults delete …`. (This trick becomes obsolete once the appearance picker below exists — use the picker instead.)
- **pt-PT per-app:** `defaults write com.lidboot.LidBoot AppleLanguages -array "pt-PT"` → relaunch → screenshot → delete. **Every layout change must be screenshotted in pt-PT** — Portuguese runs ~25% longer and has already caught one truncation bug.
- **Unsupported states (Debug only):** `open build/.../LidBoot.app --args -simulateUnsupported notALaptop|notAppleSilicon|osTooOld`.
- The popover and Settings cannot be opened programmatically here (no Accessibility permission). Screenshot the window; for popover/Settings changes, ask the user to open them and eyeball, or capture via `winid2` if they're on screen.
- **After any privileged-write testing: the machine must end at factory default** (`nvram BootPreference` → "data was not found"). The user's Mac is not a test bench.

## Research digest (two independent web-research passes, 2026-07-15)

### A. What best-in-class simple utilities do (AlDente, Sindre Sorhus apps, KeepingYouAwake, Ice, MonitorControl, Cindori)

The ten patterns, condensed — full reasoning lives in the session, the *decisions* are here:

1. **Icon = state display, popover = control, window = explainer.** AlDente ships four live-status menu bar icons so you never open the popover just to check. We already have three states (`laptopcomputer`, `.slash`, warning badge) + tooltip — keep, refine (see W6).
2. **Popover: hero card per switch, nothing else.** 300–340pt wide. Tile (28–32pt) + 13pt semibold label + 11pt secondary outcome line + trailing toggle. Configuration lives in Settings, not the popover (Sorhus rule). We're close; our popover still shows a visible Quit + two footer links (see W4).
3. **Outcome-phrased state lines** under each switch, updating instantly. Already done ("Plugging in just charges it") — keep.
4. **Hardware toggle = three visual states** (off / in-flight / on), control position always equals *actual* hardware state (MonitorControl rule). Already done via `pending` + read-back. Keep.
5. **Settings: toolbar tabs, fixed ~450–500pt, `.formStyle(.grouped)`.** Ours is 420pt with `.tabItem` — right shape, needs width + polish (W5).
6. **Zero-page onboarding.** No wizard. The one privilege (admin password per change) is already announced inline. Keep.
7. **Mechanism behind a "?" hover, never in primary copy** (AlDente pattern). We have no mechanism-explainer in-app at all — the `BootPreference`/nvram story is only in the README (W7).
8. **Cindori aesthetic, distilled:** saturated 2-stop gradients confined to small shapes (icon tiles, one hero glow) — "jewelry, not wallpaper." Cards at low-opacity white with 1px white-10% border, 10–12pt radius, matte space between. **Never gradient text or full-bleed gradient backgrounds.**
9. **System typography scale, not invented sizes.** We fail this hard: **35 hard-coded `.system(size:)` uses across 9 files** (W2).
10. **One accent, semantic color discipline.** Red only for failure; the toggle's on-tint is the confirmation. We're mostly compliant; the green "modified" language died in pass 2. Keep it dead.

**Anti-patterns the reviewers name:** settings inside the popover; colored/non-template menu bar icons; resizable tiny windows; modal/notification confirmations for toggles; jargon in primary UI; "bare" unstyled forms; 3-page onboarding; split-brain state between popover and window; gradient wallpaper.

### B. macOS 26 (Tahoe) design language — and where it overrides A

We already build with Xcode 26.5 against the macOS 26 SDK, so **standard chrome (popover panel, Settings window, menus, buttons) already renders in Liquid Glass.** The work is mostly *removing* things that fight it:

1. **Icon jail — the most urgent visual item.** macOS 26 shrinks any non-full-bleed icon onto a gray squircle tile ("icon jail", widely mocked). **Our icon is a rounded-rect drawn with a 9.77% transparent inset → it is a jail candidate.** Fix: build a layered `AppIcon.icon` in **Icon Composer** (ships with Xcode 26; layered squircle, system generates default/dark/clear/tinted modes) and keep the existing xcassets set as the macOS 15 fallback — `actool` handles both from one project. Layers: background = the blue→purple gradient full-bleed; foreground = white laptop glyph + notch as a separate depth group.
2. **Opaque backgrounds are the #1 dated tell.** `MainWindowView.swift:28` has `.background(.background)` — remove it; let the system window background through. Never paint a background into the popover (we don't — keep it that way).
3. **Hard-coded font sizes are the #2 tell.** Sweep all 35 to semantic styles: `.title2` (hero title), `.headline` (row titles), `.body` (controls), `.subheadline`/`.callout` + `.secondary` (captions/state lines), `.caption`/`.footnote` + `.tertiary` (version, fine print). Files: Diagnostics, LaunchAtLogin, MenuView, MainWindowView, ModePicker, UnsupportedView, Updater, SharedViews, SettingsView.
4. **Corner radii up.** Our cards use 5–11pt; Tahoe wants 10–16pt with `.continuous`, and on 26 `ConcentricRectangle`/`.rect(corners: .concentric(minimum:))` for shapes near window corners. Availability-gate the concentric API (`#available(macOS 26,*)`), plain 12pt otherwise.
5. **Glass APIs: use almost none.** HIG: custom `.glassEffect()` "sparingly, only the most important functional elements" — for an app this size the right number is **zero or one**. Do not wrap cards in glass; never glass-on-glass.
6. **Menu bar item:** SF Symbols auto-template — already correct. Menus on 26 show item icons; our popover footer buttons could adopt `Label(_:systemImage:)` consistently.
7. **Conflict resolution A8 vs B2:** Cindori's opaque near-black base **loses** to system materials. Keep the Cindori *gradients* on tiles and (optionally) one blurred hero glow in About; drop any hard-coded dark background. The app must look right over glass in both appearances.

## Current-state inventory (what actually ships in 0.2.0)

| Surface | File | State |
|---|---|---|
| Window (380pt fixed) | `MainWindowView.swift` | Hero tile w/ glow ring, toggles card (`.quaternary.opacity(0.5)`, 10pt), password notice, conditional caveats, Restore Default + Copy Terminal Command, version footer. Opaque `.background(.background)` at :28. |
| Popover (320pt) | `MenuView.swift` | Header + summary, same `BootToggles`, caveats, footer: "Open Lid Boot…", "Settings…", "Quit" (hover-highlight FooterButtons). |
| Settings (420pt TabView) | `SettingsView.swift` | General (mode picker + launch at login), Updates (Sparkle), About (GridPush pattern + diagnostics + Ko-fi). |
| Shared | `SharedViews.swift` | `IconTile` (gradient + glass stroke), `SettingRow` (hover, a11y-combined, `isKnown` dash state), `NoticeRow`, caveats. `Palette.lid/.power` gradients. |
| Menu bar | `LidBootApp.swift` | 3-state SF Symbol + `.help`/a11y label = full summary. |
| Icon | `Assets.xcassets` | Programmatic PNG set, rounded-rect, **not full-bleed** → icon-jail risk on 26. Generator script exists in session scratchpad only (regenerate if needed: gradient = `Palette.lid`). |
| Localization | `Localizable.xcstrings` | en (source) + pt-PT, ~74 keys. **Every new string needs a pt-PT value in the same commit.** |

Reference screenshots from today (dark + light, factory-default state) are in the session scratchpad (`audit_dark.png`, `audit_light.png`); re-take rather than trust if in doubt.

## Work items, prioritized

Each item: what, why, exactly how, and its acceptance check. Commit per item or per tight group; push to `main` (private repo). **pt-PT + dark + light screenshots are part of "done" for anything visual.**

### P0 — correctness of appearance (do these first)

**W1 — Escape icon jail: Icon Composer layered icon.**
Create `AppIcon.icon` (Icon Composer, ships with Xcode 26): background layer = full-bleed linear gradient, exactly `Palette.lid` (RGB 0.36/0.55/1.0 → 0.55/0.40/1.0, top-left→bottom-right); foreground depth group = white laptop outline + notch tab + base bar (re-derive geometry from the scratchpad `makeicon.swift`, or trace the current 1024px PNG). Add to the Xcode project (xcodegen: add the `.icon` file to the target's resources; verify `actool` picks it up — if xcodegen fights it, document the manual pbxproj step in a comment). Keep the existing xcassets `AppIcon` as the 15-fallback. **Accept:** on macOS 26, Dock/Finder icon is full-bleed squircle (no gray tile), and dark/tinted modes render; on the 15 SDK path, `.icns` still present in the bundle.

**W2 — Typography sweep: 35 hard-coded sizes → semantic styles.**
Map: 22pt→`.title2.bold()`, 17pt→`.title3.weight(.semibold)`, 14pt→`.headline`, 12–13pt→`.body`/`.headline` per role, 11–11.5pt→`.subheadline`, 10–10.5pt→`.caption`/`.footnote`. Weights via `.fontWeight()`, colors stay semantic. Do it file-by-file with a screenshot after each of: window, popover, Settings×3 tabs. **Accept:** `grep -rn "\.system(size:" App/ | wc -l` → 0 (monospaced/diagnostic text may keep `.monospaced()` styles, not sizes); no layout breakage in pt-PT.

**W3 — Kill the opaque window background + radius pass.**
Remove `.background(.background)` (`MainWindowView.swift:28`). Card radii: toggles card 10→12pt; `IconTile` corner stays proportional (7pt at 26pt tile is fine — tiles are jewelry, not chrome). Gate `ConcentricRectangle` behind `#available(macOS 26,*)` only if it's a one-liner shim; skip otherwise. **Accept:** window shows the system background (subtle translucency on 26) in both appearances; nothing double-paints behind the grouped forms in Settings.

**W4 — Appearance picker: System / Light / Dark, default System.** *(Explicit user requirement.)*
Settings › General, above the mode picker. Storage: `@AppStorage("appearance")` enum (`system|light|dark`). Apply at launch (AppDelegate, before first frame, same spot as activation policy) and on change:
```swift
NSApp.appearance = { switch pref { case .system: nil; case .light: NSAppearance(named: .aqua); case .dark: NSAppearance(named: .darkAqua) } }()
```
Localize the three labels (pt-PT: "Sistema"/"Claro"/"Escuro"). This also supersedes the `NSRequiresAquaSystemAppearance` screenshot trick — note that in the verification section of STATUS when done. **Accept:** switching updates the window, popover and Settings live, persists across relaunch, default is System; screenshots of all three.

### P1 — structure & polish

**W5 — Settings window to 2026 shape.**
Width 420→~500pt fixed; each tab body already `Form`/`.formStyle(.grouped)` for General+Updates — make About consistent (it's a hand-built VStack; acceptable as a hero pane, but move Report-a-Problem into the grouped form idiom). Tab labels keep SF Symbols. **Do not** convert to a sidebar (needs 5+ panes to justify — research consensus). **Accept:** no control clipped in pt-PT; height hugs content per tab.

**W6 — Popover footer: demote Quit, promote the gear.**
Current footer: "Open Lid Boot…" · "Settings…" · "Quit" — three text buttons. Target (Sorhus/AlDente): left = "Open Lid Boot…" (`Label`, `arrow.up.forward.app`), right = gear icon button → menu containing Settings…, Check for Updates…, Quit (⌘Q shown). **Constraint that overrides the pure pattern: in menu-bar-only mode this popover is the ONLY reachable UI** — Quit and Settings must remain reachable from it (that's why they exist; see `STATUS.md` "no Cmd-, in accessory mode"). A gear *menu* satisfies both. **Accept:** in `.menuBar` mode with the window closed, you can still reach Settings and Quit entirely from the popover.

**W7 — "How it works" hover/info popover (AlDente `?` pattern).**
One small `?`/`info.circle` button beside the toggles card header (window) and in the popover header row. Popover content (localized): 3 short lines — changes Apple's documented firmware setting (`BootPreference`); survives restarts, reversible anytime, Restore Default removes it entirely; only applies from full shutdown — sleep/wake unaffected. This moves the mechanism out of permanent caveat rows: with it in place, **collapse `StartupCaveats` to the single keyboard line** (the shutdown-vs-sleep line moves into the info popover), reducing permanent text. **Accept:** caveat block shrinks to one line + password notice; info popover reads correctly in pt-PT.

**W8 — Menu bar icon: adopt `laptopcomputer.and.arrow.down` style review + tooltip check.**
Keep the 3-state scheme, but verify glyph semantics with fresh eyes at 100% scale in the actual menu bar (the `.slash` variant must not read as "app disabled"). If ambiguous, candidates: filled variant for suppressed, outline for default. Small item; do it while in the file. **Accept:** side-by-side screenshot of both states in the menu bar, user eyeballs it.

### P2 — the one flourish (optional, last)

**W9 — About hero glow, Cindori-style, gated.**
One blurred radial-gradient blob cluster behind the About pane's icon tile only (per research: blur radius ∝ view size, overlay-blend highlight blob, slow drift optional). Static is fine; skip animation if it takes >30 min. Never behind text. **Accept:** looks intentional in both appearances; zero cost to any other surface.

**W10 — Popover width/pt-PT audit.** 320pt with pt-PT strings is tight; if any outcome line wraps awkwardly after W2, widen to 340pt (research range 300–340).

## Hard constraints (violating any of these = failed pass)

- **No behavioral changes to the NVRAM path.** `LidBootCore` is out of scope entirely. UI files only, plus Settings additions.
- **Deployment target stays macOS 15.** Every 26-only API behind `#available`, with a sane 15 fallback. Test nothing on the assumption of 26.
- **Don't touch:** `LSUIElement` + activation-policy promotion, `WindowOpener` (registered from two places on purpose), the `restorationBehavior` warning comment in `LidBootApp.swift` (do NOT add `.restorationBehavior(.disabled)` — it suppresses the window entirely; measured, not theoretical), `MenuBarExtra(isInserted:)` handling, the mode-picker's menu-bar-only confirm alert.
- **Every user-visible string** goes through `String(localized:)` at a `Text(_: String)` boundary (see `Localization.swift` header comment for why) **and gets a pt-PT entry in `Localizable.xcstrings` in the same commit.**
- **No new dependencies.** Sparkle is the only third-party package and stays that way.
- Popover keeps Quit + Settings reachable (accessory-mode lifeline — see W6).
- Don't rename user-facing "Lid Boot" / internal "LidBoot" — the split is deliberate (README "Naming").

## Verification protocol (run after the last item)

1. `swift test` and `xcodebuild … test` — 35+ green (new tests only if you added logic, e.g. appearance persistence).
2. Screenshot matrix: window + popover + Settings×3, in dark and light, en and pt-PT (8–12 images). Unsupported state via `-simulateUnsupported notALaptop`, one shot.
3. Release build: `grep -c simulateUnsupported` on the Release binary → 0; `build-dmg.sh` gates pass (hardened runtime, no sandbox, Developer ID).
4. Icon: Dock + Finder on macOS 26 — full-bleed, no gray tile; check dark mode icon variant.
5. `nvram BootPreference` → `data was not found` (machine restored).
6. Update `docs/STATUS.md` (shipped section + any new gaps) — stale docs actively mislead; this file gets a one-line "implemented in <commit>" header note per completed item.

## Suggested order

W2 → W3 (mechanical, unblock everything visual) → W4 (user ask) → W1 (icon; independent, can parallelize) → W5 → W6 → W7 → W8 → W10 → W9. Version bump to 0.3.0 at the end; it's a visible-change release worth testing the Sparkle update path with (STATUS lists "update path untested" — publishing 0.3.0 via `scripts/publish-release.sh 0.3.0 3` and watching a 0.2.0 install offer the update would close that gap too).
