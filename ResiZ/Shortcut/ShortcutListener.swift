import CoreGraphics
import Foundation

@MainActor final class ShortcutListener {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var suppressedKeyDown = false
    var onShortcut: (() -> Bool)?

    var isActive: Bool { eventTap != nil }

    func start() -> Bool {
        if isActive { return true }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                // The source is installed exclusively on the main run loop
                let suppress = MainActor.assumeIsolated {
                    let listener = Unmanaged<ShortcutListener>.fromOpaque(context).takeUnretainedValue()
                    return listener.handle(type: type, event: event)
                }
                return suppress ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return false }
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
        suppressedKeyDown = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            suppressedKeyDown = false
            return false
        }
        guard event.getIntegerValueField(.keyboardEventKeycode) == 3 else {
            return false
        }
        if type == .keyUp {
            let suppress = suppressedKeyDown
            suppressedKeyDown = false
            return suppress
        }
        if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return suppressedKeyDown
        }
        let modifiers = event.flags.intersection([.maskCommand, .maskControl, .maskShift, .maskAlternate])
        guard modifiers == [.maskCommand, .maskControl] else { return false }
        suppressedKeyDown = onShortcut?() == true
        return suppressedKeyDown
    }
}
