import Foundation
import LidBootCore

// All user-facing wording lives here, not in LidBootCore. Keeps the NVRAM logic
// presentation-free and puts every translatable string in one place.
//
// `String(localized:)` rather than raw literals, because these are handed to
// `Text(_: String)`, which does NOT look strings up — by the time SwiftUI sees
// them they must already be localized.

extension NVRAMWriteError {
    var userMessage: String {
        switch self {
        case .cancelled:
            // Unreachable in the UI: the model swallows cancellation rather than
            // showing an error for "the user changed their mind".
            return ""
        case .authorizationDenied:
            return String(localized: "macOS couldn't verify your password, so nothing changed.")
        case .interactionNotAllowed:
            return String(localized: "macOS wouldn't show the authorization prompt, so nothing changed.")
        case .couldNotCompileScript:
            return String(localized: "Couldn't prepare the system command.")
        case .scriptFailed(let code, _):
            // The raw AppleScript message is English and often unhelpful; it goes
            // to the log instead of being concatenated onto a translated line.
            return String(localized: "The system refused the change (\(code)).")
        case .verificationFailed:
            // Careful: a failed read-back means the value isn't what we asked
            // for. It does NOT mean nothing changed — claiming so would be a
            // guess in exactly the state where we've lost track.
            return String(localized: "macOS accepted the change, but the setting reads back differently. The switches show what your Mac actually reports.")
        }
    }
}

extension SystemSupport.Unsupported {
    var explanation: String {
        switch self {
        case .notAppleSilicon:
            return String(localized: "This setting only exists on Apple silicon Macs. Your Mac uses different firmware that LidBoot doesn't support.")
        case .osTooOld(let current):
            return String(localized: "This setting needs macOS 15 (Sequoia) or later. You're on \(current).")
        case .notALaptop:
            // No model identifier: "This Mac is a Mac14,12" means nothing to
            // anyone and reads like a bug.
            return String(localized: "This setting only applies to Mac laptops with a lid.")
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
            return String(localized: "BootPreference is set to a value LidBoot doesn't recognise (0x\(hex)), so it won't change it.")
        case .unreadable:
            return String(localized: "BootPreference holds a value LidBoot can't read, so it won't change it.")
        }
    }
}

extension BootBehavior {
    /// One line describing what the Mac will actually do.
    ///
    /// "Start up" throughout, never "wake": BootPreference governs powering on
    /// from a full shutdown. Waking a sleeping Mac is a different thing and is
    /// not affected by any of this.
    var summary: String {
        switch (startsOnLidOpen, startsOnPowerConnect) {
        case (true, true):
            return String(localized: "Starts up when you open the lid or connect power.")
        case (false, true):
            return String(localized: "Won't start up when you open the lid.")
        case (true, false):
            return String(localized: "Won't start up when you connect power.")
        case (false, false):
            return String(localized: "Won't start up from the lid or from power.")
        }
    }
}
