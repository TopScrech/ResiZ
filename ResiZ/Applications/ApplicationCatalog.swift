import Foundation

nonisolated struct ApplicationCatalog {
    @concurrent static func discover() async throws -> [InstalledApplication] {
        try readApplications()
    }

    private static func readApplications() throws -> [InstalledApplication] {
        let root = URL(filePath: "/Applications", directoryHint: .isDirectory)
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

        var apps: [String: InstalledApplication] = [:]
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            guard url.pathExtension.lowercased() == "app",
                  let bundle = Bundle(url: url),
                  let id = bundle.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier else { continue }

            let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent
            apps[id] = InstalledApplication(id: id, name: name, url: url)
        }
        if apps.isEmpty, let scanError { throw scanError }
        return apps.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
