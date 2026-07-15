import XCTest
@testable import LidBootCore

// MARK: - Fakes

/// Returns a scripted sequence of states, so a test can model "the write landed"
/// or "the write silently didn't take".
final class FakeReader: NVRAMReading, @unchecked Sendable {
    private let lock = NSLock()
    private var responses: [BootPreferenceState]
    private(set) var readCount = 0

    init(always: BootPreferenceState) { self.responses = [always] }
    init(sequence: [BootPreferenceState]) { self.responses = sequence }

    func read() -> BootPreferenceState {
        lock.lock(); defer { lock.unlock() }
        readCount += 1
        if responses.count > 1 { return responses.removeFirst() }
        return responses[0]
    }
}

/// An actor rather than a lock: `run` is async, and locking across a suspension
/// point is an error under the Swift 6 language mode.
actor FakeWriter: NVRAMWriting {
    private(set) var commands: [NVRAMCommand] = []
    private let errorToThrow: Error?

    init(throwing error: Error? = nil) { self.errorToThrow = error }

    private(set) var prompts: [String] = []

    func run(_ command: NVRAMCommand, prompt: String) async throws {
        commands.append(command)
        prompts.append(prompt)
        if let errorToThrow { throw errorToThrow }
    }
}

// MARK: - Service

final class BootPreferenceServiceTests: XCTestCase {

    func testApplyingFactoryDefaultDeletesTheVariable() async throws {
        let writer = FakeWriter()
        let service = BootPreferenceService(reader: FakeReader(always: .known(.factoryDefault)), writer: writer)

        try await service.apply(.factoryDefault, prompt: "test")

        // Must delete, never write a "default" byte over the factory state.
        let commands = await writer.commands
        XCTAssertEqual(commands, [.delete])
    }

    func testApplyingEachBehaviorSendsTheRightCommand() async throws {
        let cases: [(BootBehavior, NVRAMCommand)] = [
            (BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true), .set(0x01)),
            (BootBehavior(startsOnLidOpen: true, startsOnPowerConnect: false), .set(0x02)),
            (BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: false), .set(0x00))
        ]
        for (behavior, expected) in cases {
            let writer = FakeWriter()
            let service = BootPreferenceService(reader: FakeReader(always: .known(behavior)), writer: writer)
            try await service.apply(behavior, prompt: "test")
            let commands = await writer.commands
            XCTAssertEqual(commands, [expected], "wrong command for \(behavior)")
        }
    }

    func testWriteThatDoesNotStickThrowsVerificationFailed() async {
        let target = BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true)
        // nvram exits 0 but the machine still reports the old value.
        let service = BootPreferenceService(reader: FakeReader(always: .known(.factoryDefault)),
                                            writer: FakeWriter())
        do {
            try await service.apply(target, prompt: "test")
            XCTFail("a write that didn't take must not be reported as success")
        } catch let error as NVRAMWriteError {
            XCTAssertEqual(error, .verificationFailed(expected: target))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testVerificationRejectsRefusedStateAfterWrite() async {
        let target = BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true)
        let service = BootPreferenceService(reader: FakeReader(always: .unrecognized(0x09)),
                                            writer: FakeWriter())
        do {
            try await service.apply(target, prompt: "test")
            XCTFail("reading back an unrecognised value must fail verification")
        } catch let error as NVRAMWriteError {
            XCTAssertEqual(error, .verificationFailed(expected: target))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testWriterErrorPropagatesAndSkipsVerification() async {
        let writer = FakeWriter(throwing: NVRAMWriteError.cancelled)
        let reader = FakeReader(always: .known(.factoryDefault))
        let service = BootPreferenceService(reader: reader, writer: writer)

        do {
            try await service.apply(BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: true), prompt: "test")
            XCTFail("expected cancellation to propagate")
        } catch let error as NVRAMWriteError {
            XCTAssertEqual(error, .cancelled)
            XCTAssertEqual(reader.readCount, 0, "must not verify a write that never happened")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}

// MARK: - Error mapping

final class AppleScriptErrorMapperTests: XCTestCase {

    func testUserCancelCodesMapToCancelled() {
        // -128 is AppleScript's cancel; -60006 is errAuthorizationCanceled,
        // which the auth prompt can raise instead. Both are "user backed out"
        // and must never surface as an error.
        XCTAssertEqual(AppleScriptErrorMapper.map(code: -128, message: "User cancelled."), .cancelled)
        XCTAssertEqual(AppleScriptErrorMapper.map(code: -60006, message: ""), .cancelled)
    }

    func testDeniedAndNotAllowedGetTheirOwnCases() {
        XCTAssertEqual(AppleScriptErrorMapper.map(code: -60005, message: ""), .authorizationDenied)
        XCTAssertEqual(AppleScriptErrorMapper.map(code: -60007, message: ""), .interactionNotAllowed)
    }

    func testUnknownCodeFallsBackToScriptFailed() {
        XCTAssertEqual(AppleScriptErrorMapper.map(code: -1, message: "boom"),
                       .scriptFailed(code: -1, message: "boom"))
    }
}

// MARK: - System support

final class SystemSupportTests: XCTestCase {
    private func probe(appleSilicon: Bool = true,
                       hasLid: Bool = true,
                       osAtLeast: Bool = true,
                       osVersion: String = "26.5.2") -> SystemProbe {
        SystemProbe(isAppleSilicon: { appleSilicon },
                    hasLid: { hasLid },
                    isOperatingSystemAtLeast: { _ in osAtLeast },
                    osVersionString: { osVersion })
    }

    func testSupportedMachineReturnsNil() {
        XCTAssertNil(SystemSupport.check(probe: probe()))
    }

    func testIntelIsRefused() {
        // Intel uses a different variable (AutoBoot) with different semantics.
        XCTAssertEqual(SystemSupport.check(probe: probe(appleSilicon: false)), .notAppleSilicon)
    }

    func testOldOSIsRefused() {
        XCTAssertEqual(SystemSupport.check(probe: probe(osAtLeast: false, osVersion: "14.6.1")),
                       .osTooOld(current: "14.6.1"))
    }

    func testDesktopIsRefused() {
        XCTAssertEqual(SystemSupport.check(probe: probe(hasLid: false)), .notALaptop)
    }

    /// Regression: the old check was `hw.model.hasPrefix("MacBook")`, which
    /// passes on M1 machines (MacBookPro18,1) and rejects every MacBook Apple
    /// has shipped since 2022 — an M2 Air reports Mac14,2, an M4 Mac16,x.
    /// Support must depend on having a lid, not on the model string.
    func testModernMacBooksAreSupported() {
        // Apple silicon + macOS 15+ + a lid, whatever the marketing name.
        XCTAssertNil(SystemSupport.check(probe: probe(hasLid: true)))
    }

    func testArchitectureIsCheckedBeforeOS() {
        // An Intel Mac on macOS 14 should say "Intel", not "old macOS".
        XCTAssertEqual(SystemSupport.check(probe: probe(appleSilicon: false, osAtLeast: false)),
                       .notAppleSilicon)
    }
}
