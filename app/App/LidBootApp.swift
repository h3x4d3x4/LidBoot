import SwiftUI
import AppKit

@main
struct LidBootApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = LidBootModel()
    @AppStorage(AppMode.defaultsKey) private var mode: AppMode = .both

    var body: some Scene {
        Window("LidBoot", id: WindowID.main) {
            MainWindowView(model: model, mode: $mode)
                // Gives AppDelegate a way to reopen this window: returning true
                // from applicationShouldHandleReopen does nothing on its own,
                // because a closed SwiftUI Window has no NSWindow to unhide.
                .windowOpener()
                .refreshOnActivate(model)
        }
        .windowResizability(.contentSize)
        // The view draws its own title, so the chrome would just repeat it.
        .windowStyle(.hiddenTitleBar)
        // Launch-time only. Runtime mode changes are handled by
        // applyActivationPolicy() — don't try to make this reactive.
        .defaultLaunchBehavior(mode.showsDock ? .presented : .suppressed)
        .commands {
            // A single-window utility has no use for a New Window item.
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra(isInserted: menuBarInsertion) {
            MenuView(model: model, mode: $mode)
        } label: {
            Image(systemName: model.isModified ? "laptopcomputer.slash" : "laptopcomputer")
        }
        .menuBarExtraStyle(.window)
    }

    /// Honors the user dragging the status item out of the menu bar (Cmd-drag).
    /// macOS drives this to false; ignoring it would leave `mode` claiming an
    /// item exists that doesn't — and in menu-bar-only mode, that would strand
    /// the app with no way to reach it. Falling back to the Dock guarantees
    /// there's always a way back in.
    private var menuBarInsertion: Binding<Bool> {
        Binding(
            get: { mode.showsMenuBar },
            set: { inserted in
                guard !inserted, mode.showsMenuBar else { return }
                mode = .dock
                mode.applyActivationPolicy()
            }
        )
    }
}

enum WindowID {
    static let main = "main"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set the Dock/accessory policy before the first frame so the Dock icon
    /// doesn't appear and then vanish (or vice versa). This is the only thing
    /// making the Dock icon correct at launch — LSUIElement is statically true
    /// and we promote from it at runtime.
    func applicationWillFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AppMode.current.applyActivationPolicy() }
    }

    /// Clicking the Dock icon, or relaunching from Finder, must always surface
    /// something. In menu-bar-only mode there may be no visible status item at
    /// all (a full menu bar silently drops extras), so the window is the only
    /// reliable way back in.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainActor.assumeIsolated { WindowOpener.shared.open() }
        }
        return true
    }

    /// Closing the window shouldn't quit a utility that still lives in the menu
    /// bar — but a Dock-only app with no windows has nothing left to show.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !AppMode.current.showsMenuBar
    }
}
