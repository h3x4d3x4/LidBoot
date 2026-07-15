import Foundation
import IOKit

/// The machine facts LidBoot's support check depends on.
///
/// Injectable so the unsupported branches can be tested — otherwise they'd only
/// ever run on hardware we don't have, which is exactly how the old
/// `hw.model.hasPrefix("MacBook")` check survived: it happened to pass on the
/// development machine and rejected every newer MacBook.
public struct SystemProbe: Sendable {
    public var isAppleSilicon: @Sendable () -> Bool
    /// Does this Mac physically have a lid?
    public var hasLid: @Sendable () -> Bool
    public var isOperatingSystemAtLeast: @Sendable (OperatingSystemVersion) -> Bool
    public var osVersionString: @Sendable () -> String

    public init(
        isAppleSilicon: @escaping @Sendable () -> Bool,
        hasLid: @escaping @Sendable () -> Bool,
        isOperatingSystemAtLeast: @escaping @Sendable (OperatingSystemVersion) -> Bool,
        osVersionString: @escaping @Sendable () -> String
    ) {
        self.isAppleSilicon = isAppleSilicon
        self.hasLid = hasLid
        self.isOperatingSystemAtLeast = isOperatingSystemAtLeast
        self.osVersionString = osVersionString
    }

    public static let live = SystemProbe(
        isAppleSilicon: { Sysctl.int("hw.optional.arm64") == 1 },
        hasLid: { Hardware.hasClamshell() },
        isOperatingSystemAtLeast: { ProcessInfo.processInfo.isOperatingSystemAtLeast($0) },
        osVersionString: {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        }
    )
}

/// `BootPreference` only exists on Apple silicon laptops running macOS 15 or
/// later. On anything else we disable the UI and say why, rather than writing a
/// variable whose meaning we can't vouch for.
///
/// Intel Macs are deliberately unsupported: they use a different variable
/// (`AutoBoot`) with different semantics, and guessing here risks an
/// unbootable machine.
public enum SystemSupport {
    /// Why this Mac can't use the setting. Wording lives in the app layer
    /// (App/Localization.swift) — this module stays presentation-free.
    public enum Unsupported: Equatable, Sendable {
        case notAppleSilicon
        case osTooOld(current: String)
        case notALaptop
    }

    /// The macOS version that introduced `BootPreference`.
    static let minimumOS = OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)

    public static func check(probe: SystemProbe = .live) -> Unsupported? {
        guard probe.isAppleSilicon() else {
            return .notAppleSilicon
        }
        guard probe.isOperatingSystemAtLeast(minimumOS) else {
            return .osTooOld(current: probe.osVersionString())
        }
        guard probe.hasLid() else {
            return .notALaptop
        }
        return nil
    }
}

enum Hardware {
    /// True when this Mac has a clamshell (a lid).
    ///
    /// Deliberately asks the hardware instead of pattern-matching `hw.model`.
    /// Apple stopped using "MacBook…" identifiers in 2022 — an M2 Air reports
    /// `Mac14,2` and an M4 Pro reports `Mac16,x` — so any name-based check
    /// silently rejects newer laptops and needs updating every autumn.
    /// `AppleClamshellState` exists only on machines that have a lid.
    static func hasClamshell() -> Bool {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }

        guard let property = IORegistryEntryCreateCFProperty(
            root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0
        ) else {
            return false
        }
        _ = property.takeRetainedValue()
        return true
    }
}

enum Sysctl {
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        // sysctl returns a null-terminated string; drop the terminator before
        // decoding (String(cString:) is deprecated in Swift 6).
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    static func int(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }
}
