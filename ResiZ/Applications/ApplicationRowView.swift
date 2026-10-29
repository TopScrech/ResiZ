import SwiftUI
import AppKit

struct ApplicationRowView: View {
    @Environment(AppModel.self) private var appModel
    let application: InstalledApplication
    @State private var isEnabled = false

    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            Toggle(isOn: $isEnabled) {
                VStack(alignment: .leading) {
                    Text(application.name)
                        .lineLimit(1)

                    Text(appModel.detail(for: application.id))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: isEnabled) {
                if isEnabled != appModel.isEnabled(application.id) {
                    appModel.setEnabled(isEnabled, for: application.id)
                }
            }
        }
        .padding(.vertical)
        .onChange(of: appModel.isEnabled(application.id), initial: true) {
            isEnabled = appModel.isEnabled(application.id)
        }
        .contextMenu {
            Button("Use automatic detection", systemImage: "wand.and.stars") {
                appModel.clearOverride(for: application.id)
            }
            .disabled(!appModel.hasOverride(application.id))
        }
    }
}
