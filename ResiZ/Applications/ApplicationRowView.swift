import SwiftUI
import AppKit

struct ApplicationRowView: View {
    @Environment(AppModel.self) private var appModel
    let application: InstalledApplication
    @State private var isEnabled = false
    @State private var isHovered = false

    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(application.name)
                    .lineLimit(1)

                Text(appModel.detail(for: application.id))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help(appModel.detail(for: application.id))
            }

            Spacer()

            Toggle(application.name, isOn: $isEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .onChange(of: isEnabled) {
                    if isEnabled != appModel.isEnabled(application.id) {
                        appModel.setEnabled(isEnabled, for: application.id)
                    }
                }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(isHovered ? AnyShapeStyle(.quaternary.opacity(0.5)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
        .onHover { isHovered = $0 }
        .onChange(of: appModel.isEnabled(application.id), initial: true) {
            isEnabled = appModel.isEnabled(application.id)
        }
        .contextMenu {
            Button("Show in Finder", systemImage: "folder") {
                NSWorkspace.shared.activateFileViewerSelecting([application.url])
            }

            if application.isCustom {
                Button("Remove from List", systemImage: "minus.circle", role: .destructive) {
                    Task { await appModel.removeCustomApplication(application) }
                }
            }
        }
    }
}
