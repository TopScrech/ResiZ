import Foundation

nonisolated struct ApplicationCatalog {
    @concurrent static func discover(customURLs: [URL]) async throws -> [InstalledApplication] {
        try readApplications(customURLs: customURLs)
    }

    static func application(at url: URL, isCustom: Bool = false) -> InstalledApplication? {
        guard url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              let id = bundle.bundleIdentifier,
              id != Bundle.main.bundleIdentifier else { return nil }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return InstalledApplication(id: id, name: name, url: url, isCustom: isCustom)
    }

    private static func readApplications(customURLs: [URL]) throws -> [InstalledApplication] {
        var apps: [String: InstalledApplication] = [:]
        let scanError = try scan(URL(filePath: "/Applications", directoryHint: .isDirectory), into: &apps)
        _ = try? scan(URL.homeDirectory.appending(path: "Applications", directoryHint: .isDirectory), into: &apps)

        // Apps the user added explicitly win so they can be removed again
        for url in customURLs {
            if let app = application(at: url, isCustom: true) {
                apps[app.id] = app
            }
        }
        if apps.isEmpty, let scanError { throw scanError }
        return apps.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func scan(_ root: URL, into apps: inout [String: InstalledApplication]) throws -> (any Error)? {
        var scanError: (any Error)?
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, error in
                scanError = error
                return true
            }
        ) else {
            throw CocoaError(.fileReadNoPermission)
        }

        for case let url as URL in enumerator {
            try Task.checkCancellation()
            if let app = application(at: url) {
                apps[app.id] = app
            }
        }
        return scanError
    }
}
