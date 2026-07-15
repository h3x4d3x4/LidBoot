import Foundation
import AppKit

public enum NVRAMWriteError: Error, Equatable {
    /// User dismissed the authentication prompt. Not an error worth alerting about.
    case cancelled
    case couldNotCompileScript
    case scriptFailed(code: Int, message: String)
    /// The write reported success but re-reading NVRAM disagrees.
    case verificationFailed(expected: BootBehavior)
}

extension NVRAMWriteError {
    public var userMessage: String {
        switch self {
        case .cancelled:
            return "Cancelled."
        case .couldNotCompileScript:
            return "Couldn't prepare the system command."
        case .scriptFailed(let code, let message):
            return "The system refused the change (\(code)). \(message)"
        case .verificationFailed:
            return "The setting didn't stick. Your Mac is unchanged."
        }
    }
}

/// Applies a `BootBehavior` by running one fixed `nvram` command as root.
///
/// Privilege model: a one-shot `do shell script … with administrator privileges`,
/// which triggers the native Touch ID / password prompt. There is no installed
/// helper and no root daemon left behind — this setting is changed once and then
/// forgotten, so a persistent helper would add real attack surface for no gain.
public enum NVRAMWriter {
    /// NSAppleScript must be driven from the main thread.
    @MainActor
    public static func apply(_ behavior: BootBehavior) throws {
        let command = NVRAMCommand.command(for: behavior)
        try run(command)

        // Trust nothing: confirm the machine actually reports what we asked for.
        guard case .known(let actual) = NVRAMReader.read(), actual == behavior else {
            throw NVRAMWriteError.verificationFailed(expected: behavior)
        }
    }

    @MainActor
    private static func run(_ command: NVRAMCommand) throws {
        // `command.shellCommand` comes from a closed enum — never from user input,
        // so there is nothing here to escape or inject.
        let source = "do shell script \"\(command.shellCommand)\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            throw NVRAMWriteError.couldNotCompileScript
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? ""
            // -128 is "user cancelled" — the standard AppleScript cancel code.
            throw code == -128
                ? NVRAMWriteError.cancelled
                : NVRAMWriteError.scriptFailed(code: code, message: message)
        }
    }
}
