import Foundation

struct InstalledApplication: Identifiable, Sendable {
    let id: String
    let name: String
    let url: URL
}
