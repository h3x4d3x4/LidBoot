import Foundation

/// What the Mac does when you open the lid or plug in power.
///
/// These two switches are independent, which is why the UI shows two toggles
/// rather than exposing the raw NVRAM byte.
public struct BootBehavior: Equatable, Sendable {
    public var startsOnLidOpen: Bool
    public var startsOnPowerConnect: Bool

    public init(startsOnLidOpen: Bool, startsOnPowerConnect: Bool) {
        self.startsOnLidOpen = startsOnLidOpen
        self.startsOnPowerConnect = startsOnPowerConnect
    }

    /// How the Mac ships: starts up on both.
    public static let factoryDefault = BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: true)
}

extension BootBehavior {
    /// The `BootPreference` NVRAM byte for this behavior, or `nil` when the
    /// variable should be absent entirely (the factory default).
    ///
    /// Apple documents only three values; the fourth state is "no variable".
    ///   %00 → neither lid nor power starts the Mac
    ///   %01 → lid does not start the Mac, power does
    ///   %02 → power does not start the Mac, lid does
    public var nvramByte: UInt8? {
        switch (startsOnLidOpen, startsOnPowerConnect) {
        case (true, true): return nil
        case (false, true): return 0x01
        case (true, false): return 0x02
        case (false, false): return 0x00
        }
    }

    /// Inverse of `nvramByte`. Returns `nil` for a byte Apple has not documented,
    /// so the caller can refuse to guess rather than silently misreport.
    public init?(nvramByte: UInt8?) {
        switch nvramByte {
        case .none: self = .factoryDefault
        case .some(0x00): self = BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: false)
        case .some(0x01): self = BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true)
        case .some(0x02): self = BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: false)
        case .some: return nil
        }
    }
}

/// What we actually found in NVRAM.
public enum BootPreferenceState: Equatable, Sendable {
    case known(BootBehavior)
    /// Something wrote a value Apple doesn't document. We show a warning and
    /// refuse to interpret it rather than stomping on it blindly.
    case unrecognized(UInt8)
}

/// The complete set of commands this app is ever allowed to run.
///
/// Deliberately a closed enum: there is no code path that builds an `nvram`
/// invocation from arbitrary input, and no path that touches any variable other
/// than `BootPreference`. In particular we never write `auto-boot`, which is
/// widely reported to cause boot failures on Apple silicon.
public enum NVRAMCommand: Equatable, Sendable {
    case set(UInt8)
    case delete

    /// The literal executed as root. Note the absolute path to `nvram`.
    public var shellCommand: String {
        switch self {
        case .delete:
            return "/usr/sbin/nvram -d BootPreference"
        case .set(let byte):
            // nvram's escape syntax for a raw byte, e.g. 0x01 → "%01".
            return "/usr/sbin/nvram BootPreference=%\(String(format: "%02x", byte))"
        }
    }

    /// The command that puts the machine into `behavior`.
    public static func command(for behavior: BootBehavior) -> NVRAMCommand {
        if let byte = behavior.nvramByte {
            return .set(byte)
        }
        // Factory default is expressed by removing the variable, which leaves
        // NVRAM exactly as it shipped.
        return .delete
    }
}
