import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import AVFoundation

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func frame(_ element: AXUIElement) -> [String: Double] {
    var point = CGPoint.zero
    var size = CGSize.zero
    if let value = attribute(element, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
        AXValueGetValue(value as! AXValue, .cgPoint, &point)
    }
    if let value = attribute(element, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
        AXValueGetValue(value as! AXValue, .cgSize, &size)
    }
    return ["x": point.x, "y": point.y, "w": size.width, "h": size.height]
}

func ax(_ pid: pid_t) -> [[String: Any]] {
    let app = AXUIElementCreateApplication(pid)
    var result: [[String: Any]] = []
    var visited = Set<CFHashCode>()
    func visit(_ element: AXUIElement, _ depth: Int) {
        guard depth <= 20, result.count < 2500, visited.insert(CFHash(element)).inserted else { return }
        var row: [String: Any] = ["depth": depth, "frame": frame(element)]
        for (key, name) in [("role", kAXRoleAttribute), ("title", kAXTitleAttribute),
                            ("description", kAXDescriptionAttribute), ("value", kAXValueAttribute),
                            ("help", kAXHelpAttribute), ("identifier", kAXIdentifierAttribute)] {
            if let text = attribute(element, name) as? String { row[key] = text }
        }
        result.append(row)
        for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] { visit(child, depth + 1) }
    }
    visit(app, 0)
    if let bar = attribute(app, kAXExtrasMenuBarAttribute) { visit(bar as! AXUIElement, 0) }
    for window in attribute(app, kAXWindowsAttribute) as? [AXUIElement] ?? [] { visit(window, 0) }
    return result
}

func windows(_ pid: pid_t) -> [[String: Any]] {
    let all = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return all.compactMap { window in
        guard (window[kCGWindowOwnerPID as String] as? Int) == Int(pid) else { return nil }
        let bounds = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
        return ["id": window[kCGWindowNumber as String] as? Int ?? 0,
                "ownerPID": window[kCGWindowOwnerPID as String] as? Int ?? 0,
                "layer": window[kCGWindowLayer as String] as? Int ?? 0,
                "x": bounds["X"] ?? 0, "y": bounds["Y"] ?? 0,
                "w": bounds["Width"] ?? 0, "h": bounds["Height"] ?? 0]
    }
}

func displayBounds() -> [CGRect] {
    var displays = [CGDirectDisplayID](repeating: 0, count: 16)
    var count: UInt32 = 0
    guard CGGetActiveDisplayList(16, &displays, &count) == .success else { return [] }
    return displays.prefix(Int(count)).map { CGDisplayBounds($0) }
}

func requirePoint(_ x: Double, _ y: Double) throws -> CGPoint {
    let point = CGPoint(x: x, y: y)
    guard x.isFinite, y.isFinite, displayBounds().contains(where: { $0.contains(point) }) else {
        throw CocoaError(.validationMissingMandatoryProperty)
    }
    return point
}

func move(_ x: Double, _ y: Double) throws {
    let point = try requirePoint(x, y)
    guard let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                             mouseCursorPosition: point, mouseButton: .left) else { throw CocoaError(.featureUnsupported) }
    event.post(tap: .cghidEventTap)
}

func click(_ x: Double, _ y: Double) throws {
    let point = try requirePoint(x, y)
    try move(x, y)
    usleep(150_000)
    for kind in [CGEventType.leftMouseDown, .leftMouseUp] {
        guard let event = CGEvent(mouseEventSource: nil, mouseType: kind,
                                 mouseCursorPosition: point, mouseButton: .left) else { throw CocoaError(.featureUnsupported) }
        event.post(tap: .cghidEventTap)
        usleep(80_000)
    }
}

func imageInfo(_ path: String) throws -> [String: Any] {
    guard let image = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: path))) else {
        throw CocoaError(.fileReadCorruptFile)
    }
    var minimum = 1.0
    var maximum = 0.0
    for y in stride(from: 0, to: image.pixelsHigh, by: max(1, image.pixelsHigh / 150)) {
        for x in stride(from: 0, to: image.pixelsWide, by: max(1, image.pixelsWide / 150)) {
            if let color = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) {
                let value = Double((color.redComponent + color.greenComponent + color.blueComponent) / 3)
                minimum = min(minimum, value)
                maximum = max(maximum, value)
            }
        }
    }
    return ["width": image.pixelsWide, "height": image.pixelsHigh, "contrast": maximum - minimum]
}

