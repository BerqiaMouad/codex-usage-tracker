import AppKit
import SwiftUI

struct CodexUsageTrackerApp: App {
    @StateObject private var store = UsageStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("CodexLens") {
            DashboardView(store: store)
                .frame(minWidth: 1120, minHeight: 760)
        }
        .defaultSize(width: 1240, height: 820)

        Settings {
            SettingsView(store: store)
                .frame(width: 720, height: 520)
        }

        MenuBarExtra {
            MenuBarContent(store: store)
        } label: {
            MenuBarLabel(snapshot: store.snapshot)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let appIcon = AppResources.appIcon {
            NSApp.applicationIconImage = appIcon
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}

@main
enum CodexUsageTrackerMain {
    static func main() {
        if CommandLine.arguments.contains("--self-check") {
            do {
                try SelfCheck.run()
                print("Self-check passed.")
                Foundation.exit(EXIT_SUCCESS)
            } catch {
                fputs("Self-check failed: \(error.localizedDescription)\n", stderr)
                Foundation.exit(EXIT_FAILURE)
            }
        }

        CodexUsageTrackerApp.main()
    }
}
