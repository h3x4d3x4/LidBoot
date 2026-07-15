import SwiftUI
import AppKit

/// Where LidBoot lives: a menu bar item, a normal Dock app with a window, or both.
///
/// The app ships as `LSUIElement` (accessory) and is *promoted* to a regular
/// Dock app at runtime when the user asks for it. Doing it this way round means
/// menu-bar-only users never see a Dock icon flash at launch.
enum AppMode: String, CaseIterable, Identifiable {
    case menuBar
    case dock
    case both

    var id: String { rawValue }

    /// Localised: this is handed to Text(_: String), which does no lookup.
    var label: String {
        switch self {
        case .menuBar: return String(localized: "Menu Bar")
        case .dock: return String(localized: "Dock")
        case .both: return String(localized: "Both")
        }
    }

    var showsMenuBar: Bool { self != .dock }
    var showsDock: Bool { self != .menuBar }

    static let defaultsKey = "appMode"

    /// Read straight from UserDefaults, for use before any SwiftUI view exists.
    static var current: AppMode {
        AppMode(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .both
    }

    @MainActor
    func applyActivationPolicy() {
        NSApp.setActivationPolicy(showsDock ? .regular : .accessory)
    }
}
