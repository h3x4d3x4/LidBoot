import XCTest
@testable import LidBootCore

/// The reader's parsing, which used to silently claim "factory default" for
/// values it didn't understand — letting the app overwrite a state it never
/// parsed. Every not-a-single-documented-byte input must refuse.
final class BootPreferenceDecoderTests: XCTestCase {

    func testAbsentVariableIsFactoryDefault() {
        XCTAssertEqual(BootPreferenceDecoder.decode(nil), .known(.factoryDefault))
    }

    func testDocumentedBytesDecode() {
        XCTAssertEqual(BootPreferenceDecoder.decode(Data([0x00])),
                       .known(BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: false)))
        XCTAssertEqual(BootPreferenceDecoder.decode(Data([0x01])),
                       .known(BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true)))
        XCTAssertEqual(BootPreferenceDecoder.decode(Data([0x02])),
                       .known(BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: false)))
    }

    func testUndocumentedByteIsUnrecognizedNotDefault() {
        XCTAssertEqual(BootPreferenceDecoder.decode(Data([0x03])), .unrecognized(0x03))
        XCTAssertEqual(BootPreferenceDecoder.decode(Data([0xFF])), .unrecognized(0xFF))
    }

    // The regression this whole decoder exists for: a present-but-odd value
    // must never come back as `.known`.

    func testEmptyDataIsUnreadable() {
        guard case .unreadable = BootPreferenceDecoder.decode(Data()) else {
            return XCTFail("empty Data must be refused, not reported as a known state")
        }
    }

    func testMultiByteDataIsUnreadable() {
        guard case .unreadable = BootPreferenceDecoder.decode(Data([0x01, 0x02])) else {
            return XCTFail("multi-byte Data must be refused")
        }
    }

    func testNonDataTypeIsUnreadable() {
        guard case .unreadable = BootPreferenceDecoder.decode("hello" as NSString) else {
            return XCTFail("a string value must be refused")
        }
        guard case .unreadable = BootPreferenceDecoder.decode(42 as NSNumber) else {
            return XCTFail("a number value must be refused")
        }
    }

    func testEveryRefusedStateReportsRefused() {
        XCTAssertTrue(BootPreferenceDecoder.decode(Data([0x03])).isRefused)
        XCTAssertTrue(BootPreferenceDecoder.decode(Data()).isRefused)
        XCTAssertTrue(BootPreferenceDecoder.decode("x" as NSString).isRefused)
        XCTAssertFalse(BootPreferenceDecoder.decode(nil).isRefused)
        XCTAssertFalse(BootPreferenceDecoder.decode(Data([0x01])).isRefused)
    }
}
