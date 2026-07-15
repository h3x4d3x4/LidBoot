<div align="center">

# Lid Boot

**Stop your MacBook starting up on its own.**

A menu bar app and window that control whether your Mac powers on when you open
the lid or plug in power. macOS has no switch for this — Apple documents an
`nvram` command instead. Lid Boot is a front end for that command, so you don't
have to touch the Terminal.

![macOS 15+](https://img.shields.io/badge/macOS-15%2B-blue)
![Apple silicon](https://img.shields.io/badge/Apple%20silicon-required-orange)
![Swift 6](https://img.shields.io/badge/Swift-6.0-red)
![Developer ID](https://img.shields.io/badge/distribution-Developer%20ID-green)

</div>

---

## What it does

macOS keeps this behaviour in one NVRAM variable, `BootPreference`, which has
four possible states. Lid Boot shows them as two independent switches:

| Opening the lid | Connecting power | `BootPreference` |
| --- | --- | --- |
| starts up | starts up | *variable removed* (factory default) |
| **won't** start up | starts up | `%01` |
| starts up | **won't** start up | `%02` |
| **won't** start up | **won't** start up | `%00` |

Turning both switches back on **deletes** the variable rather than writing a
"default" value over it, so your Mac ends up byte-for-byte as it shipped.

## Two limitations, stated up front

Both are real, both are in the app's UI, and neither is fixable:

**1. It only applies when your Mac is shut down.** `BootPreference` governs
*starting up*, not *waking*. Open the lid on a sleeping Mac and it wakes as
normal — none of this changes that. If your Mac usually sleeps rather than
shuts down, this setting will appear to do nothing, and that's expected.

**2. Even when shut down, the keyboard and trackpad still start it.**
`BootPreference` only suppresses start-up from *opening the lid* and
*connecting power*. That's firmware, and no app can change it. So if you wanted
to wipe the keyboard without the Mac coming on: this won't do that.

## Requirements

- **Apple silicon** Mac **laptop** (M1 or later)
- **macOS 15 (Sequoia)** or later — `BootPreference` doesn't exist before this

Intel Macs are deliberately unsupported: they use a different variable
(`AutoBoot`) with different semantics, and guessing wrong there risks an
unbootable machine. Lid Boot detects unsupported hardware and says so instead of
pretending.

Support is decided by asking the hardware whether it has a lid
(`IOPMrootDomain`'s `AppleClamshellState`), **not** by matching model names.
Apple stopped using "MacBook…" identifiers in 2022 — an M2 Air reports
`Mac14,2`, an M4 reports `Mac16,x` — so any name-based check silently rejects
newer laptops and needs updating every autumn.

## How permissions work

**Reading needs nothing.** The current setting is read straight from the IO
registry, so the switches always show the truth without ever prompting.

**Changing needs root.** Lid Boot asks macOS for a one-shot authorisation
(`do shell script … with administrator privileges`), which shows the standard
password prompt, with a sentence explaining why.

**Nothing is installed.** No background helper, no root daemon, no login item
(unless you ask for one). You'll see the prompt on each change — a fair trade
for a setting you'll touch about twice, and cheaper than shipping a permanently
installed root daemon.

## Safety

NVRAM mistakes on Apple silicon can require DFU recovery, so the app is
deliberately narrow:

- **Only `BootPreference` is ever touched.** It never writes `auto-boot`, which
  is widely reported to leave Apple silicon Macs unbootable. A unit test asserts
  no reachable command can name anything else.
- **Commands come from a closed enum.** Nothing is ever built from user input,
  so there's no string to escape or inject.
- **Every write is verified** by reading the value back. A mismatch is reported,
  never assumed successful.
- **It refuses rather than guesses.** If `BootPreference` holds anything that
  isn't a documented single byte, the controls disable rather than overwrite a
  state the app doesn't understand. Deleting stays available, because removing
  the variable is safe whatever it holds.
- **App Sandbox is off** — required for NVRAM access — so Lid Boot is
  distributed with Developer ID + notarization, and can never go to the Mac App
  Store.

## Features

- Menu bar popover, a window, or both — your choice (**Settings › General**)
- **Restore Default** — one click back to factory
- **Copy Terminal Command** — the equivalent `sudo nvram …` line for your
  current setting, for scripting other Macs. Built from the same closed enum the
  app runs, so it can't drift from what the app actually does.
- **Copy Diagnostics** — model, macOS version, and the raw `BootPreference`
  value, for bug reports
- Automatic updates (Sparkle), signed and verified
- English and Portuguese (pt-PT)
- Full VoiceOver labels

## Build

`project.yml` is the source of truth — the `.xcodeproj` is generated and not
committed.

```sh
brew install xcodegen create-dmg     # once
xcodegen generate
open LidBoot.xcodeproj
```

Command line:

```sh
xcodegen generate
xcodebuild -project LidBoot.xcodeproj -scheme LidBoot -configuration Debug build
```

Tests (no root, no prompts, under a second):

```sh
swift test           # fast path
xcodebuild test -project LidBoot.xcodeproj -scheme LidBoot   # same tests via the scheme
```

### Seeing the unsupported states

They're the first thing a wrong-hardware user meets, and otherwise only
reachable through test fakes. Debug builds only:

```sh
./build/.../LidBoot.app/Contents/MacOS/LidBoot -simulateUnsupported notALaptop
#                                                                  notAppleSilicon | osTooOld
```

## Release

```sh
./scripts/build-dmg.sh                              # archive, sign, verify, package
./scripts/notarize.sh dist/LidBoot-<version>.dmg    # notarize + staple
./scripts/publish-release.sh <version> <build>      # EdDSA-sign, publish, update appcast
```

`build-dmg.sh` refuses to package a build missing the hardened runtime (Apple
would reject it) or with the sandbox enabled (the app couldn't read NVRAM),
rather than discovering either at the notary service.

`publish-release.sh --dry-run` signs and prints the appcast without publishing.

Notarization needs a one-time keychain profile (interactive — it wants an
app-specific password from appleid.apple.com):

```sh
xcrun notarytool store-credentials "lidboot-notary" \
    --apple-id "you@example.com" --team-id "632VXL3W66" --password "<app-specific-password>"
```

It isn't optional in practice: macOS 15 removed the Control-click Gatekeeper
bypass, so an un-notarized build makes users dig through System Settings to
launch it at all.

## Updates

Sparkle, on the same model as Observio:

```
this repo (private) ──build, sign, notarize locally──► publish-release.sh
                                                           │
                     ┌─────────────────────────────────────┴───────────┐
                     ▼                                                 ▼
         public repo Release assets                        public repo appcast.xml
         (LidBoot-<version>.dmg)                           (the canonical feed)
                     ▲                                                 ▲
                     │                  raw.githubusercontent.com/…/appcast.xml
                     │                  (the app reads this directly)
                app downloads here (public, no auth)
```

Releases: [LidBoot-Releases](https://github.com/h3x4d3x4/LidBoot-Releases)

The app needs no token, because integrity comes from the EdDSA signature
(`SUPublicEDKey` in Info.plist) rather than from the feed being private.

The feed URL is baked into every build, so the releases repo name is effectively
permanent — renaming or removing it breaks updates for every shipped copy, and
the only fix is handing users a new DMG. Putting a redirect in front (e.g.
`lidboot.hexadexa.io/appcast.xml`) is what would buy the ability to move hosts
later; that's its only purpose.

## Layout

```
App/                     SwiftUI. Every user-facing string lives here.
  LidBootApp.swift         scenes, activation policy, menu bar item, commands
  LidBootModel.swift       the state machine: read, apply, verify, refuse
  MainWindowView.swift     the window
  MenuView.swift           the menu bar popover
  SettingsView.swift       General / Updates / About
  Localization.swift       all wording, in one place
  Localizable.xcstrings    en + pt-PT
Sources/LidBootCore/     NVRAM logic. No UI, no user-facing strings, one
                         privileged path behind a protocol.
Tests/                   35 tests: mapping, decoding, service, errors, gate.
scripts/                 build-dmg → notarize → publish-release
docs/STATUS.md           what's proven, what's open, known gaps — read first
```

`LidBootCore` has no UI and no wording, so the interesting logic is tested with
fakes and never prompts for a password.

## Naming

The product, executable, bundle id and DMG are all `LidBoot` — no spaces, so
scripts and URLs stay simple. Everything a person reads says **Lid Boot**.
Same split as Grid Push.

---

<div align="center">

Designed and built by [Hexadexa](https://hexadexa.io) ·
[andrei@hexadexa.dev](mailto:andrei@hexadexa.dev) ·
[Ko-fi](https://ko-fi.com/hexadexa)

Copyright © 2026 Hexadexa. All rights reserved.

</div>
