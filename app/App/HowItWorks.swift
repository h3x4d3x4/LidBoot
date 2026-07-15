import SwiftUI

/// The "?" that keeps the mechanism out of the main UI.
///
/// Hardware utilities get called "technical for beginners" when they put things
/// like `BootPreference` on the front page — but power users and IT admins want
/// exactly that detail. A popover satisfies both: the surface stays plain
/// English, the mechanism is one click away for whoever wants it.
///
/// This also earns back vertical space: the shutdown-vs-sleep caveat lives here
/// now, so the permanent notice under the switches is one line instead of two.
struct HowItWorksButton: View {
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(String(localized: "How this works"))
        .accessibilityLabel(String(localized: "How this works"))
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            HowItWorksPopover()
        }
    }
}

private struct HowItWorksPopover: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How this works")
                .font(.headline)

            VStack(alignment: .leading, spacing: 9) {
                point("gearshape.2",
                      String(localized: "LidBoot changes BootPreference, a start-up setting in your Mac's firmware that Apple documents."))
                point("arrow.counterclockwise",
                      String(localized: "It survives restarts and updates. Restore Default removes it completely, leaving your Mac exactly as it shipped."))
                point("powersleep",
                      String(localized: "It only applies from a full shutdown. Waking your Mac from sleep is never affected."))
            }

            Divider()

            Link(destination: AppLinks.appleSupport) {
                HStack(spacing: 3) {
                    Text("Apple's documentation")
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption2)
                }
            }
            .font(.subheadline)
        }
        .padding(14)
        .frame(width: 300)
    }

    private func point(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)
                .padding(.top, 2)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
