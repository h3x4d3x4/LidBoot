import Foundation
import LidBootCore

// All user-facing wording lives here, not in LidBootCore. Keeps the NVRAM logic
// presentation-free and puts every translatable string in one place.
//
// `String(localized:)` rather than raw literals, because these are handed to
// `Text(_: String)`, which does NOT look strings up — by the time SwiftUI sees
// them they must already be localised.

extension NVRAMWriteError {
    var userMessage: String {
        switch self {
        case .cancelled:
            return String(localized: "Cancelled.")
        case .authorizationDenied:
            return String(localized: "macOS couldn't verify your password, so nothing changed.")
        case .interactionNotAllowed:
            return String(localized: "macOS wouldn't show the authorisation prompt, so nothing changed.")
        case .couldNotCompileScript:
            return String(localized: "Couldn't prepare the system command.")
        case .scriptFailed(let code, let message):
            let base = String(localized: "The system refused the change (\(code)).")
            return message.isEmpty ? base : "\(base) \(message)"
        case .verificationFailed:
            return String(localized: "The setting didn't stick. Your Mac is unchanged.")
        }
    }
}

extension SystemSupport.Unsupported {
    var explanation: String {
        switch self {
        case .notAppleSilicon:
            return String(localized: "This setting only exists on Apple silicon Macs. Intel Macs use a different, riskier method that LidBoot won't touch.")
        case .osTooOld(let current):
            return String(localized: "This setting needs macOS 15 (Sequoia) or later. You're on \(current).")
        case .notALaptop(let model):
            return String(localized: "This setting only applies to Mac laptops with a lid. This Mac is a \(model).")
        }
    }
}

extension BootPreferenceState {
    /// Why LidBoot won't touch the current value, when it won't.
    var refusalMessage: String? {
        switch self {
        case .known:
            return nil
        case .unrecognized(let byte):
            let hex = String(format: "%02X", byte)
            return String(localized: "Something set BootPreference to an unrecognised value (0x\(hex)). LidBoot won't change it.")
        case .unreadable(let reason):
            return String(localized: "BootPreference holds a value LidBoot doesn't understand (\(reason)). LidBoot won't change it.")
        }
    }
}

extension BootBehavior {
    /// One line describing what the Mac will actually do.
    var summary: String {
        switch (startsOnLidOpen, startsOnPowerConnect) {
        case (true, true):
            return String(localized: "Starts up when you open the lid or connect power.")
        case (false, true):
            return String(localized: "Won't start up when you open the lid.")
        case (true, false):
            return String(localized: "Won't start up when you connect power.")
        case (false, false):
            return String(localized: "Won't start up on its own at all.")
        }
    }
}
