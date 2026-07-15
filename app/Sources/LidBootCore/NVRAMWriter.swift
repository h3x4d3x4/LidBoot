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

// Deliberately no user-facing text here: this module is the NVRAM logic, and
// wording/localisation belongs to the app layer. See App/Localization.swift.

/// Runs one fixed `nvram` command as root.
///
/// `prompt` is the sentence shown in the macOS authorisation dialog. It's passed
/// in rather than hard-coded because it's user-facing text, and wording lives in
/// the app layer.
public protocol NVRAMWriting: Sendable {
    func run(_ command: NVRAMCommand, prompt: String) async throws
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

    public func run(_ command: NVRAMCommand, prompt: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Self.queue.async {
                do {
                    try Self.execute(command, prompt: prompt)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Strips anything that could break out of the AppleScript string literal.
    /// The command itself comes from a closed enum, but the prompt is free text
    /// from the app layer (and from translators), so it gets sanitised.
    static func escapeForAppleScriptLiteral(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private static func execute(_ command: NVRAMCommand, prompt: String) throws {
        // `command.shellCommand` comes from a closed enum — never from user
        // input — so there is nothing here to escape or inject.
        let source = """
            do shell script "\(command.shellCommand)" \
            with prompt "\(escapeForAppleScriptLiteral(prompt))" \
            with administrator privileges
            """
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
