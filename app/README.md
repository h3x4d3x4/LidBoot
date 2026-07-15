# LidBoot

A menu bar app and window that stops your MacBook starting up on its own when you
open the lid or plug in power.

macOS has no toggle for this. Apple documents an `nvram` command instead — LidBoot
is a front end for that command, so you don't have to touch the Terminal.

## What it actually does

macOS stores this behaviour in a single NVRAM variable, `BootPreference`, which has
four states. LidBoot shows them as two independent switches:

| Opening the lid | Connecting power | `BootPreference` |
| --- | --- | --- |
| starts up | starts up | *variable removed* (factory default) |
| **won't** start up | starts up | `%01` |
| starts up | **won't** start up | `%02` |
| **won't** start up | **won't** start up | `%00` |

Turning both switches back on **deletes** the variable, leaving NVRAM exactly as it
shipped rather than writing a "default" value over it.

## Important limitation

**Your Mac still starts up when you press a key or touch the trackpad.**

`BootPreference` only suppresses start-up from *opening the lid* and *connecting
power*. This is firmware behaviour and no app can change it. If you were hoping to
wipe the keyboard with the lid open without the Mac waking, this won't do that.

## Requirements

- **Apple silicon** Mac laptop (M1 or later)
- **macOS 15 (Sequoia)** or later — `BootPreference` doesn't exist before this

Intel Macs are deliberately unsupported: they use a different variable (`AutoBoot`)
with different semantics, and guessing wrong there risks an unbootable machine.
LidBoot detects unsupported hardware and disables itself with an explanation.

## How it gets permission

Reading the current setting needs no privileges at all, so the switches always show
the truth without prompting.

Changing it needs root. LidBoot asks macOS for a one-shot authorisation
(`do shell script … with administrator privileges`), which shows the standard Touch
ID / password prompt. **Nothing is installed** — no background helper, no root
daemon, no login item. You'll see the prompt on each change, which is a fair trade
for a setting you'll touch about twice.

## Safety

NVRAM mistakes on Apple silicon can require DFU recovery, so LidBoot is deliberately
narrow:

- It only ever touches `BootPreference`. It never writes `auto-boot`, which is
  widely reported to leave Apple silicon Macs unbootable.
- The commands come from a closed enum — nothing is ever built from user input.
  This is enforced by a unit test.
- Every write is verified by reading the value back; a mismatch is reported rather
  than assumed successful.
- App Sandbox is off (required for NVRAM access), so LidBoot is distributed with
  Developer ID + notarization rather than via the Mac App Store.

## Build

```sh
xcodegen generate
open LidBoot.xcodeproj
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project LidBoot.xcodeproj -scheme LidBoot -configuration Release build
```

Run the logic tests (no root, no prompts):

```sh
swift test
```

## Layout

```
App/                  SwiftUI: menu bar popover, window, app mode
Sources/LidBootCore/  the NVRAM logic, independently testable
Tests/                the 2x2 mapping, locked down
```

`LidBootCore` has no UI and no privileged code paths beyond the single writer, so
the interesting logic can be tested without ever prompting for a password.
