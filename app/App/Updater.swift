import SwiftUI
import Sparkle
import os

/// Sparkle auto-update.
///
/// Same model as Observio: the app is built, signed and notarized locally, then
/// the DMG and appcast are published to a *public* releases repo. Integrity
/// comes from the EdDSA signature (`SUPublicEDKey` in Info.plist), not from the
/// feed being private — which is why the source repo can stay private and the
/// app still needs no token to update.
@MainActor
final class UpdaterModel: ObservableObject {
    private let controller: SPUStandardUpdaterController
    private static let log = Logger(subsystem: "com.lidboot.LidBoot", category: "updates")

    @Published private(set) var canCheck = true
    @Published var automaticallyChecks: Bool {
        didSet { controller.updater.automaticallyChecksForUpdates = automaticallyChecks }
    }
    @Published private(set) var lastCheck: Date?

    init() {
        // startingUpdater: true — Sparkle schedules its own background checks.
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        lastCheck = controller.updater.lastUpdateCheckDate

        controller.updater.publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheck)
    }

    func checkForUpdates() {
        Self.log.info("manual update check")
        controller.updater.checkForUpdates()
        lastCheck = controller.updater.lastUpdateCheckDate
    }

    var feedURL: String {
        Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "—"
    }
}

struct UpdatesSettingsView: View {
    @ObservedObject var model: UpdaterModel

    var body: some View {
        Form {
            Section {
                Toggle("Check for updates automatically", isOn: $model.automaticallyChecks)

                HStack {
                    Button("Check Now") { model.checkForUpdates() }
                        .disabled(!model.canCheck)
                    if let lastCheck = model.lastCheck {
                        Text("Last checked \(lastCheck.formatted(.relative(presentation: .named)))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("Updates are signed and verified before installing.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }
}
