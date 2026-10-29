import SwiftUI
import AppKit
import ApplicationServices

@Observable @MainActor final class AppModel {
    var applications: [InstalledApplication] = []
    var searchText = ""
    var showsEnabledOnly = false
    var automaticallyDetects: Bool
    private(set) var isLoading = false
    private(set) var catalogError: String?
    private(set) var hasAccessibilityPermission = false
    private(set) var isShortcutActive = false
    private(set) var lastMessage: String?
    private var overrides: [String: Bool]
    private var detections: [String: ApplicationDetection] = [:]
    @ObservationIgnored private let listener = ShortcutListener()
    @ObservationIgnored private let accessibility = WindowAccessibility()
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var lastDetectionID: String?
    @ObservationIgnored private var lastDetectionTime = ContinuousClock.now - .seconds(30)
    @ObservationIgnored private var isToggling = false

    init() {
        overrides = UserDefaults.standard.dictionary(forKey: "applicationOverrides") as? [String: Bool] ?? [:]
        automaticallyDetects = UserDefaults.standard.object(forKey: "automaticallyDetects") as? Bool ?? true
        listener.onShortcut = { [weak self] in self?.handleShortcut() ?? false }
        refreshPermission()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.refreshPermission()
                await self?.detectFrontmostApplication()
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

    func isEnabled(_ id: String) -> Bool {
        overrides[id] ?? (automaticallyDetects && detections[id] == .needsShortcut)
    }

    func hasOverride(_ id: String) -> Bool { overrides[id] != nil }

    func detail(for id: String) -> String {
        if let enabled = overrides[id] {
            return enabled ? "Enabled manually" : "Disabled manually"
        }
        guard automaticallyDetects else { return "Automatic detection off" }
        return detections[id]?.description ?? "Open this app to detect its shortcut"
    }

    func setEnabled(_ enabled: Bool, for id: String) {
        overrides[id] = enabled
        UserDefaults.standard.set(overrides, forKey: "applicationOverrides")
    }

    func clearOverride(for id: String) {
        overrides[id] = nil
        UserDefaults.standard.set(overrides, forKey: "applicationOverrides")
        lastDetectionID = nil
    }

    func saveAutomaticDetection() {
        UserDefaults.standard.set(automaticallyDetects, forKey: "automaticallyDetects")
        lastDetectionID = nil
    }

    func refreshApplications() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            applications = try await ApplicationCatalog.discover()
            catalogError = nil
            lastDetectionID = nil
        } catch is CancellationError {
        } catch {
            catalogError = error.localizedDescription
        }
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

    private func detectFrontmostApplication() async {
        guard automaticallyDetects, hasAccessibilityPermission,
              let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier,
              id != Bundle.main.bundleIdentifier,
              app.activationPolicy == .regular,
              overrides[id] == nil else { return }
        let detectionID = "\(id):\(app.processIdentifier)"
        guard detectionID != lastDetectionID || ContinuousClock.now - lastDetectionTime > .seconds(20) else { return }
        lastDetectionID = detectionID
        lastDetectionTime = .now
        let result = await accessibility.detect(processID: app.processIdentifier)
        guard hasAccessibilityPermission else { return }
        detections[id] = result
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
