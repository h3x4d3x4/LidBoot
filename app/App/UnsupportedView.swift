import SwiftUI
import LidBootCore

/// Shown instead of the controls when this Mac can't use the setting at all.
///
/// The alternative — greying out the toggles — reads as "temporarily
/// unavailable" and leaves two big gradient switches looking live, next to a
/// mode picker and a launch-at-login toggle offering to configure an app that
/// can never do anything. Better to say so plainly and stop pretending.
struct UnsupportedView: View {
    let reason: SystemSupport.Unsupported
    var compact = false

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "laptopcomputer.slash")
                .font(.system(size: compact ? 22 : 28, weight: .light))
                .foregroundStyle(.secondary)

            Text("LidBoot can't help this Mac")
                .font(.system(size: compact ? 12.5 : 14, weight: .semibold))

            Text(reason.explanation)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Link("Apple's documentation", destination: AppLinks.appleSupport)
                .font(.system(size: 11))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 14 : 22)
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }
}

enum AppLinks {
    /// Apple's own page for the underlying setting.
    static let appleSupport = URL(string: "https://support.apple.com/120622")!
    static let site = URL(string: "https://hexadexa.io")!
    /// hexadexa.dev handles mail; hexadexa.io has no MX by design.
    static let email = URL(string: "mailto:andrei@hexadexa.dev?subject=LidBoot")!
    static let koFi = URL(string: "https://ko-fi.com/hexadexa")!
}
