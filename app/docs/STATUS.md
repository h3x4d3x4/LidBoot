# LidBoot — current status

**v0.5.1 · 2026-09-19.** Read this before `HANDOFF.md` (that's the historical first audit; everything in it is done). Source is public (MIT) at github.com/h3x4d3x4/LidBoot since 0.4.0.

## 0.5.0 — going wider

Done 2026-09-18, ahead of listing the app (Homebrew, r/macapps, Show HN):

- **Intel Tier 1** from `INTEL-HANDOFF.md`: honest copy (no more "risks an unbootable machine"), and the `.notAppleSilicon` screen now shows the two `AutoBoot` commands, copyable. The app still never writes on Intel; `NVRAMCommand` is unchanged and its test still passes.
- **4-state menu bar icon** (`MenuBarIcon.swift`): slash = lid off, bolt badge = power off. Closes the "two-state icon" gap below.
- **Success notification** for popover changes (`SuccessNotification.swift`). Closes the "no success feedback" gap. Permission requested on first popover change, not at launch.
- **"Takes effect after you shut down"** notice while `lastChange > bootTime` and the state is modified.
- **`lidboot://` URL scheme** (`URLCommand.swift`), for Shortcuts/Raycast/scripts. Window comes to the front before the prompt.
- **Source code link** in About.
- **es, de, fr** added to the catalog (90 keys). pt-PT informal register kept; es informal, de "du", fr "vous" — Apple's own conventions per locale.
- READMEs: dead `buymeacoffee.com` link → Ko-fi (the one the app already used).

**Not done, deliberately:** a "Shut Down Now" button. It needs the Apple Events entitlement plus a "control System Events" TCC prompt, which breaks the entitlements file's "nothing else requested" stance. The shutdown notice above covers the confusion it was meant to fix.

**Still owner-only:** the physical premise test (below), deleting `LidBoot-Releases`, and the Homebrew tap (needs the released DMG's sha256).

## What works, and what's actually been proven

Verified on hardware (MacBookPro18,1, M1 Pro, macOS 26.5.2), not assumed:

- The privileged write works from a Developer ID-signed, hardened-runtime, non-sandboxed app on macOS 26 (`euid 0`; wrote and deleted `BootPreference`).
- Reads need no privileges — set `BootPreference` externally, launched the app, it showed the true state with no prompt.
- Refresh-on-activate picks up changes made underneath a running app (`sudo nvram` in Terminal → reactivate → UI updates).
- `Restore Default` round-trips back to the factory state (user-confirmed on the real machine).
- pt-PT renders correctly (checked by forcing the app's language).
- 35 tests green via both `swift test` and `xcodebuild test`.
- The DMG builds, signs, and passes the runtime/sandbox gates; EdDSA signing produces a valid appcast signature.

**Never run: the physical test.** Shut down → close lid → open → must not start up. Then press a key → must start up. This cannot be automated and is the one thing that proves the product's whole premise. Ask a tester to do this first.

## Done since

- **Notarized.** `dist/LidBoot-0.2.0.dmg` — Apple returned `Accepted`, ticket stapled, and `spctl` now says `accepted — source=Notarized Developer ID` (it said *rejected* before). Used the existing `observio-notary` keychain profile: a notarytool profile is credentials for an Apple ID + team, not for an app, and every Hexadexa app ships under team `632VXL3W66`. `notarize.sh` now tries `hexadexa-notary`, `lidboot-notary`, `observio-notary` in order.
- **Installed and launched from the DMG** the way a tester would; Gatekeeper accepts it.

## Shipped — 0.2.0 is live

*(Superseded 2026-07-16: the source went open and releases consolidated into the main repo — canonical feed is now `https://raw.githubusercontent.com/h3x4d3x4/LidBoot/main/appcast.xml`, DMGs on this repo's Releases. `LidBoot-Releases` is consented for deletion but still exists — the token lacks the `delete_repo` scope; the user deletes it with `gh auth refresh -h github.com -s delete_repo && gh repo delete h3x4d3x4/LidBoot-Releases --yes`. The only existing install was the user's own, updated by hand. Builds ≤0.3.1 have the dead feed baked in and cannot self-update — reinstall from a current DMG.)*

- **Public releases repo:** `h3x4d3x4/LidBoot-Releases` (created with the user's explicit consent). Holds only the appcast and DMGs; no source.
- **Release:** https://github.com/h3x4d3x4/LidBoot-Releases/releases/tag/v0.2.0
- **Feed (baked into the app):** `https://raw.githubusercontent.com/h3x4d3x4/LidBoot-Releases/main/appcast.xml`
- Verified end to end, not assumed: downloaded the DMG from the public URL with no auth, the feed's `length` matches the real file, the EdDSA signature **verifies** against it, a **tampered copy fails** verification, and Gatekeeper on the quarantined download reports `accepted — source=Notarized Developer ID`.

**Feed URL decision:** points straight at raw.githubusercontent.com rather than through `lidboot.hexadexa.io`. The user chose this deliberately — one less moving part. The cost: **the feed URL is baked into every build**, so `LidBoot-Releases` is now effectively a permanent name. Renaming or deleting it breaks updates for every shipped copy, with no remote fix — the only recourse is handing users a new DMG. A redirect in front is what would buy the ability to move hosts later; that is its only purpose.

## Open — needs a human

1. **The physical test.** Still never run. See above.
2. **Sparkle signing key.** LidBoot reuses the existing key (`g1lZN7…`, the same one Observio uses) — Sparkle's default of one key per developer. Fine, but a compromise would affect every app signed with it.
3. ~~The app inside the DMG isn't stapled.~~ **CLOSED in 0.4.0**: `build-dmg.sh` now notarizes and staples the `.app` before packaging; the DMG is notarized separately as before. Offline first launches are covered.
4. ~~The update path itself is untested.~~ **PROVEN 2026-07-15.** Published 0.3.0 while 0.2.0 was installed; Sparkle fetched the feed, found the update, and showed its "A new version of LidBoot is available!" alert with the changelog rendered from the appcast's `<description>`. Note `raw.githubusercontent.com` caches for ~5 min after a release, so the feed lags briefly — `publish-release.sh` warns about this and it is not a failure.

## Decisions worth not re-litigating

- **One-shot auth, no privileged helper.** Proven to work; a persistent root daemon is unjustified attack surface for a setting changed about twice.
- **Sandbox off → Developer ID only, never Mac App Store.** The sandbox blocks both the IO registry read and the `nvram` write.
- **Only `BootPreference`, never `auto-boot`** (bricks Apple silicon boot). Commands come from a closed enum; a test asserts nothing else is reachable.
- **Refuse rather than guess.** Any NVRAM value that isn't a documented single byte → `unrecognized`/`unreadable`, controls disabled. Deleting stays available because it's safe whatever the variable holds.
- **Hardware gate asks for a lid, not a model name.** See below — this was a real bug.
- **"Start up", never "wake".** `BootPreference` governs powering on from a full shutdown; waking a sleeping Mac is unaffected. Getting this wrong invites bug reports that aren't bugs.

## The bug the first audit missed

The laptop check was `hw.model.hasPrefix("MacBook")`. Apple stopped using those identifiers in 2022 — an M2 Air is `Mac14,2`, an M4 is `Mac16,x` — so **every MacBook newer than M1 was rejected** with "This Mac is a Mac16,1" and dead controls. Since the app requires macOS 15+, that was most of the audience.

It survived a code review and a full test suite because the dev machine is an M1 (`MacBookPro18,1`, passes) **and the test fixture hardcoded that same string**. The lesson generalises: a fixture copied from the dev machine tests the dev machine. It now probes `IOPMrootDomain`'s `AppleClamshellState` (present only on machines with a lid), with a regression test.

## Known gaps (deliberate, not forgotten)

- ~~No "Report a Problem" / Copy Diagnostics.~~ **Closed** — Settings › About › Copy Diagnostics + Email a Problem (`Diagnostics.swift`).
- ~~The menu bar icon is two-state~~ **Closed in 0.5.0** — see above.
- ~~The popover gives no success feedback~~ **Closed in 0.5.0** — notification on success for popover- and URL-initiated changes.
- **`unsupported`/`refusal` states have never been seen on real hardware** — they're only reachable via injected fakes in tests and `-simulateUnsupported`. Designed, unit-tested and screenshotted in Debug, not seen on a real Intel Mac.
- **No `Cmd-,` in menu-bar-only mode**: the app is an accessory, so there's no app menu. Settings is reachable from the popover instead — this is why that link exists. **0.5.1:** that link was a `SettingsLink`, which silently no-ops when the accessory app isn't active — i.e. exactly when you click a popover. Found by the owner on 0.5.0, the first day in menu-bar-only mode. Now `openSettings` via `WindowOpener.openSettings()`, which activates and brings the window front. `-simulateState` (Debug) exists so the modified states get looked at too.
- **Two instances at once** is not an app bug: same bundle id at two paths (e.g. `/Applications` and `build/release/export`) and LaunchServices may hand a `lidboot://` URL to the other copy. Keep one copy registered on the dev machine (`lsregister -u` the rest).

## Layout

```
App/                  SwiftUI. All user-facing strings live here (Localization.swift).
  LidBootApp.swift      scenes, activation policy, menu bar item, commands
  LidBootModel.swift    the state machine: read, apply, verify, refuse
  SettingsView.swift    General / Updates / About
  Updater.swift         Sparkle
Sources/LidBootCore/  NVRAM logic. No UI, no user-facing strings, one privileged
                      path behind a protocol.
Tests/                35 tests. Mapping, decoding, service, error mapping, gate.
scripts/              build-dmg -> notarize -> publish-release (appcast)
```
