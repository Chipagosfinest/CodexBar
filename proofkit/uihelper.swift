// Window listing, accessibility tree dumps and real CGEvent input. Touches no CodexBar code.
import AppKit
import ApplicationServices
import CoreGraphics
let args = CommandLine.arguments
func json(_ o: Any) -> String { String(data: try! JSONSerialization.data(withJSONObject: o), encoding: .utf8)! }
func ownerWindows(_ owner: String) -> [[String: Any]] {
    let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return raw.compactMap { w in
        guard (w[kCGWindowOwnerName as String] as? String) == owner else { return nil }
        let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
        return ["id": w[kCGWindowNumber as String] as? Int ?? 0, "layer": w[kCGWindowLayer as String] as? Int ?? 0,
                "name": w[kCGWindowName as String] as? String ?? "",
                "x": b["X"] ?? 0, "y": b["Y"] ?? 0, "w": b["Width"] ?? 0, "h": b["Height"] ?? 0]
    }
}
func post(_ type: CGEventType, _ p: CGPoint) {
    CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}
func click(_ x: Double, _ y: Double) {
    let p = CGPoint(x: x, y: y)
    post(.mouseMoved, p); usleep(150_000); post(.leftMouseDown, p); usleep(80_000); post(.leftMouseUp, p)
}
/// Moves in small steps, as a hand does, so tracking areas and NSMenu's submenu timers see continuous motion.
func glide(_ x: Double, _ y: Double, _ steps: Int) {
    let cur = CGEvent(source: nil)?.location ?? .zero
    for i in 1...max(steps, 1) {
        let f = Double(i) / Double(max(steps, 1))
        post(.mouseMoved, CGPoint(x: cur.x + (x - cur.x) * f, y: cur.y + (y - cur.y) * f))
        usleep(16_000)
    }
}
func key(_ code: CGKeyCode, _ flags: CGEventFlags) {
    let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true); d?.flags = flags; d?.post(tap: .cghidEventTap)
    usleep(60_000)
    let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false); u?.flags = flags; u?.post(tap: .cghidEventTap)
}
func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}
func describe(_ el: AXUIElement, _ depth: Int, _ limit: Int) -> [String: Any] {
    var o: [String: Any] = [:]
    for (k, a) in [("role", "AXRole"), ("title", "AXTitle"), ("desc", "AXDescription"), ("value", "AXValue"),
                   ("help", "AXHelp"), ("identifier", "AXIdentifier"), ("sub", "AXSubrole")] {
        if let s = attr(el, a) as? String, !s.isEmpty { o[k] = s }
        else if let n = attr(el, a) as? NSNumber { o[k] = n.stringValue }
    }
    var p = CGPoint.zero, z = CGSize.zero
    if let v = attr(el, "AXPosition") { AXValueGetValue(v as! AXValue, .cgPoint, &p) }
    if let v = attr(el, "AXSize") { AXValueGetValue(v as! AXValue, .cgSize, &z) }
    o["x"] = p.x; o["y"] = p.y; o["w"] = z.width; o["h"] = z.height
    if depth < limit, let kids = attr(el, "AXChildren") as? [AXUIElement], !kids.isEmpty {
        o["kids"] = kids.map { describe($0, depth + 1, limit) }
    }
    return o
}
switch args[1] {
case "banner": // Real on-display provenance. A separate nonactivating panel, drawn over the Dock so it covers no app UI.
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    let screen = NSScreen.main!.frame
    let panel = NSPanel(contentRect: NSRect(x: screen.minX, y: screen.minY, width: screen.width, height: 46),
                        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.level = .statusBar
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    panel.backgroundColor = NSColor(calibratedRed: 0.55, green: 0.1, blue: 0.1, alpha: 1)
    let label = NSTextField(wrappingLabelWithString: args[2])
    label.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
    label.textColor = .white
    label.frame = NSRect(x: 10, y: 4, width: screen.width - 20, height: 38)
    panel.contentView?.addSubview(label)
    panel.orderFrontRegardless()
    app.run()
case "screen":
    let b = CGDisplayBounds(CGMainDisplayID())
    print(json(["x": b.origin.x, "y": b.origin.y, "w": b.size.width, "h": b.size.height]))
case "iconcheck": // path x y w h, in points: how many distinct colours are drawn in that region of a capture.
    guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: URL(fileURLWithPath: args[2]))) ?? Data()) else { print("{}"); exit(0) }
    let scale = Double(rep.pixelsWide) / Double(CGDisplayBounds(CGMainDisplayID()).size.width)
    let (x0, y0, w0, h0) = (Double(args[3])! * scale, Double(args[4])! * scale, Double(args[5])! * scale, Double(args[6])! * scale)
    var seen = Set<UInt32>()
    for y in Int(y0)..<min(Int(y0 + h0), rep.pixelsHigh) { for x in Int(x0)..<min(Int(x0 + w0), rep.pixelsWide) {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        seen.insert(UInt32(c.redComponent * 255) << 16 | UInt32(c.greenComponent * 255) << 8 | UInt32(c.blueComponent * 255))
    } }
    print(json(["colors": seen.count]))
case "trusted": print(AXIsProcessTrusted(), CGPreflightScreenCaptureAccess(), CGPreflightPostEventAccess())
case "windows": print(json(ownerWindows(args.count > 2 ? args[2] : "CodexBar")))
case "tree":  // pid, optional attribute (AXExtrasMenuBar or AXWindows)
    let app = AXUIElementCreateApplication(pid_t(args[2])!)
    let limit = args.count > 4 ? Int(args[4])! : 14
    if args.count > 3, args[3] == "AXWindows" {
        print(json((attr(app, "AXWindows") as? [AXUIElement] ?? []).map { describe($0, 0, limit) }))
    } else if let bar = attr(app, "AXExtrasMenuBar") {
        print(json(describe(bar as! AXUIElement, 0, limit)))
    } else { print("{}") }
case "click": click(Double(args[2])!, Double(args[3])!)
case "move": glide(Double(args[2])!, Double(args[3])!, args.count > 4 ? Int(args[4])! : 20)
case "cmd-r": key(15, .maskCommand)
case "esc": key(53, [])
case "return": key(36, [])
case "down": key(125, [])
case "up": key(126, [])
case "right": key(124, [])
case "dark": // Sets the session appearance through the same public switch System Settings uses.
    let on = args[2] == "1"
    let s = NSAppleScript(source: "tell application \"System Events\" to tell appearance preferences to set dark mode to \(on)")
    var e: NSDictionary?
    s?.executeAndReturnError(&e); print(e ?? "ok")
case "clipboard": // Writes the current image on the general pasteboard to a path and reports its pixels.
    let pb = NSPasteboard.general
    guard let d = pb.data(forType: .png) ?? pb.data(forType: .tiff),
          let rep = NSBitmapImageRep(data: d), let png = rep.representation(using: .png, properties: [:]) else {
        print(json(["types": (pb.types ?? []).map(\.rawValue), "png": false])); exit(0)
    }
    try! png.write(to: URL(fileURLWithPath: args[2]))
    print(json(["types": (pb.types ?? []).map(\.rawValue), "png": true, "w": rep.pixelsWide, "h": rep.pixelsHigh,
                "changeCount": pb.changeCount]))
case "clearclipboard": NSPasteboard.general.clearContents(); print(NSPasteboard.general.changeCount)
default: exit(2)
}
