import Foundation

/// `BootPreference` only exists on Apple silicon laptops running macOS 15 or
/// later. On anything else we disable the UI and say why, rather than writing a
/// variable whose meaning we can't vouch for.
///
/// Intel Macs are deliberately unsupported: they use a different variable
/// (`AutoBoot`) with different semantics, and guessing here risks an
/// unbootable machine.
public enum SystemSupport {
    public enum Unsupported: Equatable, Sendable {
        case notAppleSilicon
        case osTooOld(current: String)
        case notALaptop(model: String)

        public var explanation: String {
            switch self {
            case .notAppleSilicon:
                return "This setting only exists on Apple silicon Macs. Intel Macs use a different, riskier method that LidBoot won't touch."
            case .osTooOld(let current):
                return "This setting needs macOS 15 (Sequoia) or later. You're on \(current)."
            case .notALaptop(let model):
                return "This setting only applies to Mac laptops with a lid. This Mac is a \(model)."
            }
        }
    }

    public static func check() -> Unsupported? {
        guard sysctlInt("hw.optional.arm64") == 1 else {
            return .notAppleSilicon
        }

        let os = ProcessInfo.processInfo.operatingSystemVersion
        guard ProcessInfo.processInfo.isOperatingSystemAtLeast(
            OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)
        ) else {
            return .osTooOld(current: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        }

        let model = sysctlString("hw.model") ?? ""
        guard model.hasPrefix("MacBook") else {
            return .notALaptop(model: model.isEmpty ? "desktop Mac" : model)
        }

        return nil
    }

    // MARK: - sysctl helpers

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    static func sysctlInt(_ name: String) -> Int? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }
        return Int(value)
    }
}
