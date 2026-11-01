import AppKit
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
struct InlineUsageDashboardLayoutTests {
    @Test(arguments: AppLanguage.allCases.filter { $0 != .system })
    func `localized statistic headings stay on one line`(language: AppLanguage) {
        CodexBarLocalizationOverride.$appLanguage.withValue(language.rawValue) {
            let title = L("Estimated: %@", L("%@ tokens", L("Current window")))
            let proposal = CGSize(width: 278, height: CGFloat.greatestFiniteMagnitude)
            let shortHeight = NSHostingController(rootView: InlineUsageDashboardContent(model: Self.model(title: "X")))
                .sizeThatFits(in: proposal).height
            let fullHeight = NSHostingController(rootView: InlineUsageDashboardContent(model: Self.model(title: title)))
                .sizeThatFits(in: proposal).height
            #expect(abs(fullHeight - shortHeight) <= 1, "\(language.rawValue): the summary keeps one measured height")
        }
    }

    @Test
    func `render synthetic statistics proof when requested`() throws {
        guard let path = ProcessInfo.processInfo.environment["CODEXBAR_MENU_CARD_PROOF_DIR"] else { return }
        try CodexBarLocalizationOverride.$appLanguage.withValue("en") {
            let title = L("Estimated: %@", L("%@ tokens", L("Current window")))
            let content = VStack(alignment: .leading, spacing: 12) {
                Text("Codex statistics · synthetic").font(.headline)
                InlineUsageDashboardContent(model: Self.model(title: title))
            }
            .padding(14)
            .frame(width: 296)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .light)
            let renderer = ImageRenderer(content: content)
            renderer.scale = 2
            let image = try #require(renderer.cgImage)
            let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: directory.appendingPathComponent("statistics.png"))
        }
    }

    private static func model(title: String) -> InlineUsageDashboardModel {
        InlineUsageDashboardModel(
            accessibilityLabel: "Synthetic statistics",
            valueStyle: .tokens,
            kpis: [
                .init(title: L("Latest tokens"), value: "1K", emphasis: false),
                .init(title: title, value: "2K", emphasis: false),
            ],
            points: [],
            detailLines: [])
    }
}
