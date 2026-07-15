import Foundation
import IOKit

/// Reads the current `BootPreference` state.
///
/// Reading needs no privileges at all — only writing NVRAM requires root — so
/// the UI can always show the truth without ever prompting.
public protocol NVRAMReading: Sendable {
    func read() -> BootPreferenceState
}

/// The real thing: reads straight out of the IO registry.
public struct SystemNVRAMReader: NVRAMReading {
    private static let optionsPath = "IODeviceTree:/options"
    private static let variableName = "BootPreference"

    public init() {}

    public func read() -> BootPreferenceState {
        BootPreferenceDecoder.decode(Self.rawProperty())
    }

    /// The raw IO registry property, or nil when the variable is absent.
    private static func rawProperty() -> Any? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, optionsPath)
        guard entry != MACH_PORT_NULL else { return nil }
        defer { IOObjectRelease(entry) }

        guard let property = IORegistryEntryCreateCFProperty(
            entry, variableName as CFString, kCFAllocatorDefault, 0
        ) else {
            return nil
        }
        return property.takeRetainedValue()
    }
}
