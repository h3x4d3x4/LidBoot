import SwiftUI
import LidBootCore

@MainActor
final class LidBootModel: ObservableObject {
    /// What the machine actually reports — `nil` until we've successfully read
    /// it, and whenever we can't interpret what's there.
    ///
    /// Optional on purpose: the toggles must never show a position we invented.
    /// Previously this defaulted to `.factoryDefault` and was left untouched on
    /// unsupported/unreadable machines, so the UI cheerfully showed two switches
    /// ON — asserting a state it had never read.
    @Published private(set) var behavior: BootBehavior?
    /// What the user just asked for, while the write is still in flight.
    ///
    /// Without this the Toggle would flip, immediately snap back (the getter
    /// still returns the old machine state), then flip forward again when the
    /// write lands.
    @Published private(set) var pending: BootBehavior?
    /// Set when NVRAM holds something we refuse to interpret.
    @Published private(set) var refusal: BootPreferenceState?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isApplying = false

    /// Non-nil when this Mac can't support the setting at all.
    let unsupported: SystemSupport.Unsupported?

    private let service: BootPreferenceService

    init(service: BootPreferenceService = BootPreferenceService(),
         unsupported: SystemSupport.Unsupported? = SystemSupport.check()) {
        self.service = service
        self.unsupported = unsupported
        refresh()
    }

    /// Read the live machine state. Cheap and unprivileged, so we can do this
    /// whenever the app becomes active and never show a stale toggle.
    func refresh() {
        guard unsupported == nil else {
            behavior = nil
            return
        }
        // A stale error must not outlive the state it described.
        errorMessage = nil

        let state = service.read()
        if let value = state.behavior {
            behavior = value
            refusal = nil
        } else {
            // Don't keep showing the last-known-good switches next to a message
            // saying we can't read the value.
            behavior = nil
            refusal = state
        }
    }

    /// The state the UI should draw, or nil when we genuinely don't know.
    var displayed: BootBehavior? { pending ?? behavior }

    var isModified: Bool {
        guard let behavior else { return false }
        return behavior != .factoryDefault
    }

    /// True when we can't vouch for what's in NVRAM.
    var isRefusing: Bool { refusal != nil }

    var summary: String {
        if let unsupported { return unsupported.explanation }
        if let refusal { return refusal.refusalMessage ?? "" }
        guard let behavior else { return "" }
        return behavior.summary
    }

    var lidOpen: Binding<Bool> {
        Binding(get: { self.displayed?.startsOnLidOpen ?? false },
                set: { newValue in Task { await self.apply(lidOpen: newValue) } })
    }

    var powerConnect: Binding<Bool> {
        Binding(get: { self.displayed?.startsOnPowerConnect ?? false },
                set: { newValue in Task { await self.apply(powerConnect: newValue) } })
    }

    var controlsEnabled: Bool {
        unsupported == nil && refusal == nil && behavior != nil && !isApplying
    }

    /// Clearing the variable is safe whatever it holds, so it stays available
    /// even when we refuse to interpret the current value — that's the whole
    /// point of an escape hatch.
    var canRestoreDefault: Bool {
        unsupported == nil && !isApplying && (isModified || isRefusing)
    }

    /// The equivalent Terminal command — for scripting a fleet, or for auditing
    /// exactly what the app would run.
    ///
    /// Falls back to the delete command when we can't read the current value:
    /// offering to re-apply a state we never verified would contradict the
    /// refusal we're showing on screen.
    var terminalCommand: String {
        guard let behavior = displayed, !isRefusing else {
            return "sudo \(NVRAMCommand.delete.shellCommand)"
        }
        return "sudo \(NVRAMCommand.command(for: behavior).shellCommand)"
    }

    func restoreDefault() async {
        guard canRestoreDefault else { return }

        errorMessage = nil
        isApplying = true
        defer {
            isApplying = false
            pending = nil
        }

        do {
            // `clear` deletes outright rather than diffing against a value we
            // may not have been able to read.
            try await service.clear(prompt: Self.authPrompt)
            refresh()
        } catch NVRAMWriteError.cancelled {
            refresh()
        } catch let error as NVRAMWriteError {
            errorMessage = error.userMessage
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    private func apply(lidOpen: Bool? = nil, powerConnect: Bool? = nil) async {
        guard var desired = behavior else { return }
        if let lidOpen { desired.startsOnLidOpen = lidOpen }
        if let powerConnect { desired.startsOnPowerConnect = powerConnect }
        await apply(desired)
    }

    func apply(_ desired: BootBehavior) async {
        guard controlsEnabled, desired != behavior else { return }

        errorMessage = nil
        pending = desired
        isApplying = true
        defer {
            isApplying = false
            // Always drop the optimistic value: from here on the toggle follows
            // `behavior`, which only ever reflects a verified read.
            pending = nil
        }

        do {
            // Suspends here: the auth prompt runs off the main thread, so the
            // spinner actually paints and the UI stays responsive.
            try await service.apply(desired, prompt: Self.authPrompt)
            behavior = desired
        } catch NVRAMWriteError.cancelled {
            // Not an error: the user changed their mind at the password prompt.
            // Re-read so the toggle lands on the machine's truth.
            refresh()
        } catch let error as NVRAMWriteError {
            errorMessage = error.userMessage
            refresh()
        } catch {
            errorMessage = error.localizedDescription
            refresh()
        }
    }

    /// Shown in the macOS authorization dialog, so the user learns *why* they're
    /// being asked rather than just seeing "LidBoot wants to make changes."
    static var authPrompt: String {
        String(localized: "LidBoot needs your password to change your Mac's start-up setting.")
    }

    /// A Mac we can't help, or a value we can't read, must not look identical to
    /// a healthy Mac sitting at its factory default.
    var menuBarSymbol: String {
        if unsupported != nil || isRefusing {
            return "laptopcomputer.trianglebadge.exclamationmark"
        }
        return isModified ? "laptopcomputer.slash" : "laptopcomputer"
    }
}
