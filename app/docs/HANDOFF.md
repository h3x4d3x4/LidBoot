# LidBoot — Audit & Implementation Handoff

**Date:** 2026-07-15 · **State:** v0.1.0 builds, runs, and works end-to-end on the target machine (MacBookPro18,1, M1 Pro, macOS 26.5.2). This document is a full audit of what should improve, written for an implementing agent. Nothing in here is implemented yet.

## Read this first — context you need

- **What the app does:** GUI for the Apple-documented NVRAM variable `BootPreference` (Apple silicon + macOS 15+ only), which controls whether a MacBook powers on when the lid opens / power connects. Two toggles map to four states; "both on" *deletes* the variable (factory state) rather than writing a value. See `README.md` for the 2×2 table.
- **Privilege model (settled, do not reopen):** reads are unprivileged (IOKit, `IODeviceTree:/options`); writes run `/usr/sbin/nvram` as root via `NSAppleScript` `do shell script … with administrator privileges`. This was proven working from a Developer ID-signed, hardened-runtime, non-sandboxed app on macOS 26 before any UI was built. **No SMAppService/root daemon** — deliberately rejected (set-once setting; a persistent root helper is unjustified attack surface).
- **Safety invariants (never weaken):** only `BootPreference` is ever touched; never `auto-boot` (bricks Apple silicon boot); commands come from the closed enum `NVRAMCommand` — no string interpolation of user input; absolute path `/usr/sbin/nvram`; every write is read-back-verified. `testNoCommandEverTouchesAnotherNVRAMVariable` enforces this — keep it green.
- **Known product limitation (communicate, can't fix):** key-press/trackpad still powers the Mac on; only lid-open and power-connect are suppressible. The UI states this; keep it visible.
- **House conventions (already followed, keep):** XcodeGen `project.yml` → `.xcodeproj` (regenerate after target changes: `xcodegen generate`); local SPM package `LidBootCore` for logic; team `632VXL3W66`; hardened runtime ON, sandbox OFF (required — sandbox blocks both IOKit options read and the privileged write, so no Mac App Store, Developer ID only).
- **Verified in this session, don't re-litigate:** light mode renders correctly (checked via `NSRequiresAquaSystemAppearance` trick); menu bar icon invisible on the dev machine is **not a bug** — the menu bar is full and notched macOS silently drops overflow items (a minimal 8-line MenuBarExtra repro also didn't show). This motivates finding U1.
- **Build/run:** `xcodegen generate && xcodebuild -project LidBoot.xcodeproj -scheme LidBoot -configuration Debug -derivedDataPath ./build build`; tests: `swift test` (14 pass, <1s, no root needed).
- **Machine state:** the dev machine's NVRAM is at factory default (variable absent). Any manual testing that writes it must end with both toggles ON (or `sudo nvram -d BootPreference`).

## Step 0 — housekeeping (do before anything else)

- `git init` in `/Users/andrei/dev/LidBoot` (repo root above `app/`), first commit of the current state. `.gitignore` already exists and excludes `build/`, generated `LidBoot.xcodeproj/`.
- Keep commits small and per-finding so the user can review.

---

## A. Engineering fixes (correctness first)

### E1 — Privileged write blocks the main thread (HIGH)
`NVRAMWriter.apply` is `@MainActor` and synchronous; `LidBootModel.apply` calls it from inside SwiftUI `Binding` setters. Consequences: the `isApplying` spinner **never renders** (the `@Published` change and the blocking call happen in the same run-loop turn), the toggle animation stutters, and the whole UI is frozen while the password prompt is up.
**Fix:** make the flow async. `NSAppleScript` does need the main thread, but the model should: set `isApplying`, yield (`Task` + small structured hop) so SwiftUI paints, then execute, then verify and clear. Acceptance: spinner visibly appears before the auth prompt; toggles disabled while `isApplying`; cancel path still snaps the toggle back.

### E2 — `MenuBarExtra(isInserted:)` no-op setter (MEDIUM)
`LidBootApp.swift` builds the insertion binding with `set: { _ in }`. On macOS 15+ users can **Cmd-drag the status item out of the menu bar**; the system calls the setter with `false`, which is silently ignored → stored mode says menu bar exists, reality disagrees.
**Fix:** honor the setter — if the item is removed and mode was `.menuBar`, promote to `.dock` (never leave the app unreachable); if mode was `.both`, drop to `.dock`. Persist the change.

