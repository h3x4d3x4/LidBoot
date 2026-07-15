import SwiftUI
import ServiceManagement
import os

/// Launch at login via `SMAppService.mainApp`.
///
/// Note this is the *unprivileged* half of ServiceManagement — it registers the
/// app itself as a login item. It has nothing to do with privileged helpers
/// (SMJobBless/SMAppService.daemon), which LidBoot deliberately does not use.
@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published private(set) var isEnabled = false
    /// macOS 13+ can park a registration behind user approval in System Settings.
    /// Silently showing "off" in that case would look like a bug.
    @Published private(set) var needsApproval = false
    @Published private(set) var errorMessage: String?

    private static let log = Logger(subsystem: "com.lidboot.LidBoot", category: "login")

    init() { refresh() }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            isEnabled = true; needsApproval = false
        case .requiresApproval:
            isEnabled = true; needsApproval = true
        case .notRegistered, .notFound:
            isEnabled = false; needsApproval = false
        @unknown default:
            isEnabled = false; needsApproval = false
        }
    }

    func set(_ enabled: Bool) {
        errorMessage = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.log.error("launch at login \(enabled ? "register" : "unregister") failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = "Couldn't change this setting."
        }
        refresh()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

struct LaunchAtLoginToggle: View {
    @ObservedObject var model: LaunchAtLoginModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Toggle(isOn: Binding(get: { model.isEnabled }, set: { model.set($0) })) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Open at login").font(.system(size: 12))
                    Text("Keeps your choice active without opening LidBoot")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)

            if model.needsApproval {
                Button {
                    model.openLoginItemsSettings()
                } label: {
                    NoticeRow(symbol: "exclamationmark.circle",
                              text: "Needs approval in System Settings › Login Items. Click to open.",
                              tint: .orange)
                }
                .buttonStyle(.plain)
            }

            if let errorMessage = model.errorMessage {
                NoticeRow(symbol: "exclamationmark.triangle.fill", text: errorMessage, tint: .orange)
            }
        }
    }
}
