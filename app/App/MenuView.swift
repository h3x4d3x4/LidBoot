import SwiftUI
import LidBootCore

/// The menu bar popover.
struct MenuView: View {
    @ObservedObject var model: LidBootModel
    @Binding var mode: AppMode

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
        // The popover is rebuilt each time it opens, so this keeps it honest
        // even if NVRAM changed underneath us.
        .onAppear { model.refresh() }
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
            } else if model.unsupported == nil && model.refusal == nil {
                StatusDot(isModified: model.isModified)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 11)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button {
                WindowOpener.shared.open()
            } label: {
                Text("Settings…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the LidBoot window")

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
