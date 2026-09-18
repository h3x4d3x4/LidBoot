import Foundation
import LidBootCore

/// Debug builds only: an in-memory `BootPreference`, so the modified states and
/// the notices that hang off them can be looked at — and screenshotted — without
/// writing real NVRAM. Same reasoning as `-simulateUnsupported`: on the dev
/// machine these states are one password prompt away, on a tester's they're a
/// firmware change, and neither is how you want to review a layout.
///
///     LidBoot.app/Contents/MacOS/LidBoot -simulateState 00
///                                                        01 | 02 | removed
///
/// Writes go through the same `BootPreferenceService` path — command, then
/// read-back — they just land here instead of in the firmware. Never compiled
/// into Release.
#if DEBUG
final class SimulatedNVRAM: NVRAMReading, NVRAMWriting, @unchecked Sendable {
    private let lock = NSLock()
    private var byte: UInt8?

    init(byte: UInt8?) { self.byte = byte }

    func read() -> BootPreferenceState {
        lock.withLock {
            guard let byte else { return .known(.factoryDefault) }
            guard let behavior = BootBehavior(nvramByte: byte) else { return .unrecognized(byte) }
            return .known(behavior)
        }
    }

    func run(_ command: NVRAMCommand, prompt: String) async throws {
        lock.withLock {
            switch command {
            case .delete: byte = nil
            case .set(let value): byte = value
            }
        }
    }

    /// The service to use instead of the real one, if `-simulateState` was passed.
    static var fromArguments: BootPreferenceService? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-simulateState"), index + 1 < args.count else { return nil }
        let value = args[index + 1].lowercased()
        let byte: UInt8?
        if value == "removed" { byte = nil } else { byte = UInt8(value, radix: 16) }
        let nvram = SimulatedNVRAM(byte: byte)
        return BootPreferenceService(reader: nvram, writer: nvram)
    }
}
#endif
