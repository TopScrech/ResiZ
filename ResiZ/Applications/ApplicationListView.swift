import SwiftUI

struct ApplicationListView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                if appModel.isLoading {
                    ProgressView("Reading /Applications")
                        .padding()
                } else if let error = appModel.catalogError {
                    ContentUnavailableView("Couldn’t read applications", systemImage: "exclamationmark.folder", description: Text(error))
                } else if appModel.filteredApplications.isEmpty {
                    ContentUnavailableView("No applications", systemImage: "app.dashed", description: Text("Try another search or refresh the app list"))
                } else {
                    ForEach(appModel.filteredApplications) {
                        ApplicationRowView(application: $0)
                    }
                }
            }
        }
        .frame(height: 300)
    }
}
