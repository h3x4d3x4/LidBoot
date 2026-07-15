import SwiftUI
import AppKit

@main
struct LidBootApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = LidBootModel()
    @StateObject private var updater = UpdaterModel()
    @AppStorage(AppMode.defaultsKey) private var mode: AppMode = .both
    @AppStorage(AppAppearance.defaultsKey) private var appearance: AppAppearance = .system

    var body: some Scene {
        Window("Lid Boot", id: WindowID.main) {
            MainWindowView(model: model)
                // Gives AppDelegate a way to reopen this window: returning true
                // from applicationShouldHandleReopen does nothing on its own,
                // because a closed SwiftUI Window has no NSWindow to unhide.
                .windowOpener()
                .refreshOnActivate(model)
                .preferredColorScheme(appearance.colorScheme)
        }
        .windowResizability(.contentSize)
        // The view draws its own title, so the chrome would just repeat it.
        .windowStyle(.hiddenTitleBar)
        // Launch-time only. Runtime mode changes are handled by
        // applyActivationPolicy() — don't try to make this reactive.
        .defaultLaunchBehavior(mode.showsDock ? .presented : .suppressed)
        // NB: do NOT add .restorationBehavior(.disabled) here. It reads like the
        // fix for "macOS remembers the window was closed and reopens nothing",
        // but measured behaviour is that it suppresses the window at launch
        // entirely — you get a Dock icon and no UI at all. If the restore-closed
        // case needs fixing, do it via AppDelegate, not here.
        .commands {
            // A single-window utility has no use for a New Window item.
            CommandGroup(replacing: .newItem) {}
            // In menu-bar-only mode the app is an accessory: no app menu, so no
            // system Cmd-Q. Without this, a user with the window focused has to
            // go hunt for the status item — which may not be visible at all.
            CommandGroup(replacing: .appTermination) {
                Button("Quit Lid Boot") { NSApplication.shared.terminate(nil) }
                    .keyboardShortcut("q", modifiers: .command)
            }
            CommandGroup(replacing: .help) {
                Link("Lid Boot Help", destination: AppLinks.appleSupport)
            }
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .disabled(!updater.canCheck)
            }
        }

        Settings {
            SettingsView(model: model, mode: $mode, updater: updater)
                .preferredColorScheme(appearance.colorScheme)
        }

        MenuBarExtra(isInserted: menuBarInsertion) {
            MenuView(model: model, updater: updater)
                .preferredColorScheme(appearance.colorScheme)
        } label: {
            // The auth prompt steals focus and dismisses the popover, so after a
            // change the popover's own feedback is painted on a view that no
            // longer exists. The tooltip/label is then the only way to answer
            // "which state am I in?" without reopening it.
            Image(systemName: model.menuBarSymbol)
                .accessibilityLabel(model.summary)
                .help(model.summary)
                // Also capture openWindow here, not only from the window's own
                // view: in menu-bar-only mode the window is suppressed at
                // launch, so it never appears, so it could never register the
                // opener — leaving "Open Lid Boot…" dead in exactly the mode
                // where it's the documented way back in.
                .windowOpener()
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
        MainActor.assumeIsolated {
            AppMode.current.applyActivationPolicy()
            // Before the first frame, or you get a flash of the wrong appearance.
            AppAppearance.current.apply()
        }
    }

    // NB: there is no programmatic way to open the Settings scene here.
    // `NSApp.sendAction(Selector(("showSettingsWindow:")))` — and the older
    // `showPreferencesWindow:` — both no-op against a SwiftUI `Settings` scene
    // (tried, measured, deleted). `SettingsLink` is the only reliable route,
    // which is exactly why the popover's gear menu uses one.

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
