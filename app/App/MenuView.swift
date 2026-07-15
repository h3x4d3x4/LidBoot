import SwiftUI
import LidBootCore

/// The menu bar popover.
struct MenuView: View {
    @ObservedObject var model: LidBootModel

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
        .frame(width: 320)
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
                Text("LidBoot")
                    .font(.system(size: 14, weight: .semibold))
                Text(model.summary)
                    .font(.system(size: 11))
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

    private var footer: some View {
        HStack(spacing: 4) {
            // Not "Settings…" for this one: the window holds the primary
            // toggles, Restore Default and the help link, so calling it Settings
            // tells people there's nothing in there worth opening.
            FooterButton(title: String(localized: "Open LidBoot…")) {
                WindowOpener.shared.open()
            }
            .accessibilityHint(String(localized: "Opens the LidBoot window"))

            // In menu-bar-only mode the app is an accessory: no app menu, so no
            // Cmd-, and no other route to Settings at all. This is the only one.
            SettingsLink {
                Text("Settings…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.plain)

            Spacer()

            FooterButton(title: String(localized: "Quit")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 10)
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
                .font(.system(size: 11))
                .foregroundStyle(isHovering ? .primary : .secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
