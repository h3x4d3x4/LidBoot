import Foundation
import AppKit
import os

public enum NVRAMWriteError: Error, Equatable {
    /// User dismissed the authentication prompt. Not worth an alert.
    case cancelled
    /// Authentication was attempted and rejected.
    case authorizationDenied
    /// macOS wouldn't show the prompt at all (e.g. no GUI session).
    case interactionNotAllowed
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
        case .authorizationDenied:
            return "macOS couldn't verify your password, so nothing changed."
        case .interactionNotAllowed:
            return "macOS wouldn't show the authorisation prompt, so nothing changed."
        case .couldNotCompileScript:
            return "Couldn't prepare the system command."
        case .scriptFailed(let code, let message):
            let detail = message.isEmpty ? "" : " \(message)"
            return "The system refused the change (\(code)).\(detail)"
        case .verificationFailed:
            return "The setting didn't stick. Your Mac is unchanged."
        }
    }
}

/// Runs one fixed `nvram` command as root.
public protocol NVRAMWriting: Sendable {
    func run(_ command: NVRAMCommand) async throws
}

/// Maps AppleScript / Security framework failures onto our error cases.
///
/// Pure and separate from the script call so every branch is testable.
public enum AppleScriptErrorMapper {
    // AppleScript's own "user cancelled".
    static let userCancelled = -128
    // Security framework OSStatus values, surfaced through `do shell script`.
    static let errAuthorizationDenied = -60005
    static let errAuthorizationCanceled = -60006
    static let errInteractionNotAllowed = -60007

    public static func map(code: Int, message: String) -> NVRAMWriteError {
        switch code {
        case userCancelled, errAuthorizationCanceled:
            // Both mean "the user backed out" — never show an error for these.
            return .cancelled
        case errAuthorizationDenied:
            return .authorizationDenied
        case errInteractionNotAllowed:
            return .interactionNotAllowed
        default:
            return .scriptFailed(code: code, message: message)
        }
    }
}

/// Privilege model: a one-shot `do shell script … with administrator privileges`,
/// which triggers the standard macOS authorisation prompt. Nothing is installed —
/// no helper, no root daemon, no login item. This setting is changed once and then
/// forgotten, so a persistent helper would be attack surface for no benefit.
public struct AppleScriptNVRAMWriter: NVRAMWriting {
    /// NSAppleScript instances aren't thread-safe, so every execution goes
    /// through one serial queue. Deliberately NOT the main queue: the call
    /// blocks until the auth prompt is dismissed, and blocking main would
    /// freeze the whole UI (including the spinner meant to indicate progress).
    private static let queue = DispatchQueue(label: "com.lidboot.LidBoot.applescript")

    private static let log = Logger(subsystem: "com.lidboot.LidBoot", category: "nvram")

    public init() {}

    public func run(_ command: NVRAMCommand) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.queue.async {
                do {
                    try Self.execute(command)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func execute(_ command: NVRAMCommand) throws {
        // `command.shellCommand` comes from a closed enum — never from user
        // input — so there is nothing here to escape or inject.
        let source = "do shell script \"\(command.shellCommand)\" with administrator privileges"
        log.info("running privileged command: \(command.shellCommand, privacy: .public)")

        guard let script = NSAppleScript(source: source) else {
            log.error("NSAppleScript failed to compile")
            throw NVRAMWriteError.couldNotCompileScript
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? ""
            let mapped = AppleScriptErrorMapper.map(code: code, message: message)
            if case .cancelled = mapped {
                log.info("user cancelled the authorisation prompt (code \(code))")
            } else {
                log.error("privileged command failed: code=\(code) message=\(message, privacy: .public)")
            }
            throw mapped
        }

        log.info("privileged command succeeded")
    }
}
