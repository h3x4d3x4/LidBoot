import SwiftUI
import AppKit

@main
struct LidBootApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = LidBootModel()
    @AppStorage(AppMode.defaultsKey) private var mode: AppMode = .both

    var body: some Scene {
        Window("LidBoot", id: "main") {
            MainWindowView(model: model, mode: $mode)
        }
        .windowResizability(.contentSize)
        // The view draws its own title, so the chrome would just repeat it.
        .windowStyle(.hiddenTitleBar)
        // Menu-bar-only users shouldn't get a window thrown at them on launch.
        .defaultLaunchBehavior(mode.showsDock ? .presented : .suppressed)
        .commands {
            // A menu-bar-only utility has no use for a New Window item.
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra(isInserted: Binding(get: { mode.showsMenuBar }, set: { _ in })) {
            MenuView(model: model, mode: $mode)
        } label: {
            // Badge the icon when auto start-up is limited, so the menu bar
            // reflects the machine's state at a glance.
            Image(systemName: model.isModified ? "laptopcomputer.trianglebadge.exclamationmark" : "laptopcomputer")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set the Dock/accessory policy before the first frame so the Dock icon
    /// doesn't appear and then vanish (or vice versa).
    func applicationWillFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated { AppMode.current.applyActivationPolicy() }
    }

    /// Clicking the Dock icon with no window open should bring the window back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    /// Closing the window shouldn't quit a utility that may still live in the
    /// menu bar — but a Dock-only app with no windows has nothing left to show.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !AppMode.current.showsMenuBar
    }
}