### E3 — Dock-icon reopen is broken (HIGH — confirmed by review)
`applicationShouldHandleReopen` returning `true` does **not** reopen a closed SwiftUI `Window` scene — AppKit's default reopen has no window object to unhide. Reachable today: in `.dock` mode, close the window, click the Dock icon → nothing happens, and there is no menu bar item to fall back to.
**Fix:** plumb `openWindow` into the delegate — e.g. a `@MainActor static var onReopen: (() -> Void)?` set from a helper view that captures `@Environment(\.openWindow)`, called from `applicationShouldHandleReopen`. Then test all three modes × (window closed, window open, app relaunched). Acceptance: in every mode, activating the app from Finder/Dock always surfaces *something*.

### E4 — NVRAMReader silently defaults on weird data (LOW)
If the IORegistry property exists but isn't 1-byte `Data` (e.g., a string type or multi-byte), the current fallback logic can return `.known(.factoryDefault)` — claiming "starts up on both" about a state we don't understand.
**Fix:** any present-but-unparseable value → `.unrecognized` (extend the enum if needed for non-byte payloads). The UI already handles `.unrecognized` by disabling toggles.

### E5 — AppleScript error surface is thin (LOW)
Only `-128` (cancel) is special-cased. Real-world failures include auth-service errors (`-60005`, `-60007`) and script timeouts.
**Fix:** map the common codes to friendly messages ("macOS couldn't verify your password" etc.); keep the generic fallback. Log the raw dictionary via `os.Logger` (subsystem `com.lidboot.LidBoot`) — the app currently logs nothing, which made this session's debugging slower than it should have been.

### E6 — No testability seam for the writer (MEDIUM)
`NVRAMWriter` is an enum with static methods calling `NSAppleScript` directly; `LidBootModel` can't be unit-tested through the apply path.
**Fix:** introduce `protocol NVRAMWriting` (and `NVRAMReading`), inject into `LidBootModel.init` with default live implementations. Add model tests: toggle → correct command; cancel → state reverts; verify-mismatch → error message set. Also add `SystemSupport` tests by injecting sysctl values.

### E7 — Stale state if NVRAM changes externally (LOW)
Both surfaces refresh only `onAppear`. If the user runs `sudo nvram` in Terminal while the window is open, the UI lies until reopened.
**Fix:** refresh on `NSApplication.didBecomeActiveNotification` and when the popover opens (already does). No polling timer — this value changes ~never.

### E8 — Swift 6 mode (LOW)
`SWIFT_VERSION: 5.9` with `SWIFT_STRICT_CONCURRENCY: complete` already passes; bump to `SWIFT_VERSION: 6.0` in `project.yml` and Package.swift tools version, fix whatever surfaces (expected: little).

