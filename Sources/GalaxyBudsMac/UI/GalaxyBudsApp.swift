import AppKit
import ServiceManagement
import SwiftUI

@main
struct GalaxyBudsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var buds = BudsController.shared

    var body: some Scene {
        Window("NebulaBuds", id: "main") {
            ContentView()
                .environment(buds)
                .frame(minWidth: 820, minHeight: 560)
        }
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView().environment(buds)
        } label: {
            Image(systemName: buds.isConnected ? "earbuds" : "earbuds.case")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchAtLogin.enableOnFirstRun()

        // Started by the login item: live in the menu bar only, no window or Dock icon.
        if Self.launchedAtLogin {
            NSApp.setActivationPolicy(.accessory)
            DispatchQueue.main.async { Self.mainWindows.forEach { $0.close() } }
        } else {
            NSApp.setActivationPolicy(.regular)
            DispatchQueue.main.async {
                NSApp.activate()
                Self.mainWindows.first?.makeKeyAndOrderFront(nil)
            }
        }

        // The Dock icon follows the main window: hidden when it closes, shown when it opens.
        let center = NotificationCenter.default
        center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { note in
            guard let closing = note.object as? NSWindow, Self.isMainWindow(closing) else { return }
            if Self.mainWindows.allSatisfy({ $0 === closing || !$0.isVisible }) {
                NSApp.setActivationPolicy(.accessory)
            }
        }
        center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { note in
            guard let window = note.object as? NSWindow, Self.isMainWindow(window) else { return }
            NSApp.setActivationPolicy(.regular)
        }

        Task { @MainActor in BudsController.shared.start() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    private static var launchedAtLogin: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        return event.eventID == kAEOpenApplication
            && event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    private static func isMainWindow(_ w: NSWindow) -> Bool { !(w is NSPanel) && w.canBecomeMain }
    private static var mainWindows: [NSWindow] { NSApp.windows.filter(isMainWindow) }
}

enum LaunchAtLogin {
    static var status: SMAppService.Status { SMAppService.mainApp.status }
    static var isEnabled: Bool { status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("GalaxyBuds: launch at login %@ failed: %@", enabled ? "register" : "unregister", "\(error)")
        }
    }

    static func enableOnFirstRun() {
        let key = "didSetUpLaunchAtLogin"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        set(true)
    }
}
