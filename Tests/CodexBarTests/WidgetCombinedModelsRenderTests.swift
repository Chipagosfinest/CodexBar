import AppKit
import CodexBarCore
import SwiftUI
import Testing
import Vision
@testable import CodexBarWidget

@MainActor
struct WidgetCombinedModelsRenderTests {
    @Test(arguments: [ColorScheme.light, .dark], [false, true])
    func `large tile preserves its quota headline and model breakdown together`(
        scheme: ColorScheme,
        dense: Bool) throws
    {
        try WidgetLocalizationOverride.$language.withValue("en") {
            let now = Date()
            let primary = RateWindow(usedPercent: 61, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
            let entry = WidgetSnapshot.ProviderEntry(
                provider: .claude,
                updatedAt: now,
                primary: primary,
                secondary: nil,
                usageRows: dense ? [
                    .init(id: "primary", title: "Session", percentLeft: 39, window: primary),
                    .init(id: "secondary", title: "Weekly", percentLeft: 70),
                    .init(id: "claude-weekly-scoped-sonnet", title: "Sonnet quota", percentLeft: 8),
                ] : nil,
                tokenUsage: dense ? .init(
                    sessionCostUSD: 1.5,
                    sessionTokens: 1200,
                    last30DaysCostUSD: 30,
                    last30DaysTokens: 24000,
                    sessionLabel: "Today",
                    updatedAt: now) : nil,
                topModels: [
                    .init(modelName: "Sonnet", share: 0.6, totalTokens: 600, costUSD: 6),
                    .init(modelName: "Haiku", share: 0.4, totalTokens: 400, costUSD: 4),
                ])
            let view = UsageTile(entry: entry, size: .large) {
                TileHeader(provider: entry.provider, updatedAt: entry.updatedAt, size: .large)
            }
            .environment(\.locale, Locale(identifier: "en"))
            .environment(\.colorScheme, scheme)
            .frame(width: 301, height: 317)
            .padding(14)
            .background(scheme == .dark ? Color(white: 0.12) : Color(white: 0.96))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3
            let image = try #require(renderer.cgImage)
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            try VNImageRequestHandler(cgImage: image).perform([request])
            let text = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: " ").replacingOccurrences(of: " ", with: "")
            #expect(text.contains("39%"), "Quota headline missing: \(text)")
            #expect(text.contains("Sonnet") && text.contains("Haiku"), "Model rows missing: \(text)")
            #expect(text.contains("60%") && text.contains("40%"), "Model shares missing: \(text)")
            if dense {
                #expect(text.contains("70%") && text.contains("8%"), "Secondary quotas clipped: \(text)")
            }

            if let path = ProcessInfo.processInfo.environment["CODEXBAR_WIDGET_COMBINED_PROOF_DIR"] {
                let directory = URL(fileURLWithPath: path, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let bitmap = NSBitmapImageRep(cgImage: image)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                let appearance = scheme == .dark ? "dark" : "light"
                let name = "combined-large-\(dense ? "dense" : "sparse")-\(appearance).png"
                try png.write(to: directory.appendingPathComponent(name), options: .atomic)
            }
        }
    }
}
