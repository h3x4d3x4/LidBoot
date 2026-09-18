import SwiftUI
import LidBootCore

/// Shown instead of the controls when this Mac can't use the setting at all.
///
/// The alternative — greying out the toggles — reads as "temporarily
/// unavailable" and leaves two big gradient switches looking live, next to a
/// mode picker and a launch-at-login toggle offering to configure an app that
/// can never do anything. Better to say so plainly and stop pretending.
struct UnsupportedView: View {
    let reason: SystemSupport.Unsupported
    var compact = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "laptopcomputer.slash")
                .font((compact ? Font.title : Font.largeTitle).weight(.light))
                .foregroundStyle(.secondary)

            Text("LidBoot can't help this Mac")
                .font(compact ? Font.headline : Font.title3.weight(.semibold))

            Text(reason.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if reason == .notAppleSilicon {
                IntelCommands()
            }

            Link("Apple's documentation", destination: AppLinks.appleSupport)
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 14 : 22)
        .padding(.horizontal, 8)
    }
}

/// The dead-end screen becomes an answer: the Intel-era commands, copyable.
///
/// The app never runs these — `NVRAMCommand` stays a closed enum over
/// `BootPreference`, and the test that enforces it is untouched. This is text.
/// The commands themselves are verbatim, never localized.
private struct IntelCommands: View {
    @State private var didCopy = false

    // `%03` restores, not `-d`: that's the only documented Intel restore, and
    // nobody has established delete-as-restore there. Don't "fix" it to match
    // the Apple-silicon philosophy.
    private static let disable = "sudo nvram AutoBoot=%00"
    private static let restore = "sudo nvram AutoBoot=%03"

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            commandRow(Self.disable, label: String(localized: "Don't start up from the lid or from power"))
            commandRow(Self.restore, label: String(localized: "Restore"))

            Text("Intel has one switch, not two. A key press still starts the Mac. To undo everything, reset NVRAM: hold Option-Command-P-R at start-up.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        }
        .padding(.horizontal, 6)
        .animation(.easeInOut(duration: 0.15), value: didCopy)
    }

    private func commandRow(_ command: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Text(verbatim: command)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                Spacer(minLength: 0)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(command, forType: .string)
                    didCopy = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        didCopy = false
                    }
                } label: {
                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(String(localized: "Copy"))
                .accessibilityLabel(String(localized: "Copy \(command)"))
            }
        }
    }
}

enum AppLinks {
    /// Apple's own page for the underlying setting.
    static let appleSupport = URL(string: "https://support.apple.com/120622")!
    static let site = URL(string: "https://hexadexa.io")!
    static let productSite = URL(string: "https://lidboot.hexadexa.io")!
    static let source = URL(string: "https://github.com/h3x4d3x4/LidBoot")!
    /// hexadexa.dev handles mail; hexadexa.io has no MX by design.
    static let email = URL(string: "mailto:andrei@hexadexa.dev?subject=LidBoot")!
    // "Buy me a coffee" is the label; the page is Ko-fi. buymeacoffee.com is a
    // different service where no hexadexa account exists — that URL was a 404.
    static let buyMeACoffee = URL(string: "https://ko-fi.com/hexadexa")!
}
