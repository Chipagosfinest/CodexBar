import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 180),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = "Widget Desktop Smoke Host"
        let label = NSTextField(labelWithString: "Widget Desktop Smoke Host")
        label.identifier = NSUserInterfaceItemIdentifier("widget-desktop-smoke-host")
        label.frame = NSRect(x: 24, y: 78, width: 272, height: 24)
        window.contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView?.addSubview(label)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
