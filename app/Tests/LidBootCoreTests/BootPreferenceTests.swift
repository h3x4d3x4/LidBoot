import XCTest
@testable import LidBootCore

/// These lock down the 2x2 mapping between the two user-facing toggles and the
/// single NVRAM byte. Getting a bit inverted here would silently do the opposite
/// of what the user asked, so every state is asserted explicitly against the
/// values Apple documents.
final class BootPreferenceTests: XCTestCase {

    // MARK: - Behavior -> byte

    func testFactoryDefaultHasNoVariable() {
        // Both on == variable absent, not a written byte. This is what keeps
        // "revert" byte-for-byte identical to a machine that was never touched.
        XCTAssertNil(BootBehavior.factoryDefault.nvramByte)
        XCTAssertEqual(BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: true).nvramByte, nil)
    }

    func testNoLidBootIsHex01() {
        XCTAssertEqual(BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true).nvramByte, 0x01)
    }

    func testNoPowerBootIsHex02() {
        XCTAssertEqual(BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: false).nvramByte, 0x02)
    }

    func testNeitherIsHex00() {
        XCTAssertEqual(BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: false).nvramByte, 0x00)
    }

    // MARK: - Byte -> behavior

    func testAbsentVariableMeansStartsOnBoth() {
        XCTAssertEqual(BootBehavior(nvramByte: nil), .factoryDefault)
    }

    func testDecodesEachDocumentedByte() {
        XCTAssertEqual(BootBehavior(nvramByte: 0x00),
                       BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: false))
        XCTAssertEqual(BootBehavior(nvramByte: 0x01),
                       BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true))
        XCTAssertEqual(BootBehavior(nvramByte: 0x02),
                       BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: false))
    }

    func testUndocumentedByteIsRejectedRatherThanGuessed() {
        // We must not invent a meaning for a value Apple doesn't define.
        XCTAssertNil(BootBehavior(nvramByte: 0x03))
        XCTAssertNil(BootBehavior(nvramByte: 0xFF))
    }

    // MARK: - Round trip

    func testEveryStateRoundTrips() {
        for lid in [true, false] {
            for power in [true, false] {
                let original = BootBehavior(startsOnLidOpen: lid, startsOnPowerConnect: power)
                let decoded = BootBehavior(nvramByte: original.nvramByte)
                XCTAssertEqual(decoded, original, "round trip failed for lid=\(lid) power=\(power)")
            }
        }
    }

    func testFourDistinctStatesProduceFourDistinctEncodings() {
        let encodings = [
            BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: true).nvramByte,
            BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true).nvramByte,
            BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: false).nvramByte,
            BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: false).nvramByte
        ]
        XCTAssertEqual(Set(encodings).count, 4, "each toggle combination must map to a unique NVRAM state")
    }

    // MARK: - Commands

    func testCommandStringsMatchAppleDocumentedSyntax() {
        XCTAssertEqual(NVRAMCommand.set(0x00).shellCommand, "/usr/sbin/nvram BootPreference=%00")
        XCTAssertEqual(NVRAMCommand.set(0x01).shellCommand, "/usr/sbin/nvram BootPreference=%01")
        XCTAssertEqual(NVRAMCommand.set(0x02).shellCommand, "/usr/sbin/nvram BootPreference=%02")
        XCTAssertEqual(NVRAMCommand.delete.shellCommand, "/usr/sbin/nvram -d BootPreference")
    }

    func testDefaultBehaviorDeletesRatherThanWrites() {
        XCTAssertEqual(NVRAMCommand.command(for: .factoryDefault), .delete)
    }

    func testEachNonDefaultBehaviorWritesItsByte() {
        XCTAssertEqual(NVRAMCommand.command(for: BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true)), .set(0x01))
        XCTAssertEqual(NVRAMCommand.command(for: BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: false)), .set(0x02))
        XCTAssertEqual(NVRAMCommand.command(for: BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: false)), .set(0x00))
    }

    /// The safety property that matters most: no reachable command may touch any
    /// variable other than BootPreference — especially not `auto-boot`, which can
    /// leave an Apple silicon Mac unbootable.
    func testNoCommandEverTouchesAnotherNVRAMVariable() {
        let allCommands: [NVRAMCommand] = [.delete, .set(0x00), .set(0x01), .set(0x02)]
        for command in allCommands {
            XCTAssertTrue(command.shellCommand.hasPrefix("/usr/sbin/nvram "),
                          "must invoke nvram by absolute path: \(command.shellCommand)")
            XCTAssertTrue(command.shellCommand.contains("BootPreference"))
            XCTAssertFalse(command.shellCommand.lowercased().contains("auto-boot"))
            XCTAssertFalse(command.shellCommand.contains(";"), "no command chaining")
            XCTAssertFalse(command.shellCommand.contains("&&"), "no command chaining")
            XCTAssertFalse(command.shellCommand.contains("\""), "no quotes that could break out of the AppleScript literal")
        }
    }

    // MARK: - Reading the live machine

    func testReadingCurrentMachineDoesNotRequirePrivileges() {
        // Must not prompt, must not crash, must return something sane.
        // (Value depends on machine state, so we only assert it's well-formed.)
        switch SystemNVRAMReader().read() {
        case .known:
            break
        case .unrecognized(let byte):
            XCTFail("machine has an undocumented BootPreference value: \(byte)")
        case .unreadable(let reason):
            XCTFail("machine's BootPreference is unreadable: \(reason)")
        }
    }
}