*(The independent code review's findings are merged in section D — read it; where it overlaps with E1–E8 the more specific prescription wins.)*

---

## B. UX / product improvements

### U1 — Menu-bar-only mode can strand the app (HIGH)
This machine proved it: full menu bar + notch = status item silently invisible. If the user picks "Menu Bar" mode, the app may become **unreachable** (no Dock icon, no visible status item, window suppressed on relaunch).
**Fix (layered):** (a) when the user selects Menu Bar-only, show a confirm sheet mentioning the notch/full-bar caveat and how to get back (relaunch app → in menu-bar mode a relaunch must always open the window — tie into E3); (b) honor E2's Cmd-drag handling. Acceptance: there is no reachable state where neither window, Dock icon, nor status item can be summoned.

### U2 — Iconography sends the wrong signal (MEDIUM)
When protection is active the status item shows `laptopcomputer.trianglebadge.exclamationmark` (reads as *error*) while the popover header shows a **green** dot (reads as *good*). Two conflicting semantics for the same state.
**Fix:** one language: active = calm/positive. Suggest status item swaps to a filled or slashed variant (e.g. `laptopcomputer.slash` or filled symbol) — not a warning triangle; keep the green dot. Add `symbolEffect` bounce on state change for polish.

### U3 — Microcopy pass (MEDIUM)
- Header summary "Your Mac starts up on its own." is ambiguous (sounds like a complaint). Better: "Starts up when you open the lid or connect power." / "Won't start up when you open the lid." etc.
- Toggle captions currently restate the toggle state; consider captions that state the *consequence* ("Opens straight to the login screen" vs "Stays off until you press a key").
- The caveat line is good — keep it.
**Also:** verify what the auth prompt actually offers — if it's password-only (likely for `do shell script`), don't say "Touch ID" anywhere in copy or docs. Check on the real machine and align.

### U4 — App icon (HIGH, it has none)
There is no AppIcon at all — Finder/Dock/switcher show the generic icon. Create an asset catalog (`App/Assets.xcassets`), restore `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`. Direction to match the in-app tiles: rounded-rect, blue→purple gradient (the exact colors used in `SharedViews.swift`), white laptop-lid glyph, subtle notch cutout as a signature detail. Generate the full macOS size set (16→1024). The user likes the Cindori (cindori.com) aesthetic — glassy, gradient, dark-friendly.

### U5 — Launch at login (MEDIUM)
Standard for a menu bar utility: a toggle using `SMAppService.mainApp.register()`/`unregister()`, in the window under the mode picker, with status read from `SMAppService.mainApp.status`. Handle `.requiresApproval` by deep-linking to Login Items settings.

### U6 — Window design polish (MEDIUM)
Current window is clean but flat for the Cindori bar. Concrete, contained upgrades (don't redesign the world):
- Hero: give the header tile a soft glow ring; animate the summary text change with `.contentTransition(.numericText())`-style fade.
- Rows: hover highlight (`onHover` + background), pressed state.
- Card: swap flat `Color.primary.opacity(0.045)` for `.background(.quaternary.opacity(…))` or a `Material` so it adapts to vibrancy.
- Footer: version string (`CFBundleShortVersionString`) small + link "How this works" → Apple's support page `https://support.apple.com/120622`.
- Both surfaces already share `BootToggles`/`SharedViews.swift` — keep additions shared the same way.

### U7 — Localization (MEDIUM, user cares)
Move all strings to a String Catalog (`Localizable.xcstrings`); ship **en** + **pt-PT** (the user is Portuguese; their other products ship pt-PT). Keep NVRAM terms untranslated. `SystemSupport.Unsupported.explanation` and `NVRAMWriteError.userMessage` live in `LidBootCore` — either move user-facing strings up into the app layer (cleaner) or localize within the package.

### U8 — Accessibility (MEDIUM)
Toggles use `Toggle("", …).labelsHidden()` → VoiceOver announces junk. Add `.accessibilityLabel("Start up when opening the lid")` etc.; make each `SettingRow` a single accessibility element with combined label/value; check caption gray contrast (11pt secondary on dark is borderline); the green/gray status dot needs an accessibility label too.

### U9 — Keyboard & window niceties (LOW)
Cmd+W closes the window (verify the hidden-title-bar window still gets it); Esc dismisses the popover; consider `Settings` scene? — **no**: the mode picker in-window is friendlier for a one-window app, skip Cmd+, to avoid two surfaces for three controls.

---

## C. Distribution (deferred Phase 4 — now specced)

Copy the working patterns from `~/dev/GridPush/scripts/` and `~/dev/Observio/app/scripts/` (`build-dmg.sh`, `notarize.sh`, `ExportOptions.plist`, `README-releases.md`). Concretely:

1. **`scripts/ExportOptions.plist`** — `method: developer-id`, `teamID: 632VXL3W66`, automatic signing.
2. **`scripts/build-dmg.sh`** — archive → export → `create-dmg` (installed). Version from `MARKETING_VERSION`.
3. **`scripts/notarize.sh`** — one-time prerequisite the **user** must run interactively (needs their app-specific password): `xcrun notarytool store-credentials` (no credentials stored yet — verified). Then `notarytool submit --wait` → `stapler staple` → `spctl --assess` gate.
4. **Sparkle** (house standard, v2.6+): add the SPM dependency to the app target in `project.yml`, `SUFeedURL` + `SUPublicEDKey` in Info.plist. Observio's model: EdDSA-sign DMGs, publish appcast + artifacts to a separate public releases repo — decide with the user whether LidBoot warrants that or plain GitHub Releases first. **Ask before creating any public repo.**
5. **Gatekeeper reality check** (why notarization is non-optional): macOS 15+ removed the Ctrl-click bypass; unsigned/un-notarized apps require a System Settings dance and 15.1+ is stricter. A signed + notarized DMG is the minimum shippable unit.
6. Versioning: bump to `0.2.0` after implementing sections A+B; `1.0.0` when distribution works end-to-end.

---

## D. Independent code review findings (merged)

A from-scratch review by a separate agent confirmed E1–E4 and E6 (its H1/H2 = E1, H4 = E3, M1 = E2, M2 = E4, H3 = E6) and added the following **new** items. Verdict was "fix-then-ship: no security holes; land the H-items plus M1/M2 before release." Security pass was clean: closed-enum command construction, no injection surface, no TOCTOU concern, sandbox-off justified.

### D1 — Toggle snaps before the write is confirmed (fold into E1)
The `Toggle` visually flips immediately in the `Binding` setter even though root hasn't confirmed; today cancel-revert only works because everything is synchronous. When making E1 async (`set: { v in Task { await self.apply(...) } }`), **re-verify the ordering**: the toggle must end in the machine-truth state on cancel/failure, with no flicker fight between the optimistic flip and `refresh()`.

### D2 — Reader must also refuse empty `Data` and wrong types (sharpens E4)
The guard's fallback returns `.known(.factoryDefault)` for present-but-non-`Data` values **and for empty `Data`**. Both must route to a refuse path. `unrecognized(UInt8)` can't represent "wrong type / empty" — add a case (e.g. `.unreadable`) and drive the same disabled-toggles UI as `unrecognizedByte`.

### D3 — Auth-daemon error codes read as failures when they're cancels (MEDIUM)
Beyond AppleScript `-128`, SecurityAgent termination can surface as `errAuthorizationCanceled (-60006)`, `errAuthorizationDenied (-60005)`, `errInteractionNotAllowed (-60007)`. Today those become "The system refused the change (-60006)." for what was a user cancel. Map `-60006` → `.cancelled`; give `-60005`/`-60007` friendly denied/not-allowed messages. (Extends E5.)

### D4 — Xcode scheme runs zero tests (MEDIUM)
`project.yml` has `test: targets: []`, so `xcodebuild test` reports green while running nothing — a CI trap. Fix: wire the SwiftPM test product into the scheme's test action, or make CI run `swift test` explicitly and document it in the README build section.

### D5 — Stale/misleading comments on load-bearing code (LOW)
- `Info.plist` `LSUIElement` comment says "no Dock icon, no main window" — wrong since the mode feature; document the promote-at-runtime strategy instead, and note that `applicationWillFinishLaunching`'s policy call is the *only* thing making the Dock icon correct at launch.
- `NVRAMWriter` claims "NSAppleScript must be driven from the main thread" — inaccurate (single consistent thread is the actual requirement); matters because E1's fix moves it off main. Validate on macOS 26.
- `defaultLaunchBehavior` is initial-launch-only; add a one-liner so nobody "fixes" it into a runtime feedback loop.

### D6 — Deprecated API (LOW)
`MenuView.swift`: `NSApp.activate(ignoringOtherApps:)` is deprecated on macOS 14+ → `NSApp.activate()`.

### D7 — Dock-mode close quits without confirmation (LOW, UX call)
`applicationShouldTerminateAfterLastWindowClosed` returning true in dock-only mode means closing the window quits the app. Intended, but combined with E3-before-fix there was no way back. After E3 lands this is acceptable; optionally note it in the U1 confirm sheet copy.

### D8 — Test coverage gaps (feeds E6's test list)
Untested and worth locking down once seams exist: reader non-happy paths (multi-byte, non-Data, empty); writer error mapping (`-128`, compile-fail, verify-fail); model orchestration (cancel-snaps-back, `isApplying` lifecycle, `controlsEnabled` gating, `summary` strings for 4 states + unsupported + unrecognized); `AppMode` parsing of bogus defaults → `.both`; `SystemSupport` branches via injected sysctl provider.

---

## E. Suggested implementation order

1. Step 0 (git) → E1+D1, E2, E3 (correctness core; E3 unblocks U1)
2. E4+D2, E5+D3, E6+D8 tests, D4 scheme fix, D5/D6 (locks behavior before UI churn)
3. U1–U3 (reachability + semantics; small diffs)
4. U4 (icon) + U6 (polish) — visual pass in one branch, screenshot both modes light+dark for user review
5. U5, U7, U8, U9
6. E7, E8
7. Section C, pausing for the user's interactive `store-credentials` step and repo-creation consent

**Definition of done for each item:** builds clean (`xcodegen generate` if project.yml changed), all `swift test` green (add tests where the item touches `LidBootCore` or the model), manual acceptance criterion in the item met, machine NVRAM restored to the state the user had (currently: factory default / variable absent). The full real-hardware test (shut down, close lid, open → must not boot) has **never been run** — coordinate with the user before running it; it can't be automated.
