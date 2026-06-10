import AppKit

enum AppResources {
    static var appIcon: NSImage? {
        Bundle.module.url(forResource: "CodexUsageTracker", withExtension: "icns")
            .flatMap(NSImage.init(contentsOf:))
    }

    static var menuBarIcon: NSImage? {
        Bundle.module.url(forResource: "CodexUsageTrackerMenuBar", withExtension: "png")
            .flatMap(NSImage.init(contentsOf:))
            .map { image in
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                return image
            }
    }
}
