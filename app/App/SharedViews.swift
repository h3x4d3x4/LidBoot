import SwiftUI
import LidBootCore

/// The two toggles. Shared verbatim between the menu bar popover and the window
/// so the two surfaces can never drift apart.
struct BootToggles: View {
    @ObservedObject var model: LidBootModel

    var body: some View {
        VStack(spacing: 2) {
            SettingRow(
                symbol: "laptopcomputer",
                tint: [Color(red: 0.36, green: 0.55, blue: 1.0), Color(red: 0.55, green: 0.40, blue: 1.0)],
                title: "Opening the lid",
                caption: model.behavior.startsOnLidOpen ? "Starts up your Mac" : "Won't start up your Mac",
                isOn: model.lidOpen,
                enabled: model.controlsEnabled
            )
            SettingRow(
                symbol: "bolt.fill",
                tint: [Color(red: 1.0, green: 0.68, blue: 0.25), Color(red: 1.0, green: 0.42, blue: 0.38)],
                title: "Connecting power",
                caption: model.behavior.startsOnPowerConnect ? "Starts up your Mac" : "Won't start up your Mac",
                isOn: model.powerConnect,
                enabled: model.controlsEnabled
            )
        }
    }
}

struct SettingRow: View {
    let symbol: String
    let tint: [Color]
    let title: String
    let caption: String
    @Binding var isOn: Bool
    let enabled: Bool

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(LinearGradient(colors: enabled ? tint : [.gray.opacity(0.5), .gray.opacity(0.35)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 26, height: 26)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: (enabled ? tint[0] : .clear).opacity(0.30), radius: 3, y: 1)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(caption)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(!enabled)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

struct NoticeRow: View {
    let symbol: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundStyle(tint)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// The limitation users would otherwise discover the hard way.
struct KeyboardCaveat: View {
    var body: some View {
        NoticeRow(
            symbol: "info.circle",
            text: "Your Mac still starts up if you press a key or touch the trackpad.",
            tint: .secondary
        )
    }
}

struct ModePicker: View {
    @Binding var mode: AppMode

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Show LidBoot in")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Picker("", selection: $mode) {
                ForEach(AppMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
