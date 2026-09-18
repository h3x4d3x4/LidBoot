import AppKit
import UserNotifications

/// Closes the feedback loop the popover can't.
///
/// The auth prompt steals focus and dismisses the popover, so by the time the
/// write lands, the toggle the user flipped is painted on a view that no longer
/// exists. The window survives (it just loses focus), so this is only posted
/// for changes that started in the popover.
///
/// Permission is requested lazily, on the first successful popover change:
/// asking at launch would be a prompt for a feature the user hasn't met yet.
/// A refusal is honored silently — the menu bar icon still carries the state.
@MainActor
final class SuccessNotification: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SuccessNotification()

    private var center: UNUserNotificationCenter? {
        // UNUserNotificationCenter traps when there is no bundle identifier,
        // which is the case for the bare executable under `swift run`-style
        // launches. Guarding here keeps Debug-from-anywhere working.
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    func install() {
        center?.delegate = self
    }

    func post(body: String) {
        guard let center else { return }
        Task {
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                guard (try? await center.requestAuthorization(options: [.alert])) == true else { return }
            case .denied:
                return
            default:
                break
            }
            let content = UNMutableNotificationContent()
            content.title = "LidBoot"
            content.body = body
            // One identifier: a second change replaces the first banner rather
            // than stacking two contradictory statements.
            let request = UNNotificationRequest(identifier: "lidboot.changed", content: content, trigger: nil)
            try? await center.add(request)
        }
    }

    // After the auth prompt the app is usually frontmost, and macOS would
    // otherwise swallow the banner — which is the whole point of posting it.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { WindowOpener.shared.open() }
    }
}
