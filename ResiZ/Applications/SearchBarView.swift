import SwiftUI
import UniformTypeIdentifiers

struct SearchBarView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isImporting = false

    var body: some View {
        @Bindable var appModel = appModel

        HStack {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search apps", text: $appModel.searchText)
                    .textFieldStyle(.plain)

                if !appModel.searchText.isEmpty {
                    Button("Clear search", systemImage: "xmark.circle.fill") {
                        appModel.searchText = ""
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 8))

            Toggle("Enabled only", systemImage: "line.3.horizontal.decrease", isOn: $appModel.showsEnabledOnly)
                .toggleStyle(.button)
                .labelStyle(.iconOnly)
                .help("Show enabled apps only")

            Button("Add App", systemImage: "plus") {
                isImporting = true
            }
            .labelStyle(.iconOnly)
            .help("Add an app from another location")
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.application], allowsMultipleSelection: true) {
            guard case .success(let urls) = $0 else { return }
            Task { await appModel.addApplications(urls) }
        }
    }
}
