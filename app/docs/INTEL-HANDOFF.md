# Intel Mac support — findings and implementation handoff

**Date:** 2026-07-16 · **Verdict up front: do NOT ship an Intel write path.
Implement the documentation tier below instead.** The research (multi-source,
cross-verified 2026-07-16) and the reasoning are captured here so the decision
doesn't get re-litigated from scratch every time someone opens an issue asking
for Intel support.

## The facts an implementer needs

**The Intel mechanism is `AutoBoot`** (CamelCase), community-discovered in 2016,
never documented by Apple. `%00` disables auto power-on — lid-open and
power-connect **together; there is no lid/power split on Intel** (`%01`/`%02`
have zero evidence anywhere). Documented restore is writing `%03` — *not*
deleting the variable; factory-fresh machines have it absent, but nobody has
documented delete-as-restore, so LidBoot's delete-don't-write philosophy is
untested territory there. Reads are unprivileged, same IORegistry path as ours;
absent means enabled.

**Who it would serve:** at our macOS 15 floor, exactly five discontinued T2
laptop families (MBP 2018/2019/2020-13", MBA 2020) — Tahoe cuts that to two, is
officially the **last Intel macOS** (WWDC 2025), and security updates end
~fall 2028. The Macs that most want the trick (2016–17 T1 models) can't run
macOS 15 at all. On every reachable model the feature is weaker than ours:
one merged toggle, and T2's any-key/trackpad power-on can't be suppressed.

**Risk is inverted vs Apple silicon.** `AutoBoot` on Intel has nine years of
community use with zero harm reports, and Cmd-Opt-P-R NVRAM reset is an
Apple-documented escape hatch (blocked only by a firmware password, in which
case the Terminal revert still works). The bricking horror stories belong to
**`auto-boot`** (lowercase, iBoot/bridgeOS — controls whether firmware boots at
all). They're unrelated variables that coexist on T2 Macs — any code matching
"autoboot" case-insensitively is a footgun.

**Why we still don't ship it:** the maintainer owns no Intel Mac. Write-then-
verify — the app's core safety pillar — would be a claim never once observed
running on real EFI NVRAM. A shrinking five-model audience doesn't justify
diluting "it only ever touches BootPreference, enforced by a unit test" into a
two-variable story on untestable hardware. Precedent agrees: the Intel-era apps
that did this (DarkBoot, BootBuddy) are dead, and they even read state wrong
(grepping for `%03` misreports factory-fresh machines).

## Tier 1 — implement now (documentation + honest gate copy)

1. **README, "Requirements" section:** the current line says Intel guessing
   "risks an unbootable machine" — **that's wrong for Intel** (it's the
   Apple-silicon `auto-boot` confusion that bricks; Intel is key-combo
   recoverable). Replace with: different variable, different semantics (no
   lid/power split), hardware we can't test — and give the command:

   ```
   sudo nvram AutoBoot=%00     # disable auto power-on (lid + power together)
   sudo nvram AutoBoot=%03     # restore
   ```

   Applies to: MacBook Pro 2016+, MacBook 12" 2017, MacBook Air 2018+ (Intel).
   Caveats to state: on T2 models a key press or trackpad touch still powers
   on; recovery is Cmd-Opt-P-R at boot (Apple-documented).

2. **In-app unsupported screen (`UnsupportedView`)**: for the `.notAppleSilicon`
   case only, add the same two commands in a copyable monospaced block under
   the explanation, with the same caveats in one caption line. This turns the
   dead-end screen into an answer. Localize (pt-PT) as always; the command
   strings themselves stay verbatim/untranslated.

3. **`Localization.swift` copy fix** for `.notAppleSilicon` — same inaccuracy
   as the README ("riskier method" framing). New copy: "Intel Macs use a
   different setting (`AutoBoot`) that LidBoot can't test on real hardware.
   You can set it yourself in Terminal — see below."

4. **Safety invariants untouched:** `NVRAMCommand` stays a closed enum over
   `BootPreference` only; `testNoCommandEverTouchesAnotherNVRAMVariable` keeps
   passing unchanged. The app never writes on Intel; it only *displays* text.

Acceptance: build + 35 tests green; screenshot the `.notAppleSilicon` screen via
`-simulateUnsupported notAppleSilicon` (Debug) in en + pt-PT; README renders.

## Tier 2 — only if real demand materializes (spec, not a commitment)

Trigger: multiple issues from actual Intel-Mac owners offering to test. Then:

- Separate `IntelAutoBootCommand` enum (`disable` = `%00`, `restore` = `%03` —
  **write `%03`, don't delete**; deletion is undocumented on Intel), gated by
  `SystemSupport` detecting Intel + T-chip laptop; UI collapses to ONE switch
  ("Start up automatically") with the T2 key-press caveat pinned.
- Exact-match variable names only (`AutoBoot`), never case-insensitive.
- Ship behind an explicit "community-tested, unverified by the maintainer"
  label, and only after at least one tester confirms write-then-read-back on
  T2 hardware through the app itself.
- Keep the deployment floor at macOS 15. Dropping to 12/13 to reach T1 Macs is
  rejected outright — different SDK era, different Sparkle, different
  everything, for hardware whose OS is already unsupported.

Sources are linked in the research record (session 2026-07-16); key ones:
Apple 120622 (AS-only doc), archived HT201150 (which Intels auto-boot), Apple
120282 (Sequoia Intel list), OSXDaily/iFixit/Eclectic Light (`AutoBoot` usage),
Apple 102539/102603 (NVRAM reset + firmware-password caveat).
