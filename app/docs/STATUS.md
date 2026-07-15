# LidBoot — current status

**v0.2.0 · 2026-07-15.** Read this before `HANDOFF.md` (that's the historical first audit; everything in it is done).

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

## Open — needs a human

1. **Notarization.** No keychain profile exists yet. Either tell the implementer the profile name other projects use (`NOTARIZE_PROFILE=<name> ./scripts/notarize.sh dist/LidBoot-0.2.0.dmg`) or create one:
   `xcrun notarytool store-credentials "lidboot-notary" --apple-id "your-apple-id@example.com" --team-id "632VXL3W66" --password "<app-specific-password>"`
   Until then `spctl` says `rejected — source=Unnotarized Developer ID`, and macOS 15+ removed the Control-click bypass, so testers would have to go through System Settings to launch it. **Don't ship the DMG before this.**
2. **Public releases repo.** `h3x4d3x4/LidBoot-Releases` doesn't exist. It must be **public** so the app updates without a token (integrity comes from the EdDSA signature, not repo privacy). Not created — that's outward-facing and needs the user's explicit yes.
3. **Cloudflare redirect.** `lidboot.hexadexa.io/appcast.xml` → `https://raw.githubusercontent.com/h3x4d3x4/LidBoot-Releases/main/appcast.xml` (302), same rule shape as Observio's. **The feed URL is baked into every build**, so until this exists updates silently do nothing. It's a redirect precisely so the backing store can move without shipping a new app.
4. **Sparkle signing key.** LidBoot reuses the developer's existing key (`g1lZN7…`, the same one Observio uses) — Sparkle's default of one key per developer. Fine, but a compromise would affect every app signed with it. Decide whether LidBoot should get its own.

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

- **No "Report a Problem" / Copy Diagnostics.** There's good `os_log` instrumentation (subsystem `com.lidboot.LidBoot`, categories `nvram`/`service`/`updates`/`login`) that no user can reach. A button dumping app version, macOS version, raw `BootPreference` bytes and the last error would turn "it didn't work" into an actionable report. Worth doing before a wider beta.
- **The menu bar icon is two-state** (`laptopcomputer` / `.slash`, plus a warning badge for refusal/unsupported). It can't distinguish lid-off from power-off from both-off. The tooltip and accessibility label carry the full summary, which is the mitigation.
- **The popover gives no success feedback**, because the auth prompt takes focus and dismisses it — the toggle, caption and summary are all painted on a view that no longer exists by the time the write lands. The menu bar tooltip is the fallback. A notification on success would fix it properly.
- **`unsupported`/`refusal` states have never been seen on real hardware** — they're only reachable via injected fakes in tests. They're designed and unit-tested, not visually verified.
- **No `Cmd-,` in menu-bar-only mode**: the app is an accessory, so there's no app menu. Settings is reachable from the popover instead — this is why that link exists.

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
