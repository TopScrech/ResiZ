import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(spacing: 0) {
            HeaderView()
                .padding()

            AccessibilityStatusView()

            SearchBarView()
                .padding(.horizontal)
                .padding(.bottom, 8)

            Divider()

            ApplicationListView()

            Divider()

            FooterView()
                .padding(.horizontal)
                .padding(.vertical, 10)
        }
        .frame(width: 360)
        .task { await appModel.refreshApplications() }
    }
}
