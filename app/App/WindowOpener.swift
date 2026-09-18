import SwiftUI
import AppKit

/// Bridges `openWindow` (a SwiftUI environment value, only reachable from a
/// view) to `AppDelegate` (plain AppKit, no environment).
///
/// This exists because `applicationShouldHandleReopen` returning `true` does not
/// reopen a closed SwiftUI `Window` scene — AppKit's default reopen has no
/// NSWindow to unhide, so the Dock icon click silently did nothing.
@MainActor
final class WindowOpener {
    static let shared = WindowOpener()
    private init() {}

    /// Captured by `windowOpener()` from a live view's environment.
    var openWindowAction: ((String) -> Void)?
    var openSettingsAction: (() -> Void)?

    func open(_ id: String = WindowID.main) {
        openWindowAction?(id)
        bringFront(autosaveName: id)
    }

    /// Settings, from anywhere — the popover's gear menu, a URL.
    ///
    /// Not `SettingsLink`: in menu-bar-only mode the app is an accessory and
    /// usually not active when the popover is clicked, and in that state
    /// `SettingsLink` silently does nothing (measured on macOS 26 — the
    /// popover closes, no window appears). `openSettings` is the same scene
    /// through an action we control, so we can activate first and then make
    /// sure the window actually lands in front.
    func openSettings() {
        openSettingsAction?()
        bringFront(autosaveName: "com_apple_SwiftUI_Settings_window")
    }

    /// An accessory app opening a window doesn't become active on its own, so
    /// the window can appear behind whatever was frontmost — indistinguishable
    /// from "nothing happened". SwiftUI creates the window asynchronously,
    /// hence the hop.
    private func bringFront(autosaveName: String) {
        NSApp.activate()
        DispatchQueue.main.async {
            NSApp.activate()
            NSApp.windows.first { $0.frameAutosaveName == autosaveName }?.makeKeyAndOrderFront(nil)
        }
    }
}

private struct WindowOpenerModifier: ViewModifier {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    func body(content: Content) -> some View {
        content.onAppear {
            WindowOpener.shared.openWindowAction = { id in openWindow(id: id) }
            WindowOpener.shared.openSettingsAction = { openSettings() }
        }
    }
}

/// Refreshes the model whenever the app becomes active.
///
/// The NVRAM value can change under us (someone runs `sudo nvram` in Terminal),
/// and a long-lived window would otherwise keep showing a stale toggle. No
/// polling — this value changes approximately never, so activation is enough.
private struct RefreshOnActivateModifier: ViewModifier {
    let model: LidBootModel

    func body(content: Content) -> some View {
        content.onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            model.refresh()
        }
    }
}

extension View {
    func windowOpener() -> some View { modifier(WindowOpenerModifier()) }

    func refreshOnActivate(_ model: LidBootModel) -> some View {
        modifier(RefreshOnActivateModifier(model: model))
    }
}
