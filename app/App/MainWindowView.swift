import SwiftUI
import LidBootCore

/// The regular app window, for people who'd rather not live in the menu bar.
/// Shows exactly the same controls as the popover.
struct MainWindowView: View {
    @ObservedObject var model: LidBootModel
    @Binding var mode: AppMode
    @StateObject private var launchAtLogin = LaunchAtLoginModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            BootToggles(model: model)
                .padding(6)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                }

            if let errorMessage = model.errorMessage {
                NoticeRow(symbol: "exclamationmark.triangle.fill", text: errorMessage, tint: .orange)
                    .transition(.opacity)
            }

            KeyboardCaveat()

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                ModePicker(mode: $mode)
                LaunchAtLoginToggle(model: launchAtLogin)
            }

            Divider()
            actions
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
                Text("LidBoot")
                    .font(.system(size: 17, weight: .semibold))
                Text(model.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: model.summary)
            }

            Spacer(minLength: 0)

            if model.isApplying {
                ProgressView().controlSize(.small)
            } else if model.unsupported == nil && model.refusal == nil {
                StatusDot(isModified: model.isModified)
            }
        }
    }

    @State private var didCopy = false

    private var actions: some View {
        HStack(spacing: 8) {
            Button("Restore Default") {
                Task { await model.restoreDefault() }
            }
            .controlSize(.small)
            // Nothing to restore when the variable is already absent.
            .disabled(!model.isModified || !model.controlsEnabled)
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
                Label(didCopy ? "Copied" : "Copy Command",
                      systemImage: didCopy ? "checkmark" : "terminal")
            }
            .controlSize(.small)
            .disabled(model.unsupported != nil)
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
            Link("How this works", destination: URL(string: "https://support.apple.com/120622")!)
                .font(.system(size: 10.5))
        }
    }
}

extension Bundle {
    static var appVersion: String {
        main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
