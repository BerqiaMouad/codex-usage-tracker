import AppKit

enum AppResources {
    static var appIcon: NSImage? {
        Bundle.module.url(forResource: "CodexUsageTracker", withExtension: "icns")
            .flatMap(NSImage.init(contentsOf:))
    }
}
