import SwiftUI
import AppKit
import os

/// Light / Dark / System, applied app-wide.
///
/// `System` is the default and means "don't override" — `NSApp.appearance = nil`
/// lets the app follow the system setting, which is what almost everyone wants
/// and what macOS does for free. The other two exist for people who want this
/// one window to disagree with their system, which is a real preference for a
/// utility that mostly lives in the menu bar.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// Localized: handed to `Text(_: String)`, which does no lookup.
    var label: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }

    /// What SwiftUI scenes honour. nil = follow the system.
    ///
    /// This is the one that actually works: setting `NSApp.appearance` alone is
    /// measurably ignored by SwiftUI `Window`/`MenuBarExtra`/`Settings` scenes
    /// (verified — the property reads back as Aqua while the window stays dark).
    /// `preferredColorScheme` drives the scenes; `NSApp.appearance` is still set
    /// alongside so AppKit-drawn chrome agrees.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    /// nil means "follow the system" — not "no appearance".
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    static let defaultsKey = "appearance"

    /// Read straight from UserDefaults, for use before any SwiftUI view exists.
    static var current: AppAppearance {
        AppAppearance(rawValue: UserDefaults.standard.string(forKey: defaultsKey) ?? "") ?? .system
    }

    private static let log = Logger(subsystem: "com.lidboot.LidBoot", category: "appearance")

    @MainActor
    func apply() {
        // Setting this on NSApp covers every surface at once — window, popover
        // and Settings — so they can't disagree with each other.
        NSApp.appearance = nsAppearance
        Self.log.info("applied appearance=\(self.rawValue, privacy: .public)")
    }
}

struct AppearancePicker: View {
    @Binding var appearance: AppAppearance

    var body: some View {
        Picker("Appearance", selection: binding) {
            ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.segmented)
    }

    private var binding: Binding<AppAppearance> {
        Binding(
            get: { appearance },
            set: { newValue in
                appearance = newValue
                newValue.apply()
            }
        )
    }
}
