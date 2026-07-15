import Foundation
import os

/// The app's entry point to NVRAM: read the current state, and apply a new one.
///
/// Composes a reader and a writer so tests can substitute fakes for both. The
/// write-then-verify pairing lives here rather than in the writer, because
/// "did it stick?" is a question only the reader can answer.
public struct BootPreferenceService: Sendable {
    private let reader: any NVRAMReading
    private let writer: any NVRAMWriting
    private static let log = Logger(subsystem: "com.lidboot.LidBoot", category: "service")

    public init(reader: any NVRAMReading = SystemNVRAMReader(),
                writer: any NVRAMWriting = AppleScriptNVRAMWriter()) {
        self.reader = reader
        self.writer = writer
    }

    public func read() -> BootPreferenceState {
        reader.read()
    }

    /// Applies `behavior` and confirms the machine agrees afterwards.
    ///
    /// Trust nothing: `nvram` exiting 0 is not proof the value took, so we read
    /// it back and treat any disagreement as a failure.
    public func apply(_ behavior: BootBehavior) async throws {
        let command = NVRAMCommand.command(for: behavior)
        try await writer.run(command)

        let actual = reader.read()
        guard actual == .known(behavior) else {
            Self.log.error("verification failed: expected \(String(describing: behavior)), read back \(String(describing: actual))")
            throw NVRAMWriteError.verificationFailed(expected: behavior)
        }
        Self.log.info("applied and verified: \(String(describing: behavior))")
    }
}
