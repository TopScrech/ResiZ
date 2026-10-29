import Foundation

nonisolated enum ApplicationDetection: Sendable {
    case needsShortcut, hasShortcut, unsupported, unavailable

    var description: String {
        switch self {
        case .needsShortcut: "Missing shortcut · enabled automatically"
        case .hasShortcut: "Already has Control–Command–F"
        case .unsupported: "Window doesn’t expose fullscreen"
        case .unavailable: "Couldn’t verify · enable manually or try another window"
        }
    }
}
