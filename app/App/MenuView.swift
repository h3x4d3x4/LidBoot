import SwiftUI
import LidBootCore

/// The menu bar popover.
struct MenuView: View {
    @ObservedObject var model: LidBootModel
    @Binding var mode: AppMode
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 14)

            BootToggles(model: model)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)

            if let errorMessage = model.errorMessage {
                NoticeRow(symbol: "exclamationmark.triangle.fill", text: errorMessage, tint: .orange)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 9)
            }

            Divider().padding(.horizontal, 14)

            KeyboardCaveat()
                .padding(.horizontal, 14)
                .padding(.vertical, 9)

            Divider().padding(.horizontal, 14)
            footer
        }
        .frame(width: 320)
        .onAppear { model.refresh() }
        .onChange(of: mode) { _, newValue in newValue.applyActivationPolicy() }
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
            } else if model.unsupported == nil {
                Circle()
                    .fill(model.isModified ? Color.green : Color.secondary.opacity(0.35))
                    .frame(width: 7, height: 7)
                    .help(model.isModified ? "Auto start-up is limited" : "Default behaviour")
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 11)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Text("Open LidBoot…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
