import SwiftUI
import LidBootCore

/// The regular app window, for people who'd rather not live in the menu bar.
/// Shows exactly the same controls as the popover, plus the less-used actions.
struct MainWindowView: View {
    @ObservedObject var model: LidBootModel
    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            if let unsupported = model.unsupported {
                // Nothing below this is actionable on such a Mac, so don't show it.
                UnsupportedView(reason: unsupported)
            } else {
                controls
            }

            Divider()
            footer
        }
        // Extra headroom so the title bar's traffic lights don't sit on the header.
        .padding(.top, 30)
        .padding([.horizontal, .bottom], 20)
        .frame(width: 380)
        .background(.background)
        .animation(.easeInOut(duration: 0.2), value: model.errorMessage)
        .onAppear { model.refresh() }
    }

    @ViewBuilder
    private var controls: some View {
        BootToggles(model: model)
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            }

        if let errorMessage = model.errorMessage {
            NoticeRow(symbol: "exclamationmark.triangle.fill", text: errorMessage,
                      tint: .orange, prominent: true)
                .transition(.opacity)
        }

        VStack(alignment: .leading, spacing: 6) {
            // Only meaningful once something is actually suppressed.
            if model.isModified {
                StartupCaveats()
            }
            PasswordNotice()
        }

        Divider()
        actions
    }

    private var header: some View {
        HStack(spacing: 12) {
            IconTile(symbol: "laptopcomputer", tint: Palette.lid, size: 42, corner: 11, glyph: 19)
                .overlay {
                    // Soft glow ring — the one flourish that lifts the header
                    // out of "system settings pane" territory.
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Palette.lid[0].opacity(0.35), lineWidth: 3)
                        .blur(radius: 4)
                }
                .shadow(color: Palette.lid[0].opacity(0.35), radius: 8, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text("Lid Boot")
                    .font(.system(size: 17, weight: .semibold))
                // On an unsupported Mac the panel below carries the explanation;
                // repeating it here just says the same sentence twice.
                if model.unsupported == nil {
                    Text(model.summary)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: model.summary)
                }
            }

            Spacer(minLength: 0)

            if model.isApplying {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Restore Default") {
                Task { await model.restoreDefault() }
            }
            .controlSize(.small)
            .disabled(!model.canRestoreDefault)
            .help("Removes the setting, returning your Mac to how it shipped")

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(model.terminalCommand, forType: .string)
                didCopy = true
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    didCopy = false
                }
            } label: {
                Label(didCopy ? "Copied" : "Copy Terminal Command",
                      systemImage: didCopy ? "checkmark" : "terminal")
            }
            .controlSize(.small)
            // Mid-write the command would describe the state you're leaving.
            .disabled(model.unsupported != nil || model.isApplying)
            .help(model.terminalCommand)

            Spacer()
        }
        .animation(.easeInOut(duration: 0.15), value: didCopy)
    }

    private var footer: some View {
        HStack {
            Text("Version \(Bundle.appVersion)", comment: "Footer version label")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer()
            // The unsupported panel already offers this link; two of them on one
            // small window is noise.
            if model.unsupported == nil {
                Link(destination: AppLinks.appleSupport) {
                    HStack(spacing: 3) {
                        Text("Apple's documentation")
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 9))
                    }
                }
                .font(.system(size: 10.5))
                .help(AppLinks.appleSupport.absoluteString)
            }
        }
    }
}

extension Bundle {
    static var appVersion: String {
        main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
