import SwiftUI
import LidBootCore

@MainActor
final class LidBootModel: ObservableObject {
    /// What the machine actually reports.
    @Published private(set) var behavior: BootBehavior = .factoryDefault
    /// What the user just asked for, while the write is still in flight.
    ///
    /// Without this the Toggle would flip, immediately snap back (the getter
    /// still returns the old machine state), then flip forward again when the
    /// write lands. Showing the pending value keeps the switch under the user's
    /// finger until we know the answer.
    @Published private(set) var pending: BootBehavior?
    /// Set when NVRAM holds something we refuse to interpret.
    @Published private(set) var refusal: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isApplying = false

    /// The state the UI should draw.
    var displayed: BootBehavior { pending ?? behavior }

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
        guard unsupported == nil else { return }
        let state = service.read()
        if let behavior = state.behavior {
            self.behavior = behavior
            refusal = nil
        } else {
            refusal = state.refusalMessage
        }
    }

    var isModified: Bool { refusal == nil && behavior != .factoryDefault }

    var summary: String {
        if let unsupported { return unsupported.explanation }
        if let refusal { return refusal }
        return behavior.summary
    }

    var lidOpen: Binding<Bool> {
        Binding(get: { self.displayed.startsOnLidOpen },
                set: { newValue in Task { await self.apply(lidOpen: newValue) } })
    }

    var powerConnect: Binding<Bool> {
        Binding(get: { self.displayed.startsOnPowerConnect },
                set: { newValue in Task { await self.apply(powerConnect: newValue) } })
    }

    var controlsEnabled: Bool {
        unsupported == nil && refusal == nil && !isApplying
    }

    private func apply(lidOpen: Bool? = nil, powerConnect: Bool? = nil) async {
        var desired = behavior
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
            try await service.apply(desired)
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
}