func screenSimilarity(_ screenPath: String, _ menuPath: String, _ rectangle: CGRect,
                      recordedDisplay: CGRect? = nil) throws -> [String: Any] {
    let availableDisplays = recordedDisplay.map { [$0] } ?? displayBounds()
    guard let screen = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: screenPath))),
          let menu = NSBitmapImageRep(data: try Data(contentsOf: URL(fileURLWithPath: menuPath))),
          let display = availableDisplays.first, availableDisplays.count == 1, display.contains(rectangle)
    else { throw CocoaError(.fileReadCorruptFile) }
    let scale = CGFloat(screen.pixelsWide) / display.width
    guard abs(CGFloat(screen.pixelsHigh) - display.height * scale) < 2 else { throw CocoaError(.featureUnsupported) }
    var errors: [Double] = []
    for row in 2..<38 {
        for column in 2..<28 {
            let u = CGFloat(column) / 30
            let v = CGFloat(row) / 40
            let sx = Int((rectangle.minX - display.minX + rectangle.width * u) * scale)
            let sy = Int((rectangle.minY - display.minY + rectangle.height * v) * scale)
            guard let a = screen.colorAt(x: sx, y: sy)?.usingColorSpace(.sRGB),
                  let b = menu.colorAt(x: Int(CGFloat(menu.pixelsWide) * u), y: Int(CGFloat(menu.pixelsHigh) * v))?
                  .usingColorSpace(.sRGB) else { continue }
            errors.append(Double((abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent) +
                                  abs(a.blueComponent - b.blueComponent)) / 3))
        }
    }
    guard !errors.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
    return ["samples": errors.count, "meanRGBError": errors.reduce(0, +) / Double(errors.count),
            "screenWidth": screen.pixelsWide, "screenHeight": screen.pixelsHigh,
            "menuWidth": menu.pixelsWide, "menuHeight": menu.pixelsHigh]
}

func escape() {
    for down in [true, false] {
        CGEvent(keyboardEventSource: nil, virtualKey: 53, keyDown: down)?.post(tap: .cghidEventTap)
        usleep(60_000)
    }
}

func writeJSON(_ value: Any, _ url: URL? = nil) throws {
    let data = try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys])
    if let url { try data.write(to: url, options: .atomic) }
    else { print(String(decoding: data, as: UTF8.self)) }
}

@MainActor
private final class ProofDisplay: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let mode: String
    let output: URL
    let product: String
    let overlay: String
    var window: NSWindow?
    var item: NSStatusItem?
    var timers: [Timer] = []

    init(mode: String, output: URL, product: String, overlay: String) {
        self.mode = mode
        self.output = output
        self.product = product
        self.overlay = overlay
    }

    func applicationDidFinishLaunching(_: Notification) {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1024, height: 768)
        let width = min(650, screen.width - 380)
        let window = NSWindow(contentRect: NSRect(x: 12, y: 20, width: width, height: 95),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .floating
        window.backgroundColor = .windowBackgroundColor
        let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 95))
        for (index, text) in ["SYNTHETIC BUILT-APP UI PROOF — declared early-entry overlay",
                              "Product: \(self.product)", "Overlay SHA256: \(self.overlay)",
                              "No shipping startup or live-account claim"].enumerated() {
            let label = NSTextField(labelWithString: text)
            label.font = .monospacedSystemFont(ofSize: index == 0 ? 10 : 8, weight: .regular)
            label.frame = NSRect(x: 10, y: 72 - index * 20, width: Int(width) - 20, height: 18)
            view.addSubview(label)
        }
        window.contentView = view
        window.orderFront(nil)
        self.window = window
        if self.mode == "preflight" {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            item.button?.title = "Proof UI"
            let menu = NSMenu()
            menu.delegate = self
            menu.addItem(withTitle: "SYNTHETIC CGEvent opened this native menu", action: nil, keyEquivalent: "")
            item.menu = menu
            self.item = item
            self.schedule(0.7) { [weak self] in
                guard let self, let button = self.item?.button, let host = button.window else { return }
                let rect = host.convertToScreen(button.convert(button.bounds, to: nil))
                do { try click(rect.midX, screen.height - rect.midY) }
                catch {
                    try? writeJSON(["preflightPassed": false, "reason": "Offscreen/invalid status-item target"],
                                   self.output.appendingPathComponent("preflight.json"))
                    NSApp.terminate(nil)
                }
            }
            self.schedule(20) {
                try? writeJSON(["synthetic": true, "preflightPassed": false, "reason": "No native menu event"],
                               self.output.appendingPathComponent("preflight.json"))
                NSApp.terminate(nil)
            }
        }
    }

    private func schedule(_ delay: Double, _ operation: @escaping @MainActor () -> Void) {
        let timer = Timer(timeInterval: delay, repeats: false) { _ in MainActor.assumeIsolated { operation() } }
        self.timers.append(timer)
        RunLoop.main.add(timer, forMode: .common)
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard self.mode == "preflight" else { return }
        self.schedule(0.6) {
            do {
                for arguments in [["-x", self.output.appendingPathComponent("preflight-screen.png").path],
                                  ["-v", "-V", "3", "-x", self.output.appendingPathComponent("preflight-screen.mov").path]] {
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                    task.arguments = arguments
                    try task.run()
                    task.waitUntilExit()
                    guard task.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
                }
                try writeJSON(["synthetic": true, "preflightPassed": true, "actualCGEventOpenedNativeMenu": true,
                               "axTrusted": AXIsProcessTrusted(), "screenCaptureAllowed": CGPreflightScreenCaptureAccess(),
                               "postEventAllowed": CGPreflightPostEventAccess()], self.output.appendingPathComponent("preflight.json"))
            } catch {
                try? writeJSON(["preflightPassed": false, "error": String(describing: error)],
                               self.output.appendingPathComponent("preflight.json"))
            }
            menu.cancelTracking()
            NSApp.terminate(nil)
        }
    }
}

