import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

/// Renders the three payload shapes argued in `docs/research/share-card-layout.md`
/// (sparse / dense / multi) through the production path — `ShareStatsRenderer.pngData`,
/// i.e. the same `NSHostingView` renderer `ShareStatsExporter.saveImage`/`copyImage` use —
/// rather than the standalone `ImageRenderer` harness that doc explicitly disclaims as
/// "not a production-bundle render". Set `CODEXBAR_SHARE_STATS_SCREENSHOT_DIR` to persist
/// the PNGs for review.
struct ShareStatsLayoutProductionRenderTests {
    @MainActor
    @Test
    func `sparse dense and multi payloads render through the production NSHostingView path`() throws {
        let periodEnd = try #require(DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026,
            month: 9,
            day: 16).date)

        let scenarios = [
            ("sparse", Self.sparsePayload(periodEnd: periodEnd)),
            ("dense", Self.densePayload(periodEnd: periodEnd)),
            ("multi", Self.multiCurrencyPayload(periodEnd: periodEnd)),
        ]

        for (name, payload) in scenarios {
            let data = try #require(ShareStatsRenderer.pngData(for: payload))
            // Non-trivial PNG confirms the NSHostingView path actually rasterized content,
            // not a blank/degenerate frame.
            #expect(data.count > 10000)

            if let directory = ProcessInfo.processInfo.environment["CODEXBAR_SHARE_STATS_SCREENSHOT_DIR"] {
                let output = URL(fileURLWithPath: directory, isDirectory: true)
                try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
                try data.write(
                    to: output.appendingPathComponent("share-card-layout-production-\(name).png"),
                    options: .atomic)
            }
        }
    }

    /// 1 subscription, no model history — the case that left dead space above the footer.
    private static func sparsePayload(periodEnd: Date) -> ShareStatsPayload {
        ShareStatsPayload(
            days: 30,
            periodEnd: periodEnd,
            providers: [
                ShareStatsProviderPayload(
                    provider: .claude,
                    providerName: "Claude",
                    subscriptionName: "Max",
                    currencyCode: "USD",
                    totalTokens: 42000,
                    estimatedCost: 12.40,
                    coveredDayCount: 30),
            ],
            topModels: [],
            currencies: [
                ShareStatsCurrencyPayload(
                    currencyCode: "USD",
                    estimatedCost: 12.40,
                    coveredDayCount: 30),
            ],
            totalTokens: 42000)
    }

    /// 5 subscriptions, 3 models, ~$123,456.78 — the tightest vertical and horizontal case.
    private static func densePayload(periodEnd: Date) -> ShareStatsPayload {
        ShareStatsPayload(
            days: 30,
            periodEnd: periodEnd,
            providers: [
                ShareStatsProviderPayload(
                    provider: .claude,
                    providerName: "Claude",
                    subscriptionName: "Max",
                    currencyCode: "USD",
                    totalTokens: 3_100_000,
                    estimatedCost: 45820.11,
                    coveredDayCount: 30),
                ShareStatsProviderPayload(
                    provider: .codex,
                    providerName: "Codex",
                    subscriptionName: nil,
                    currencyCode: "USD",
                    totalTokens: 2_400_000,
                    estimatedCost: 33010.55,
                    coveredDayCount: 30),
                ShareStatsProviderPayload(
                    provider: .cursor,
                    providerName: "Cursor",
                    subscriptionName: "Pro",
                    currencyCode: "USD",
                    totalTokens: 1_900_000,
                    estimatedCost: 22460.90,
                    coveredDayCount: 30),
                ShareStatsProviderPayload(
                    provider: .gemini,
                    providerName: "Gemini",
                    subscriptionName: nil,
                    currencyCode: "USD",
                    totalTokens: 1_100_000,
                    estimatedCost: 14615.12,
                    coveredDayCount: 30),
                ShareStatsProviderPayload(
                    provider: .copilot,
                    providerName: "Copilot",
                    subscriptionName: nil,
                    currencyCode: "USD",
                    totalTokens: 600_000,
                    estimatedCost: 7550.10,
                    coveredDayCount: 30),
            ],
            topModels: [
                ShareStatsModelPayload(
                    provider: .claude,
                    providerName: "Claude",
                    modelName: "claude-opus-5",
                    currencyCode: "USD",
                    totalTokens: 3_100_000,
                    estimatedCost: 45820.11),
                ShareStatsModelPayload(
                    provider: .codex,
                    providerName: "Codex",
                    modelName: "gpt-5.4-codex",
                    currencyCode: "USD",
                    totalTokens: 2_400_000,
                    estimatedCost: 33010.55),
                ShareStatsModelPayload(
                    provider: .cursor,
                    providerName: "Cursor",
                    modelName: "composer-2",
                    currencyCode: "USD",
                    totalTokens: 1_900_000,
                    estimatedCost: 22460.90),
            ],
            currencies: [
                ShareStatsCurrencyPayload(
                    currencyCode: "USD",
                    estimatedCost: 123_456.78,
                    coveredDayCount: 30),
            ],
            totalTokens: 9_100_000)
    }

    /// 3 currencies — exercises the secondary-currency coverage line.
    private static func multiCurrencyPayload(periodEnd: Date) -> ShareStatsPayload {
        ShareStatsPayload(
            days: 30,
            periodEnd: periodEnd,
            providers: [
                ShareStatsProviderPayload(
                    provider: .claude,
                    providerName: "Claude",
                    subscriptionName: "Max",
                    currencyCode: "USD",
                    totalTokens: 900_000,
                    estimatedCost: 120.0,
                    coveredDayCount: 30),
                ShareStatsProviderPayload(
                    provider: .qwencloud,
                    providerName: "Qwen",
                    subscriptionName: nil,
                    currencyCode: "EUR",
                    totalTokens: 400_000,
                    estimatedCost: 45.0,
                    coveredDayCount: 30),
                ShareStatsProviderPayload(
                    provider: .factory,
                    providerName: "Factory",
                    subscriptionName: nil,
                    currencyCode: "GBP",
                    totalTokens: 150_000,
                    estimatedCost: 15.0,
                    coveredDayCount: 30),
            ],
            topModels: [
                ShareStatsModelPayload(
                    provider: .claude,
                    providerName: "Claude",
                    modelName: "claude-sonnet-5",
                    currencyCode: "USD",
                    totalTokens: 900_000,
                    estimatedCost: 120.0),
            ],
            currencies: [
                ShareStatsCurrencyPayload(
                    currencyCode: "USD",
                    estimatedCost: 120.0,
                    coveredDayCount: 30),
                ShareStatsCurrencyPayload(
                    currencyCode: "EUR",
                    estimatedCost: 45.0,
                    coveredDayCount: 30),
                ShareStatsCurrencyPayload(
                    currencyCode: "GBP",
                    estimatedCost: 15.0,
                    coveredDayCount: 30),
            ],
            totalTokens: 1_450_000)
    }
}
