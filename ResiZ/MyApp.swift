import SwiftUI

@main struct MyApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("ResiZ", systemImage: "arrow.up.left.and.arrow.down.right") {
            ContentView()
                .environment(appModel)
        }
        .menuBarExtraStyle(.window)
    }
}
