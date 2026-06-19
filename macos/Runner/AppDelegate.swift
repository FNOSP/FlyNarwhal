import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidBecomeActive(_ notification: Notification) {
    restoreMainWindowIfNeeded()
  }

  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      restoreMainWindowIfNeeded()
    }
    return true
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // Keep the app resident in Dock after the main window is closed.
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  private func restoreMainWindowIfNeeded() {
    guard let window = NSApp.mainWindow ?? NSApp.windows.first else {
      return
    }

    if window.isMiniaturized {
      window.deminiaturize(nil)
    }

    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }
}
