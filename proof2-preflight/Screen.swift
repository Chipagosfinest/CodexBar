import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 680, height: 300),
                      styleMask: [.titled], backing: .buffered, defer: false)
window.title = "Synthetic actual-screen preflight"
let title = NSTextField(labelWithString: "SYNTHETIC SCREEN PREFLIGHT — no accounts or providers")
title.frame = NSRect(x: 20, y: 230, width: 640, height: 30)
window.contentView?.addSubview(title)
window.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
let menu = NSMenu(title: "Native onscreen menu")
menu.addItem(NSMenuItem(title: "Synthetic native NSMenu", action: nil, keyEquivalent: ""))
menu.addItem(NSMenuItem(title: "Healthy 11% used", action: nil, keyEquivalent: ""))
DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    menu.popUp(positioning: nil, at: NSPoint(x: 50, y: 200), in: window.contentView)
}
DispatchQueue.main.asyncAfter(deadline: .now() + 12) { app.terminate(nil) }
app.run()