@main @MainActor
struct ChartNativeUI {
    static func main() throws {
        let args = CommandLine.arguments
        switch args[1] {
        case "ax": try writeJSON(ax(pid_t(args[2])!))
        case "windows": try writeJSON(windows(pid_t(args[2])!))
        case "click": try click(Double(args[2])!, Double(args[3])!)
        case "move": try move(Double(args[2])!, Double(args[3])!)
        case "esc": escape()
        case "displays": try writeJSON(displayBounds().map { ["x": $0.minX, "y": $0.minY, "w": $0.width, "h": $0.height] })
        case "image-info": try writeJSON(imageInfo(args[2]))
        case "screen-similarity":
            try writeJSON(screenSimilarity(args[2], args[3], CGRect(x: Double(args[4])!, y: Double(args[5])!,
                                                                  width: Double(args[6])!, height: Double(args[7])!)))
        case "screen-similarity-recorded":
            // Offline controls only. The live driver always uses screen-similarity with actual CG displays.
            try writeJSON(screenSimilarity(args[2], args[3], CGRect(x: Double(args[4])!, y: Double(args[5])!,
                                                                  width: Double(args[6])!, height: Double(args[7])!),
                                           recordedDisplay: CGRect(x: Double(args[8])!, y: Double(args[9])!,
                                                                   width: Double(args[10])!, height: Double(args[11])!)))
        case "application":
            guard let application = NSRunningApplication(processIdentifier: pid_t(args[2])!) else { throw CocoaError(.fileNoSuchFile) }
            try writeJSON(["pid": application.processIdentifier, "executable": application.executableURL?.path ?? "",
                           "bundle": application.bundleURL?.path ?? ""])
        case "trusted": try writeJSON(["ax": AXIsProcessTrusted(), "screen": CGPreflightScreenCaptureAccess(), "post": CGPreflightPostEventAccess()])
        case "media":
            let asset = AVURLAsset(url: URL(fileURLWithPath: args[2]))
            let size = asset.tracks(withMediaType: .video).first?.naturalSize ?? .zero
            try writeJSON(["duration": CMTimeGetSeconds(asset.duration), "width": size.width, "height": size.height])
        case "preflight", "banner":
            let output = URL(fileURLWithPath: args[2], isDirectory: true)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
            let delegate = ProofDisplay(mode: args[1], output: output,
                                        product: args.count > 3 ? args[3] : "synthetic preflight",
                                        overlay: args.count > 4 ? args[4] : "no product build yet")
            let application = NSApplication.shared
            application.setActivationPolicy(.accessory)
            application.delegate = delegate
            withExtendedLifetime(delegate) { application.run() }
        default: throw CocoaError(.featureUnsupported)
        }
    }
}
