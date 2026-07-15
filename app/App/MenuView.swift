import SwiftUI
import LidBootCore

/// The menu bar popover.
struct MenuView: View {
    @ObservedObject var model: LidBootModel
    @ObservedObject var updater: UpdaterModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 14)

            if let unsupported = model.unsupported {
                UnsupportedView(reason: unsupported, compact: true)
                    .padding(.horizontal, 8)
            } else {
                controls
            }

            Divider().padding(.horizontal, 14)
            footer
        }
        // 340, not 320: pt-PT strings run ~25% longer than the English and
        // wrap awkwardly at the narrower width. Still inside the 300-340 range
        // that comparable menu bar apps use.
        .frame(width: 340)
        // The popover is rebuilt each time it opens, so this keeps it honest
        // even if NVRAM changed underneath us.
        .onAppear { model.refresh() }
    }

    @ViewBuilder
    private var controls: some View {
        BootToggles(model: model)
            .padding(.vertical, 8)
            .padding(.horizontal, 8)

        if let errorMessage = model.errorMessage {
            NoticeRow(symbol: "exclamationmark.triangle.fill", text: errorMessage,
                      tint: .orange, prominent: true)
                .padding(.horizontal, 14)
                .padding(.bottom, 9)
        }

        Divider().padding(.horizontal, 14)

        VStack(alignment: .leading, spacing: 6) {
            if model.isModified {
                StartupCaveats()
            }
            PasswordNotice()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text("LidBoot")
                        .font(.headline)
                    if model.unsupported == nil {
                        HowItWorksButton()
                    }
                }
                Text(model.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if model.isApplying {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 11)
    }

    /// Left: the one thing you might want next. Right: a gear holding everything
    /// else, so the popover isn't a row of competing text buttons.
    ///
    /// Quit and Settings live in the gear rather than being dropped: in
    /// menu-bar-only mode the app is an accessory with no app menu, so this
    /// popover is the *only* reachable UI. A gear menu keeps them one click away
    /// without spending the popover's limited surface on them.
    private var footer: some View {
        HStack(spacing: 4) {
            FooterButton(title: String(localized: "Open LidBoot…")) {
                WindowOpener.shared.open()
            }
            .accessibilityHint(String(localized: "Opens the LidBoot window"))

            Spacer()

            Menu {
                // SettingsLink rather than a Button: it's the only thing that
                // reliably opens the Settings scene from an accessory app.
                SettingsLink { Label("Settings…", systemImage: "gearshape") }
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("Check for Updates…", systemImage: "arrow.down.circle")
                }
                .disabled(!updater.canCheck)
                Divider()
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit LidBoot", systemImage: "power")
                }
                .keyboardShortcut("q")
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help(String(localized: "More options"))
            .accessibilityLabel(String(localized: "More options"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

/// The rows above get a hover highlight, which teaches "highlight = clickable".
/// Plain text buttons would then break that lesson on the only two controls that
/// actually navigate.
private struct FooterButton: View {
    let title: String
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isHovering ? .primary : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
