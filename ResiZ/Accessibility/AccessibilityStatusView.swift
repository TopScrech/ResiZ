import SwiftUI

struct AccessibilityStatusView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading) {
                Label(appModel.statusTitle, systemImage: appModel.isShortcutActive ? "checkmark.shield" : "hand.raised")
                    .foregroundStyle(appModel.isShortcutActive ? .green : .orange)

                if !appModel.hasAccessibilityPermission {
                    Text("Allow ResiZ in System Settings → Privacy & Security → Accessibility to control other apps’ windows")
                        .font(.caption)

                    Button("Open Accessibility Settings", systemImage: "gear", action: appModel.openAccessibilitySettings)
                } else if !appModel.isShortcutActive {
                    Button("Retry shortcut listener", systemImage: "arrow.clockwise", action: appModel.refreshPermission)
                }

                if let message = appModel.lastMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
