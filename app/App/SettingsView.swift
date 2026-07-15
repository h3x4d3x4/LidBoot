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
        .frame(width: 420)
        .frame(minHeight: 300)
    }
}

struct GeneralSettingsView: View {
    @Binding var mode: AppMode
    @ObservedObject var launchAtLogin: LaunchAtLoginModel

    var body: some View {
        Form {
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

            IconTile(symbol: "laptopcomputer", tint: Palette.lid, size: 84, corner: 19, glyph: 38)
                .shadow(color: Palette.lid[0].opacity(0.3), radius: 12, y: 4)

            Spacer().frame(height: 14)

            Text("Lid Boot")
                .font(.system(size: 22, weight: .bold))
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
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    Link("hexadexa.io", destination: AppLinks.site)
                        .font(.system(size: 11))
                    dot
                    // .dev handles mail — hexadexa.io has no MX by design.
                    Link("andrei@hexadexa.dev", destination: AppLinks.email)
                        .font(.system(size: 11))
                    dot
                    Link("Ko-fi", destination: AppLinks.koFi)
                        .font(.system(size: 11))
                }
            }

            Spacer().frame(height: 12)

            Text("Copyright \u{00A9} 2026 Hexadexa. All rights reserved.")
                .font(.system(size: 10))
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
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 40)

            Spacer(minLength: 20)
        }
        .frame(maxWidth: .infinity)
    }

    private var dot: some View {
        Text(verbatim: "·")
            .font(.system(size: 11))
            .foregroundStyle(.quaternary)
    }

    private func acknowledgement(_ name: String, _ license: String) -> some View {
        HStack {
            Text(name).font(.system(size: 11, weight: .medium))
            Spacer()
            Text(license).font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }
}
