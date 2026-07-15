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
                tint: Palette.lid,
                title: "Opening the lid",
                // Say what happens, not just what the switch is set to.
                caption: model.displayed.startsOnLidOpen
                    ? "Wakes straight to the login screen"
                    : "Stays off until you press a key",
                accessibilityLabel: "Start up when opening the lid",
                isOn: model.lidOpen,
                enabled: model.controlsEnabled
            )
            SettingRow(
                symbol: "bolt.fill",
                tint: Palette.power,
                title: "Connecting power",
                caption: model.displayed.startsOnPowerConnect
                    ? "Plugging in starts your Mac"
                    : "Plugging in just charges it",
                accessibilityLabel: "Start up when connecting power",
                isOn: model.powerConnect,
                enabled: model.controlsEnabled
            )
        }
    }
}

enum Palette {
    static let lid = [Color(red: 0.36, green: 0.55, blue: 1.0), Color(red: 0.55, green: 0.40, blue: 1.0)]
    static let power = [Color(red: 1.0, green: 0.68, blue: 0.25), Color(red: 1.0, green: 0.42, blue: 0.38)]
}

struct SettingRow: View {
    let symbol: String
    let tint: [Color]
    let title: String
    let caption: String
    let accessibilityLabel: String
    @Binding var isOn: Bool
    let enabled: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol, tint: tint, enabled: enabled)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(caption)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    // Captions swap as the switch flips; fade rather than snap.
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.18), value: caption)
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
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.primary.opacity(isHovering && enabled ? 0.06 : 0))
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        // One element for VoiceOver: without this the switch announces as an
        // unlabelled toggle and the title/caption are read separately.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isOn ? "On. \(caption)" : "Off. \(caption)")
        .accessibilityAddTraits(.isToggle)
        .accessibilityHint(enabled ? "Changing this asks for your password" : "")
    }
}

struct IconTile: View {
    let symbol: String
    let tint: [Color]
    var enabled = true
    var size: CGFloat = 26
    var corner: CGFloat = 7
    var glyph: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(LinearGradient(colors: enabled ? tint : [.gray.opacity(0.5), .gray.opacity(0.35)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: glyph, weight: .medium))
                    .foregroundStyle(.white)
            }
            .overlay {
                // Subtle top highlight — reads as glass rather than flat fill.
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.45), .white.opacity(0.05)],
                                       startPoint: .top, endPoint: .bottom),
                        lineWidth: 0.5
                    )
            }
            .shadow(color: (enabled ? tint[0] : .clear).opacity(0.30), radius: 3, y: 1)
            .accessibilityHidden(true)
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
                .accessibilityHidden(true)
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

/// Green when start-up is limited, grey when the Mac is at its default.
/// Deliberately not a warning colour: having protection on is the good state.
struct StatusDot: View {
    let isModified: Bool

    var body: some View {
        Circle()
            .fill(isModified ? Color.green : Color.secondary.opacity(0.35))
            .frame(width: 7, height: 7)
            .accessibilityElement()
            .accessibilityLabel(isModified ? "Start-up is limited" : "Default start-up behaviour")
            .help(isModified ? "Start-up is limited" : "Default behaviour")
    }
}
