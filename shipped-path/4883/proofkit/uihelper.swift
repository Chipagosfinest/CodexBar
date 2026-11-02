// Window listing, real CGEvent input, and pixel counts. Touches no CodexBar code.
import AppKit
import ApplicationServices
import CoreGraphics
let args = CommandLine.arguments
func windows() -> [[String: Any]] {
    let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return raw.compactMap { w in
        guard (w[kCGWindowOwnerName as String] as? String) == "CodexBar" else { return nil }
        let b = w[kCGWindowBounds as String] as? [String: CGFloat] ?? [:]
        return ["id": w[kCGWindowNumber as String] as? Int ?? 0, "layer": w[kCGWindowLayer as String] as? Int ?? 0,
                "x": b["X"] ?? 0, "y": b["Y"] ?? 0, "w": b["Width"] ?? 0, "h": b["Height"] ?? 0]
    }
}
func click(_ x: Double, _ y: Double) {
    let p = CGPoint(x: x, y: y)
    CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(150_000)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
    usleep(80_000)
    CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
}
func key(_ code: CGKeyCode, _ flags: CGEventFlags) {
    let d = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true); d?.flags = flags; d?.post(tap: .cghidEventTap)
    usleep(60_000)
    let u = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false); u?.flags = flags; u?.post(tap: .cghidEventTap)
}
/// Counts saturated Command Code purple pixels versus neutral bar-like pixels in the card's bar band.
func pixels(_ path: String) -> [String: Int] {
    guard let rep = NSBitmapImageRep(data: (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()) else { return [:] }
    var purple = 0, total = 0
    for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide {
        guard let c = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        total += 1
        if c.brightnessComponent > 0.45, c.saturationComponent > 0.35,
           c.hueComponent > 0.68, c.hueComponent < 0.82 { purple += 1 }
    } }
    return ["purple": purple, "total": total, "w": rep.pixelsWide, "h": rep.pixelsHigh]
}
/// The app's status item through its own accessibility tree (window lists may not expose it on macOS 26).
func statusItems(_ pid: pid_t) -> [[String: Any]] {
    let app = AXUIElementCreateApplication(pid)
    var bar: CFTypeRef?
    guard AXUIElementCopyAttributeValue(app, kAXExtrasMenuBarAttribute as CFString, &bar) == .success, let bar else { return [] }
    var kids: CFTypeRef?
    guard AXUIElementCopyAttributeValue(bar as! AXUIElement, kAXChildrenAttribute as CFString, &kids) == .success,
          let items = kids as? [AXUIElement] else { return [] }
    return items.map { el in
        var p = CGPoint.zero, z = CGSize.zero
        var pv: CFTypeRef?, sv: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXPositionAttribute as CFString, &pv)
        AXUIElementCopyAttributeValue(el, kAXSizeAttribute as CFString, &sv)
        if let pv { AXValueGetValue(pv as! AXValue, .cgPoint, &p) }
        if let sv { AXValueGetValue(sv as! AXValue, .cgSize, &z) }
        return ["x": p.x, "y": p.y, "w": z.width, "h": z.height]
    }
}
/// Screen frame of an open status menu's item, found by title through the accessibility tree.
func menuItem(_ pid: pid_t, _ title: String) -> [String: Any]? {
    func attr(_ el: AXUIElement, _ name: String) -> CFTypeRef? {
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
    }
    func find(_ el: AXUIElement, _ depth: Int) -> AXUIElement? {
        if (attr(el, kAXTitleAttribute) as? String) == title { return el }
        guard depth < 6, let kids = attr(el, kAXChildrenAttribute) as? [AXUIElement] else { return nil }
        for kid in kids { if let hit = find(kid, depth + 1) { return hit } }
        return nil
    }
    guard let bar = attr(AXUIElementCreateApplication(pid), kAXExtrasMenuBarAttribute),
          let el = find(bar as! AXUIElement, 0),
          let pv = attr(el, kAXPositionAttribute), let sv = attr(el, kAXSizeAttribute) else { return nil }
    var p = CGPoint.zero, z = CGSize.zero
    AXValueGetValue(pv as! AXValue, .cgPoint, &p); AXValueGetValue(sv as! AXValue, .cgSize, &z)
    return ["x": p.x, "y": p.y, "w": z.width, "h": z.height]
}
func allWindows() -> [String] {
    let raw = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    return raw.map { "\($0[kCGWindowOwnerName as String] ?? "?") layer=\($0[kCGWindowLayer as String] ?? "?") bounds=\($0[kCGWindowBounds as String] ?? "?") onscreen=\($0[kCGWindowIsOnscreen as String] ?? "?")" }
        .filter { $0.contains("CodexBar") || $0.contains("layer=25") }
}
switch args[1] {
case "items": print(String(data: try! JSONSerialization.data(withJSONObject: statusItems(pid_t(args[2])!)), encoding: .utf8)!)
case "all": print(allWindows().joined(separator: "\n"))
case "trusted": print(AXIsProcessTrusted(), CGPreflightScreenCaptureAccess(), CGPreflightPostEventAccess())
case "windows": print(String(data: try! JSONSerialization.data(withJSONObject: windows()), encoding: .utf8)!)
case "menu-item":
    let hit: Any = menuItem(pid_t(args[2])!, args[3]) ?? NSNull()
    print(String(data: try! JSONSerialization.data(withJSONObject: hit, options: .fragmentsAllowed), encoding: .utf8)!)
case "click": click(Double(args[2])!, Double(args[3])!)
case "cmd-r": key(15, .maskCommand)
case "esc": key(53, [])
case "pixels": print(String(data: try! JSONSerialization.data(withJSONObject: pixels(args[2])), encoding: .utf8)!)
default: exit(2)
}
