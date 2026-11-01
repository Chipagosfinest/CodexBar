import AppKit
import CodexBarCore
import SwiftUI
import Testing
@testable import CodexBar

/// Shipped-path proof: the Share AI Usage window's preview and the PNG that Copy Image puts on the
/// pasteboard, with the app appearance switched and no explicit appearance passed to the renderer.
@MainActor
struct V2ShareExportProofTests {
    @Test
    func `share window preview and copied image follow the app appearance`() throws {
        guard let dirPath = ProcessInfo.processInfo.environment["CODEXBAR_REDESIGN_PROOF_DIR"] else { return }
        let dir = URL(fileURLWithPath: dirPath)
        let app = NSApplication.shared
        let original = app.appearance
        defer { app.appearance = original }
        var log: [String] = []
        try CodexBarLocalizationOverride.$appLanguage.withValue("en") {
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                app.appearance = NSAppearance(named: appearance)
                let payload = V2ProofTests.sharePayload()

                // Preview: the real window controller's content, as the user sees it before copying.
                let controller = ShareStatsWindowController(payload: payload)
                let window = try #require(controller.window)
                window.appearance = nil
                window.orderFrontRegardless()
                window.layoutIfNeeded()
                RunLoop.current.run(until: Date().addingTimeInterval(0.6))
                let content = try #require(window.contentView?.superview ?? window.contentView)
                let rep = try #require(content.bitmapImageRepForCachingDisplay(in: content.bounds))
                content.cacheDisplay(in: content.bounds, to: rep)
                let preview = try #require(rep.representation(using: .png, properties: [:]))
                try preview.write(to: dir.appendingPathComponent("share-window-preview-\(name).png"))
                window.close()

                // Copy Image: the exporter's own path into a private pasteboard, read back as PNG.
                let pasteboard = NSPasteboard(name: NSPasteboard.Name("codexbar-v2-proof-\(UUID().uuidString)"))
                defer { pasteboard.releaseGlobally() }
                #expect(ShareStatsExporter.copyImage(payload, pasteboard: pasteboard))
                let copied = try #require(pasteboard.data(forType: .png))
                try copied.write(to: dir.appendingPathComponent("share-copied-image-\(name).png"))

                let bitmap = try #require(NSBitmapImageRep(data: copied))
                let corner = try #require(bitmap.colorAt(x: 4, y: 4)?.usingColorSpace(.sRGB))
                log.append(String(
                    format: "%@: app=%@ copied=%dx%d corner=(%.3f, %.3f, %.3f)",
                    name, appearance.rawValue, bitmap.pixelsWide, bitmap.pixelsHigh,
                    corner.redComponent, corner.greenComponent, corner.blueComponent))
                if name == "light" {
                    #expect(corner.redComponent > 0.95 && corner.blueComponent > 0.95)
                } else {
                    #expect(corner.redComponent < 0.15 && abs(corner.redComponent - corner.blueComponent) < 0.01)
                }
            }
        }
        try (log.joined(separator: "\n") + "\n").write(
            to: dir.appendingPathComponent("share-export-proof.txt"), atomically: true, encoding: .utf8)
    }
}
