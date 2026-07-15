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

    var label: String {
        switch self {
        case .menuBar: return "Menu Bar"
        case .dock: return "Dock"
        case .both: return "Both"
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
