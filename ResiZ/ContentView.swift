import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        @Bindable var appModel = appModel

        VStack(alignment: .leading) {
            HStack {
                Label("ResiZ", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.headline)

                Spacer()

                Text("⌃⌘F")
                    .font(.title3.monospaced())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Control Command F")
            }

            Text("Fullscreen for your apps")
                .font(.title2)
                .bold()

            Text("Press Control–Command–F to toggle fullscreen in enabled apps")
                .foregroundStyle(.secondary)

            AccessibilityStatusView()

            Toggle("Automatically detect missing shortcuts", isOn: $appModel.automaticallyDetects)
                .onChange(of: appModel.automaticallyDetects) {
                    appModel.saveAutomaticDetection()
                }

            Divider()

            TextField("Search applications", text: $appModel.searchText)
                .textFieldStyle(.roundedBorder)

            Toggle("Show enabled apps only", isOn: $appModel.showsEnabledOnly)
                .toggleStyle(.checkbox)

            ApplicationListView()

            Text("Detection checks running apps when you switch to them\nApps must expose fullscreen through Accessibility")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            HStack {
                Text("\(appModel.enabledAppCount) enabled")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Refresh apps", systemImage: "arrow.clockwise") {
                    Task { await appModel.refreshApplications() }
                }
                .labelStyle(.iconOnly)
                .help("Refresh applications from /Applications")
                .disabled(appModel.isLoading)

                Button("Quit ResiZ", systemImage: "power", action: appModel.quit)
            }
        }
        .padding()
        .frame(width: 420)
        .task { await appModel.refreshApplications() }
    }
}
