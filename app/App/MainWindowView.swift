import SwiftUI
import LidBootCore

/// The regular app window, for people who'd rather not live in the menu bar.
/// Shows exactly the same controls as the popover.
struct MainWindowView: View {
    @ObservedObject var model: LidBootModel
    @Binding var mode: AppMode

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            card {
                BootToggles(model: model)
            }

            if let errorMessage = model.errorMessage {
                NoticeRow(symbol: "exclamationmark.triangle.fill", text: errorMessage, tint: .orange)
            }

            KeyboardCaveat()

            Divider()

            ModePicker(mode: $mode)
        }
        // Extra headroom so the title bar's traffic lights don't sit on the header.
        .padding(.top, 30)
        .padding([.horizontal, .bottom], 20)
        .frame(width: 380)
        .background(.background)
        .onAppear { model.refresh() }
        .onChange(of: mode) { _, newValue in newValue.applyActivationPolicy() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.36, green: 0.55, blue: 1.0), Color(red: 0.55, green: 0.40, blue: 1.0)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "laptopcomputer")
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: Color(red: 0.36, green: 0.55, blue: 1.0).opacity(0.35), radius: 6, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                Text("LidBoot")
                    .font(.system(size: 17, weight: .semibold))
                Text(model.summary)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if model.isApplying {
                ProgressView().controlSize(.small)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            }
    }
}
