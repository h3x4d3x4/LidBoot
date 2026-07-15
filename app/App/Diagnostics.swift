import SwiftUI
import LidBootCore

/// A paste-ready summary of everything you'd otherwise have to ask a tester for.
///
/// The app logs plenty (subsystem `com.lidboot.LidBoot`), but no user is going to
/// open Console.app, so all of it is effectively unreachable in a bug report.
/// This turns "it didn't work" into something actionable.
///
/// Deliberately English and unlocalized: it's for the developer's inbox, not the
/// user's screen. Nothing here is personal — model, OS, and one NVRAM byte.
@MainActor
enum Diagnostics {
    static func report(model: LidBootModel, mode: AppMode) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let os = ProcessInfo.processInfo.operatingSystemVersionString

        var lines = [
            "Lid Boot \(version) (\(build))",
            "macOS: \(os)",
            "Model: \(HardwareInfo.modelIdentifier)",
            "Apple silicon: \(HardwareInfo.isAppleSilicon ? "yes" : "no")",
            "Has lid: \(HardwareInfo.hasLid ? "yes" : "no")",
            "BootPreference: \(BootPreferenceService().read().diagnosticDescription)",
            "Show in: \(mode.rawValue)"
        ]

        if let unsupported = model.unsupported {
            lines.append("Unsupported: \(unsupported)")
        }
        if let error = model.errorMessage {
            lines.append("Last error: \(error)")
        }
        return lines.joined(separator: "\n")
    }
}

/// Pairs the diagnostics with somewhere to send them — a Copy button with no
/// destination just moves the problem.
struct ReportProblemView: View {
    @ObservedObject var model: LidBootModel
    @Binding var mode: AppMode
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(Diagnostics.report(model: model, mode: mode),
                                                   forType: .string)
                    didCopy = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        didCopy = false
                    }
                } label: {
                    Label(didCopy ? "Copied" : "Copy Diagnostics",
                          systemImage: didCopy ? "checkmark" : "doc.on.doc")
                }
                .controlSize(.small)

                Link(destination: AppLinks.email) {
                    Label("Email a Problem", systemImage: "envelope")
                }
                .controlSize(.small)
            }
            Text("Diagnostics include your Mac model, macOS version and the current setting. Nothing personal.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .animation(.easeInOut(duration: 0.15), value: didCopy)
    }
}
