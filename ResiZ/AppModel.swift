import SwiftUI
import AppKit
import ApplicationServices

@Observable @MainActor final class AppModel {
    var applications: [InstalledApplication] = []
    var searchText = ""
    var showsEnabledOnly = false
    private(set) var isLoading = false
    private(set) var isDetecting = false
    private(set) var catalogError: String?
    private(set) var hasAccessibilityPermission = false
    private(set) var isShortcutActive = false
    private(set) var lastMessage: String?
    private var overrides: [String: Bool]
    private var customApplicationPaths: [String]
    private var detections: [String: ApplicationDetection] = [:]
    @ObservationIgnored private let listener = ShortcutListener()
    @ObservationIgnored private let accessibility = WindowAccessibility()
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var isToggling = false

    init() {
        overrides = UserDefaults.standard.dictionary(forKey: "applicationOverrides") as? [String: Bool] ?? [:]
        customApplicationPaths = UserDefaults.standard.stringArray(forKey: "customApplicationPaths") ?? []
        listener.onShortcut = { [weak self] in self?.handleShortcut() ?? false }
        refreshPermission()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshPermission()
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
            }
        }
    }

    var filteredApplications: [InstalledApplication] {
        applications.filter {
            (searchText.isEmpty || $0.name.localizedStandardContains(searchText))
                && (!showsEnabledOnly || isEnabled($0.id))
        }
    }

    var enabledAppCount: Int { applications.filter { isEnabled($0.id) }.count }

    var statusTitle: String {
        if !hasAccessibilityPermission { return "Accessibility permission needed" }
        return isShortcutActive ? "Shortcut ready" : "Shortcut listener unavailable"
    }

    func isEnabled(_ id: String) -> Bool { overrides[id] ?? false }

    func detail(for id: String) -> String {
        detections[id]?.description ?? (isEnabled(id) ? "Enabled" : "Off")
    }

    func setEnabled(_ enabled: Bool, for id: String) {
        overrides[id] = enabled
        detections[id] = nil
        UserDefaults.standard.set(overrides, forKey: "applicationOverrides")
    }

    /// Checks running apps once and enables the ones missing Control–Command–F, leaving apps the user turned off alone
    func detectMissingShortcuts() async {
        guard hasAccessibilityPermission, !isDetecting else { return }
        isDetecting = true
        defer { isDetecting = false }
        let installed = Set(applications.map(\.id))
        let running = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier
                && installed.contains($0.bundleIdentifier ?? "")
        }
        var enabledCount = 0
        for app in running {
            guard let id = app.bundleIdentifier else { continue }
            let result = await accessibility.detect(processID: app.processIdentifier)
            guard hasAccessibilityPermission else { return }
            detections[id] = result
            if result == .needsShortcut, overrides[id] == nil {
                overrides[id] = true
                enabledCount += 1
            }
        }
        UserDefaults.standard.set(overrides, forKey: "applicationOverrides")
        lastMessage = running.isEmpty
            ? "Open the apps you want to check, then detect again"
            : "Checked \(running.count) running apps · enabled \(enabledCount)"
    }

    func refreshApplications() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await ApplicationCatalog.discover(customURLs: customApplicationPaths.map { URL(filePath: $0) })
            catalogError = nil
        } catch is CancellationError {
        } catch {
            catalogError = error.localizedDescription
        }
    }

    /// Adds apps from any location and turns them on, since picking an app signals the user wants it
    func addApplications(_ urls: [URL]) async {
        for url in urls {
            guard let app = ApplicationCatalog.application(at: url) else { continue }
            if !customApplicationPaths.contains(url.path) {
                customApplicationPaths.append(url.path)
            }
            setEnabled(true, for: app.id)
        }
        UserDefaults.standard.set(customApplicationPaths, forKey: "customApplicationPaths")
        await refreshApplications()
    }

    func removeCustomApplication(_ application: InstalledApplication) async {
        customApplicationPaths.removeAll { $0 == application.url.path }
        UserDefaults.standard.set(customApplicationPaths, forKey: "customApplicationPaths")
        overrides[application.id] = nil
        detections[application.id] = nil
        UserDefaults.standard.set(overrides, forKey: "applicationOverrides")
        await refreshApplications()
    }

    func refreshPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
        if hasAccessibilityPermission {
            isShortcutActive = listener.start()
        } else {
            listener.stop()
            isShortcutActive = false
            detections.removeAll()
        }
    }

    func openAccessibilitySettings() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func quit() {
        monitorTask?.cancel()
        listener.stop()
        NSApplication.shared.terminate(nil)
    }

    private func handleShortcut() -> Bool {
        guard hasAccessibilityPermission,
              let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier,
              id != Bundle.main.bundleIdentifier,
              isEnabled(id) else { return false }
        guard !isToggling else { return true }
        isToggling = true
        let processID = app.processIdentifier
        Task { [weak self] in
            guard let self else { return }
            defer { isToggling = false }
            guard NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else { return }
            lastMessage = await accessibility.toggleFullscreen(processID: processID)
        }
        return true
    }
}
