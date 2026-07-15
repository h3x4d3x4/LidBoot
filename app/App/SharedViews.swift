import SwiftUI
import LidBootCore

/// The two toggles. Shared verbatim between the menu bar popover and the window
/// so the two surfaces can never drift apart.
struct BootToggles: View {
    @ObservedObject var model: LidBootModel

    var body: some View {
        VStack(spacing: 2) {
            // These are Strings handed to Text(_: String), which does no lookup,
            // so they must be localized here rather than at the Text call.
            SettingRow(
                symbol: "laptopcomputer",
                tint: Palette.lid,
                title: String(localized: "Opening the lid"),
                // Say what happens, not just what the switch is set to. Never
                // "wake" — this is about starting up from a full shutdown.
                caption: caption(
                    on: String(localized: "Opening the lid starts your Mac"),
                    off: String(localized: "Opening the lid won't start your Mac"),
                    value: model.displayed?.startsOnLidOpen
                ),
                accessibilityLabel: String(localized: "Start up when opening the lid"),
                isOn: model.lidOpen,
                isKnown: model.displayed != nil,
                enabled: model.controlsEnabled
            )
            SettingRow(
                symbol: "bolt.fill",
                tint: Palette.power,
                title: String(localized: "Connecting power"),
                caption: caption(
                    on: String(localized: "Plugging in starts your Mac"),
                    off: String(localized: "Plugging in just charges it"),
                    value: model.displayed?.startsOnPowerConnect
                ),
                accessibilityLabel: String(localized: "Start up when connecting power"),
                isOn: model.powerConnect,
                isKnown: model.displayed != nil,
                enabled: model.controlsEnabled
            )
        }
    }

    /// Never claims a behaviour we haven't read off the machine.
    private func caption(on: String, off: String, value: Bool?) -> String {
        guard let value else { return String(localized: "Unknown") }
        return value ? on : off
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
    /// False when we couldn't read the machine. A switch always looks like it's
    /// asserting something, so when we don't know we show a dash instead.
    var isKnown = true
    let enabled: Bool

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            IconTile(symbol: symbol, tint: tint, enabled: enabled)

            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.headline)
                Text(caption)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    // Captions swap as the switch flips; fade rather than snap.
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.18), value: caption)
            }

            Spacer(minLength: 8)

            if isKnown {
                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .disabled(!enabled)
            } else {
                Text(verbatim: "—")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(isHovering && enabled ? 0.06 : 0))
        }
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovering)
        // One element for VoiceOver: without this the switch announces as an
        // unlabelled toggle and the title/caption are read separately.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isToggle)
    }

    private var accessibilityValue: String {
        guard isKnown else { return String(localized: "Unknown") }
        return isOn ? String(localized: "On. \(caption)") : String(localized: "Off. \(caption)")
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
                    // The one deliberate hard-coded size in the app: this is a
                    // decorative glyph scaled to the tile it sits in, not text.
                    // A semantic text style would resize with the user's
                    // preferences and overflow the fixed-size tile.
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
    /// Errors must not be styled as the least important text on screen.
    var prominent = false

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(tint)
                .padding(.top, 1)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(prominent ? .primary : .secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}

/// The one thing people would otherwise discover the hard way.
///
/// Only worth saying once something is actually suppressed — at factory default
/// "your Mac still starts up if you press a key" is a non-sequitur, because
/// everything starts it up.
///
/// The other caveat (this only applies from a full shutdown; sleep is
/// unaffected) moved into the "How this works" popover. It matters, but it's
/// background rather than a warning, and two permanent grey rows under the
/// switches read as fine print nobody finishes.
struct StartupCaveats: View {
    var body: some View {
        NoticeRow(
            symbol: "keyboard",
            text: String(localized: "Your Mac still starts up if you press a key or touch the trackpad."),
            tint: .secondary
        )
    }
}

/// Tells people the price of flipping a switch before they flip it.
struct PasswordNotice: View {
    var body: some View {
        NoticeRow(
            symbol: "lock",
            text: String(localized: "Changing either switch asks for your Mac password."),
            tint: .secondary
        )
    }
}
