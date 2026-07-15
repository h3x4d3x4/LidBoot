import SwiftUI
import LidBootCore

@MainActor
final class LidBootModel: ObservableObject {
    @Published private(set) var behavior: BootBehavior = .factoryDefault
    @Published private(set) var unrecognizedByte: UInt8?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isApplying = false

    /// Non-nil when this Mac can't support the setting at all.
    let unsupported: SystemSupport.Unsupported?

    init() {
        unsupported = SystemSupport.check()
        refresh()
    }

    /// Read the live machine state. Cheap and unprivileged, so we can do this
    /// every time the menu opens and never show a stale toggle.
    func refresh() {
        guard unsupported == nil else { return }
        switch NVRAMReader.read() {
        case .known(let value):
            behavior = value
            unrecognizedByte = nil
        case .unrecognized(let byte):
            unrecognizedByte = byte
        }
    }

    var isModified: Bool { behavior != .factoryDefault }

    var summary: String {
        if let unsupported { return unsupported.explanation }
        if let byte = unrecognizedByte {
            return "Something set BootPreference to an unrecognised value (0x\(String(format: "%02X", byte))). LidBoot won't change it."
        }
        switch (behavior.startsOnLidOpen, behavior.startsOnPowerConnect) {
        case (true, true): return "Your Mac starts up on its own."
        case (false, true): return "Opening the lid won't start your Mac."
        case (true, false): return "Connecting power won't start your Mac."
        case (false, false): return "Your Mac won't start up on its own."
        }
    }

    var lidOpen: Binding<Bool> {
        Binding(get: { self.behavior.startsOnLidOpen },
                set: { self.apply(lidOpen: $0) })
    }

    var powerConnect: Binding<Bool> {
        Binding(get: { self.behavior.startsOnPowerConnect },
                set: { self.apply(powerConnect: $0) })
    }

    var controlsEnabled: Bool {
        unsupported == nil && unrecognizedByte == nil && !isApplying
    }

    private func apply(lidOpen: Bool? = nil, powerConnect: Bool? = nil) {
        var desired = behavior
        if let lidOpen { desired.startsOnLidOpen = lidOpen }
        if let powerConnect { desired.startsOnPowerConnect = powerConnect }
        apply(desired)
    }

    private func apply(_ desired: BootBehavior) {
        guard controlsEnabled, desired != behavior else { return }

        errorMessage = nil
        isApplying = true
        defer { isApplying = false }

        do {
            try NVRAMWriter.apply(desired)
            behavior = desired
        } catch NVRAMWriteError.cancelled {
            // Not an error: the user changed their mind at the password prompt.
            // Snap the toggle back to what the machine actually says.
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
