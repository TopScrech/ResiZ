import ApplicationServices
import Foundation

actor WindowAccessibility {
    private let fullscreenAttribute = "AXFullScreen" as CFString

    func toggleFullscreen(processID: pid_t) -> String? {
        let application = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(application, 0.2)
        guard let window = focusedWindow(in: application) else {
            return "No focused window was available"
        }
        guard let current = value(of: fullscreenAttribute, in: window) as? Bool else {
            return "This window doesn’t expose fullscreen through Accessibility"
        }
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(window, fullscreenAttribute, &settable) == .success,
              settable.boolValue else {
            return "This window doesn’t allow fullscreen through Accessibility"
        }
        let result = AXUIElementSetAttributeValue(window, fullscreenAttribute, current ? kCFBooleanFalse : kCFBooleanTrue)
        guard result == .success else {
            return "Couldn’t change fullscreen for this window — Accessibility error \(result.rawValue)"
        }
        return nil
    }

    func detect(processID: pid_t) -> ApplicationDetection {
        let application = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(application, 0.15)
        guard let window = focusedWindow(in: application) else { return .unavailable }
        var settable: DarwinBoolean = false
        guard AXUIElementIsAttributeSettable(window, fullscreenAttribute, &settable) == .success,
              settable.boolValue,
              value(of: fullscreenAttribute, in: window) is Bool else { return .unsupported }
        guard let menu = element(of: kAXMenuBarAttribute as CFString, in: application),
              let children = value(of: kAXChildrenAttribute as CFString, in: menu) as? [AXUIElement],
              !children.isEmpty else { return .unavailable }

        var pending = children
        var visited = 0
        let deadline = ContinuousClock.now + .seconds(2)
        while let item = pending.popLast() {
            guard visited < 1_200, ContinuousClock.now < deadline, !Task.isCancelled else { return .unavailable }
            visited += 1
            let character = value(of: "AXMenuItemCmdChar" as CFString, in: item) as? String
            let virtualKey = value(of: "AXMenuItemCmdVirtualKey" as CFString, in: item) as? NSNumber
            if character?.lowercased() == "f" || virtualKey?.intValue == 3 {
                // Accessibility menu modifiers use Carbon bits: Control = 4, Command is implicit
                guard let modifiers = value(of: "AXMenuItemCmdModifiers" as CFString, in: item) as? NSNumber else {
                    return .unavailable
                }
                if modifiers.intValue == 4 { return .hasShortcut }
            }

            var childValue: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &childValue)
            if result == .success, let descendants = childValue as? [AXUIElement] {
                pending.append(contentsOf: descendants)
            } else if result != .noValue && result != .attributeUnsupported {
                return .unavailable
            }
        }
        return .needsShortcut
    }

    private func focusedWindow(in application: AXUIElement) -> AXUIElement? {
        element(of: kAXFocusedWindowAttribute as CFString, in: application)
            ?? element(of: kAXMainWindowAttribute as CFString, in: application)
    }

    private func value(of attribute: CFString, in element: AXUIElement) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &result) == .success else { return nil }
        return result
    }

    private func element(of attribute: CFString, in parent: AXUIElement) -> AXUIElement? {
        guard let result = value(of: attribute, in: parent),
              CFGetTypeID(result) == AXUIElementGetTypeID() else { return nil }
        return (result as! AXUIElement)
    }
}
