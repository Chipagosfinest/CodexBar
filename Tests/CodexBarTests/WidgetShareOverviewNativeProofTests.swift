import AppKit
import CodexBarCore
import SwiftUI
import WidgetKit
import XCTest
@testable import CodexBarWidget

/// Opt-in, synthetic rendering proof for each production widget that exposes the share route.
@MainActor
final class WidgetShareOverviewNativeProofTests: XCTestCase {
    private struct Canvas {
        let name: String
        let size: CGSize
        let view: AnyView
    }

    func test_shareOverviewWidgetsFitDesktopFamilies() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let directory = environment["CODEXBAR_WIDGET_SHARE_PROOF_DIR"] else {
            throw XCTSkip("Set CODEXBAR_WIDGET_SHARE_PROOF_DIR to render the synthetic widget proof.")
        }
        let output = URL(fileURLWithPath: directory, isDirectory: true)
        guard environment["CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS"] == "1",
              environment[CodexCredentialFileAccess.isolationEnvironmentKey] == "1",
              environment["CODEXBAR_TEST_SESSION_FILE_ISOLATION"] == "1",
              environment["CODEXBAR_ALLOW_TEST_KEYCHAIN_ACCESS"] != "1",
              NSHomeDirectory().hasPrefix(output.deletingLastPathComponent().path + "/")
        else { return XCTFail("Use contained home plus credential and session isolation.") }

        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let snapshot = WidgetPreviewData.snapshot()
        let entry = CodexBarWidgetEntry(date: Date(), provider: .codex, snapshot: snapshot)
        let compactEntry = CodexBarCompactEntry(
            date: Date(),
            provider: .codex,
            metric: .todayCost,
            snapshot: snapshot)
        let switcherEntry = CodexBarSwitcherEntry(
            date: Date(),
            provider: .codex,
            availableProviders: [.codex, .claude],
            snapshot: snapshot)
        let small = CGSize(width: 160, height: 160)
        let medium = CGSize(width: 360, height: 160)
        let large = CGSize(width: 360, height: 380)
        let canvases: [Canvas] = [
            self.canvas("usage-small", small, CodexBarUsageWidgetView(entry: entry), family: .systemSmall),
            self.canvas("usage-medium", medium, CodexBarUsageWidgetView(entry: entry), family: .systemMedium),
            self.canvas("usage-large", large, CodexBarUsageWidgetView(entry: entry), family: .systemLarge),
            self.canvas("compact-small", small, CodexBarCompactWidgetView(entry: compactEntry)),
            self.canvas(
                "switcher-small",
                small,
                CodexBarSwitcherWidgetView(entry: switcherEntry),
                family: .systemSmall),
            self.canvas(
                "switcher-medium",
                medium,
                CodexBarSwitcherWidgetView(entry: switcherEntry),
                family: .systemMedium),
            self.canvas(
                "switcher-large",
                large,
                CodexBarSwitcherWidgetView(entry: switcherEntry),
                family: .systemLarge),
            self.canvas("history-medium", medium, CodexBarHistoryWidgetView(entry: entry), family: .systemMedium),
            self.canvas("history-large", large, CodexBarHistoryWidgetView(entry: entry), family: .systemLarge),
        ]

        for canvas in canvases {
            let hosting = NSHostingView(rootView: canvas.view)
            hosting.appearance = NSAppearance(named: .aqua)
            hosting.frame = NSRect(origin: .zero, size: canvas.size)
            let window = NSWindow(
                contentRect: hosting.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            defer {
                window.contentView = nil
                window.close()
            }

            window.layoutIfNeeded()
            hosting.layoutSubtreeIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            XCTAssertEqual(hosting.bounds.size.width, canvas.size.width, accuracy: 0.5)
            XCTAssertEqual(hosting.bounds.size.height, canvas.size.height, accuracy: 0.5)
            let image = try XCTUnwrap(hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds))
            hosting.cacheDisplay(in: hosting.bounds, to: image)
            try XCTUnwrap(image.representation(using: .png, properties: [:]))
                .write(to: output.appendingPathComponent("share-overview-\(canvas.name).png"))
        }
    }

    private func canvas(
        _ name: String,
        _ size: CGSize,
        _ view: some View,
        family: WidgetFamily? = nil) -> Canvas
    {
        let content = AnyView(
            view
                .environment(\.widgetFamily, family ?? .systemSmall)
                .frame(width: size.width, height: size.height)
                .background(Color(nsColor: .windowBackgroundColor)))
        return Canvas(name: name, size: size, view: content)
    }
}
