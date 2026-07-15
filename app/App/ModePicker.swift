import SwiftUI

/// Picks where LidBoot lives, and guards the one choice that can hide the app.
///
/// Menu-bar-only is genuinely risky: if the menu bar is full — which is common
/// on notched MacBooks, where macOS silently drops overflow items instead of
/// wrapping — the status item never appears. With no Dock icon and no window on
/// launch, the app would be running and unreachable. So we confirm first, and
/// make sure the escape hatch is stated up front rather than discovered.
struct ModePicker: View {
    @Binding var mode: AppMode
    @State private var pendingMenuBarOnly = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Show Lid Boot in")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Picker("Show Lid Boot in", selection: pickerBinding) {
                ForEach(AppMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .accessibilityLabel("Show Lid Boot in")
        }
        .alert("Hide the Dock icon?", isPresented: $pendingMenuBarOnly) {
            Button("Cancel", role: .cancel) {}
            Button("Use Menu Bar Only") {
                mode = .menuBar
                mode.applyActivationPolicy()
            }
        } message: {
            Text("""
                Lid Boot will only be reachable from its menu bar icon. If your menu bar is full, macOS may not have room to show it — this is common on Macs with a notch.

                If you can't find the icon, open Lid Boot again from Finder or Launchpad and this window will come back.
                """)
        }
    }

    /// Intercepts only the risky transition; the other two apply immediately.
    private var pickerBinding: Binding<AppMode> {
        Binding(
            get: { mode },
            set: { newMode in
                guard newMode != mode else { return }
                if newMode == .menuBar {
                    pendingMenuBarOnly = true
                } else {
                    mode = newMode
                    newMode.applyActivationPolicy()
                }
            }
        )
    }
}
