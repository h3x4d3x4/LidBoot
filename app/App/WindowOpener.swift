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

    func open(_ id: String = WindowID.main) {
        openWindowAction?(id)
        NSApp.activate()
    }
}

private struct WindowOpenerModifier: ViewModifier {
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            WindowOpener.shared.openWindowAction = { id in openWindow(id: id) }
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
