import SwiftUI

struct AccessibilityStatusView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        if !appModel.hasAccessibilityPermission || !appModel.isShortcutActive {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 6) {
                    Text(appModel.statusTitle)
                        .font(.callout)
                        .bold()

                    if !appModel.hasAccessibilityPermission {
                        Text("Allow ResiZ in Privacy & Security → Accessibility so it can control other apps’ windows")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Open Settings", action: appModel.openAccessibilitySettings)
                            .controlSize(.small)
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button("Retry", systemImage: "arrow.clockwise", action: appModel.refreshPermission)
                            .controlSize(.small)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.orange.opacity(0.12), in: .rect(cornerRadius: 10))
            .padding(.horizontal)
            .padding(.bottom, 10)
        } else if let message = appModel.lastMessage {
            Label(message, systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }
}
