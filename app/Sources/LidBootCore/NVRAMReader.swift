import Foundation
import IOKit

/// Reads `BootPreference` straight out of the IO registry.
///
/// This needs no privileges at all — only writing NVRAM requires root — so the
/// menu can always show the true current state without ever prompting.
public enum NVRAMReader {
    private static let optionsPath = "IODeviceTree:/options"
    private static let variableName = "BootPreference"

    public static func read() -> BootPreferenceState {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, optionsPath)
        guard entry != MACH_PORT_NULL else {
            // No options node at all: nothing has been set, so we're at default.
            return .known(.factoryDefault)
        }
        defer { IOObjectRelease(entry) }

        guard let property = IORegistryEntryCreateCFProperty(
            entry, variableName as CFString, kCFAllocatorDefault, 0
        ) else {
            // Variable absent == factory default (starts on both lid and power).
            return .known(.factoryDefault)
        }

        let value = property.takeRetainedValue()

        // nvram stores this as a single raw byte of CFData.
        guard let data = value as? Data, let byte = data.first, data.count == 1 else {
            if let data = value as? Data, let byte = data.first {
                return .unrecognized(byte)
            }
            return .known(.factoryDefault)
        }

        guard let behavior = BootBehavior(nvramByte: byte) else {
            return .unrecognized(byte)
        }
        return .known(behavior)
    }
}
