import AppKit
import LidBootCore
import os

/// `lidboot://` — the switches as URLs, for Shortcuts, Raycast, Alfred and
/// shell scripts (`open lidboot://lid/off`).
///
///     lidboot://lid/off      lidboot://lid/on
///     lidboot://power/off    lidboot://power/on
///     lidboot://all/off      lidboot://all/on   (= Restore Default)
///     lidboot://restore
///     lidboot://open
///
/// Every change still goes through the same auth prompt, the same closed enum
/// and the same read-back verification as a click — a URL can't do anything a
/// click can't, and can't skip the password. The window is brought up first so
/// the prompt never appears out of nowhere: the user sees which switch is
/// about to move, and where the result landed.
@MainActor
enum URLCommand {
    static let scheme = "lidboot"
    private static let log = Logger(subsystem: "com.lidboot.LidBoot", category: "url")

    static func handle(_ url: URL, model: LidBootModel = .shared) {
        guard url.scheme?.lowercased() == scheme else { return }
        let verb = url.host?.lowercased() ?? ""
        let argument = url.pathComponents.dropFirst().first?.lowercased()

        // Context first, prompt second.
        WindowOpener.shared.open()
        NSApplication.shared.activate()

        guard let current = model.behavior else {
            // Unsupported, unreadable, or refused: the window now explains why.
            log.notice("Ignored \(url.absoluteString, privacy: .public): no readable state")
            return
        }

        var desired = current
        switch (verb, argument) {
        case ("open", _):
            return
        case ("lid", "on"):     desired.startsOnLidOpen = true
        case ("lid", "off"):    desired.startsOnLidOpen = false
        case ("power", "on"):   desired.startsOnPowerConnect = true
        case ("power", "off"):  desired.startsOnPowerConnect = false
        case ("all", "on"), ("restore", _):
            desired = .factoryDefault
        case ("all", "off"):
            desired = BootBehavior(startsOnLidOpen: false, startsOnPowerConnect: false)
        default:
            log.error("Unrecognized URL \(url.absoluteString, privacy: .public)")
            return
        }

        Task { await model.apply(desired, from: .url) }
    }
}
