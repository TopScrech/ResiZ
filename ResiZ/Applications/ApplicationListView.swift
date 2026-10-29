import SwiftUI

struct ApplicationListView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if appModel.isLoading && appModel.applications.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.top, 40)
                } else if let error = appModel.catalogError {
                    ContentUnavailableView("Couldn’t read applications", systemImage: "exclamationmark.folder", description: Text(error))
                } else if appModel.filteredApplications.isEmpty {
                    ContentUnavailableView(
                        appModel.showsEnabledOnly ? "No enabled apps" : "No results",
                        systemImage: appModel.showsEnabledOnly ? "app.dashed" : "magnifyingglass",
                        description: Text(appModel.showsEnabledOnly ? "Turn an app on to see it here" : "Try another search")
                    )
                } else {
                    ForEach(appModel.filteredApplications) {
                        ApplicationRowView(application: $0)
                    }
                }
            }
            .padding(6)
        }
        .scrollIndicators(.never)
        .frame(height: 320)
    }
}
