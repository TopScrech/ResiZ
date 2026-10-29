import SwiftUI

struct FooterView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        HStack {
            if appModel.isDetecting {
                ProgressView()
                    .controlSize(.mini)

                Text("Checking running apps…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("\(appModel.enabledAppCount) of \(appModel.applications.count) apps enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu("Settings", systemImage: "gearshape") {
                Button("Detect Missing Shortcuts", systemImage: "wand.and.stars") {
                    Task { await appModel.detectMissingShortcuts() }
                }
                .disabled(appModel.isDetecting || !appModel.hasAccessibilityPermission)

                Text("Enables running apps without ⌃⌘F")

                Divider()

                Button("Refresh Apps", systemImage: "arrow.clockwise") {
                    Task { await appModel.refreshApplications() }
                }
                .disabled(appModel.isLoading)

                Divider()

                Button("Quit ResiZ", systemImage: "power", action: appModel.quit)
                    .keyboardShortcut("q")
            }
            .labelStyle(.iconOnly)
            .menuStyle(.button)
            .buttonStyle(.borderless)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
