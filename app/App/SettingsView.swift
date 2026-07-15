import SwiftUI

/// The Settings scene (Cmd-,).
///
/// The main window is for the two switches — the thing you opened the app to do.
/// Everything you set once and forget (where the app lives, login, updates) moved
/// here, which is where macOS users look for it anyway.
struct SettingsView: View {
    @ObservedObject var model: LidBootModel
    @Binding var mode: AppMode
    @ObservedObject var updater: UpdaterModel
    @StateObject private var launchAtLogin = LaunchAtLoginModel()

    var body: some View {
        TabView {
            GeneralSettingsView(mode: $mode, launchAtLogin: launchAtLogin)
                .tabItem { Label("General", systemImage: "gearshape") }

            UpdatesSettingsView(model: updater)
                .tabItem { Label("Updates", systemImage: "arrow.down.circle") }

            AboutView(model: model, mode: $mode)
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 500)
        .frame(minHeight: 320)
    }
}

struct GeneralSettingsView: View {
    @Binding var mode: AppMode
    @ObservedObject var launchAtLogin: LaunchAtLoginModel
    @AppStorage(AppAppearance.defaultsKey) private var appearance: AppAppearance = .system

    var body: some View {
        Form {
            Section {
                AppearancePicker(appearance: $appearance)
            }
            Section {
                ModePicker(mode: $mode)
            }
            Section {
                LaunchAtLoginToggle(model: launchAtLogin)
            }
        }
        .formStyle(.grouped)
    }
}

struct AboutView: View {
    @ObservedObject var model: LidBootModel
    @Binding var mode: AppMode

    private let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1"
    private let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 24)

            // The real icon, not a tile imitating it — an About box showing a
            // hand-drawn stand-in for the app's own icon is the one place that
            // can't be allowed to drift. Sized to 104 so the squircle lands at
            // ~84pt after the asset's baked padding; its shadow is in the pixels.
            AppIconImage(size: 104)
                // The one decorative flourish in the app: a soft colour wash
                // behind the hero tile only. Gradients stay jewelry — confined
                // to small shapes — rather than becoming wallpaper, which is
                // what makes this look premium instead of template-y.
                .background {
                    ZStack {
                        Circle()
                            .fill(Palette.lid[0].opacity(0.30))
                            .frame(width: 120, height: 120)
                            .offset(x: -26, y: -14)
                        Circle()
                            .fill(Palette.power[0].opacity(0.16))
                            .frame(width: 96, height: 96)
                            .offset(x: 30, y: 20)
                        Circle()
                            .fill(Palette.lid[1].opacity(0.24))
                            .frame(width: 108, height: 108)
                            .offset(x: 18, y: -24)
                    }
                    // Blur scaled well past the blob size melts them into one
                    // wash rather than three readable circles.
                    .blur(radius: 34)
                    .accessibilityHidden(true)
                }

            Spacer().frame(height: 14)

            Text("LidBoot")
                .font(.title.bold())
            Text("Start-up control for MacBooks")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer().frame(height: 10)

            Text("Version \(version) (\(build))")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)

            Spacer().frame(height: 18)
            Divider().padding(.horizontal, 40)
            Spacer().frame(height: 14)

            VStack(spacing: 6) {
                Text("Designed and built by Hexadexa")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Link("hexadexa.io", destination: AppLinks.site)
                        .font(.subheadline)
                    dot
                    // .dev handles mail — hexadexa.io has no MX by design.
                    Link("andrei@hexadexa.dev", destination: AppLinks.email)
                        .font(.subheadline)
                    dot
                    Link("Ko-fi", destination: AppLinks.koFi)
                        .font(.subheadline)
                }
            }

            Spacer().frame(height: 12)

            Text("Copyright \u{00A9} 2026 Hexadexa. All rights reserved.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 18)

            ReportProblemView(model: model, mode: $mode)
                .padding(.horizontal, 40)

            Spacer().frame(height: 16)

            DisclosureGroup {
                VStack(alignment: .leading, spacing: 4) {
                    acknowledgement("Sparkle", "MIT")
                }
                .padding(.top, 6)
            } label: {
                Text("Acknowledgements")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }

    private var dot: some View {
        Text(verbatim: "·")
            .font(.subheadline)
            .foregroundStyle(.quaternary)
    }

    private func acknowledgement(_ name: String, _ license: String) -> some View {
        HStack {
            Text(name).font(.subheadline.weight(.medium))
            Spacer()
            Text(license).font(.caption).foregroundStyle(.tertiary)
        }
    }
}
