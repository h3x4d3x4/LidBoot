<div align="center">

<img src="app/App/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="112" alt="" />

# LidBoot

**Your lid is not a power button.**

Stop your MacBook starting up when you open the lid or connect power.

### [↓ Download for macOS](https://github.com/h3x4d3x4/LidBoot/releases/latest)

<sub>Apple silicon · macOS 15+ · free · [lidboot.hexadexa.io](https://lidboot.hexadexa.io)</sub>

</div>

---

Shut down your MacBook, then open the lid or plug in the charger — and it starts
right back up. macOS has no setting to stop it. Apple documents an `nvram`
command instead. LidBoot is that command, with two switches.

## What it actually does

macOS keeps this behaviour in a single NVRAM variable, `BootPreference`, which
has four states. LidBoot shows them as two independent switches:

| Opening the lid | Connecting power | `BootPreference` |
| --- | --- | --- |
| starts up | starts up | *variable removed* (factory default) |
| **won't** start up | starts up | `%01` |
| starts up | **won't** start up | `%02` |
| **won't** start up | **won't** start up | `%00` |

Turning both switches back on **deletes** the variable, leaving NVRAM exactly as
it shipped rather than writing a "default" value over it.

## Limitations

**A key press still starts your Mac.** `BootPreference` only suppresses start-up
from opening the lid and connecting power. That's firmware, and no app can change
it.

**Sleep is untouched.** This applies from a full shutdown. Waking behaves as it
always has.

The app says both of these on screen rather than letting you find out.

## Requirements

Apple silicon MacBook (M1 or later), macOS 15 (Sequoia) or later.

Intel Macs are deliberately unsupported: they use a different variable
(`AutoBoot`) with different semantics, and guessing wrong risks an unbootable
machine. LidBoot detects unsupported hardware and disables itself with an
explanation.

## Safety

NVRAM mistakes on Apple silicon can require DFU recovery, so this app is
deliberately narrow:

- It only ever touches `BootPreference` — never `auto-boot`, which is widely
  reported to leave Apple silicon Macs unbootable.
- Commands come from a closed enum; nothing is built from user input. A unit test
  fails the build if one of them touches another variable.
- Every write is verified by reading the value back.
- A value it doesn't recognise disables the switches rather than overwriting a
  state it can't explain.

Reads need no privileges. Writes ask macOS for a one-shot authorisation, so
**nothing is installed** — no background helper, no root daemon.

## Build

`project.yml` is the source of truth; the `.xcodeproj` is generated and not
committed.

```sh
brew install xcodegen         # once
cd app
xcodegen generate
swift test                    # 35 tests, no root, under a second
open LidBoot.xcodeproj
```

`swift test` needs no signing. To build and run the app itself, change
`DEVELOPMENT_TEAM` in `app/project.yml` to your own team (or clear it and use
ad-hoc signing locally).

See [`app/README.md`](app/README.md) for the release pipeline, notarization and
Sparkle setup, and [`app/docs/STATUS.md`](app/docs/STATUS.md) for current state.

## Repositories

| | |
| --- | --- |
| **LidBoot** (this repo) | Source, signed release DMGs, and the Sparkle appcast (`appcast.xml`). |
| **LidBoot-site** | The [lidboot.hexadexa.io](https://lidboot.hexadexa.io) landing page. |

## Contributing & support

LidBoot is a small utility, maintained as time permits. Bug reports are
welcome — include the output of **Settings › About › Copy Diagnostics**. Small,
focused PRs are welcome too; anything touching the NVRAM path needs a matching
test, and the safety rules above are non-negotiable.

**Security:** for anything security-relevant, email
[andrei@hexadexa.dev](mailto:andrei@hexadexa.dev) instead of opening a public
issue.

## License

[MIT](LICENSE).

---

Built by [Hexadexa](https://hexadexa.io) · [Buy me a coffee](https://buymeacoffee.com/hexadexa) ·
Not affiliated with Apple Inc.
