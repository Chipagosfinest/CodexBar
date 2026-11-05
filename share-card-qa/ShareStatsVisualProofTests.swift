import AppKit
import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

/// Research-only exploratory export harness. Product UI and clipboard are never operated.
struct ShareStatsVisualProofTests {
    @Test @MainActor
    func `render representative share payloads for human inspection`() throws {
        let path = try #require(ProcessInfo.processInfo.environment["CODEXBAR_SHARE_VISUAL_PROOF_DIR"])
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let providers: [ShareStatsProviderPayload] = [
            .init(provider: .claude, providerName: "Claude", subscriptionName: "Max", currencyCode: "USD",
                  totalTokens: 900_000_000, estimatedCost: 1234.56, coveredDayCount: 30),
            .init(provider: .codex, providerName: "Codex", subscriptionName: "Pro 20x", currencyCode: "USD",
                  totalTokens: 600_000_000, estimatedCost: 900, coveredDayCount: 30),
        ]
        let models: [ShareStatsModelPayload] = [
            .init(provider: .claude, providerName: "Claude", modelName: "Claude", currencyCode: "USD",
                  totalTokens: 900_000_000, estimatedCost: 1234.56),
            .init(provider: .codex, providerName: "Codex", modelName: "GPT", currencyCode: "USD",
                  totalTokens: 600_000_000, estimatedCost: 900),
        ]
        for scenario in ["priced", "partial", "multi-currency", "unpriced", "no-models", "many-providers", "no-totals"] {
            let currencies: [ShareStatsCurrencyPayload]
            switch scenario {
            case "multi-currency":
                currencies = [.init(currencyCode: "USD", estimatedCost: 1234.56, coveredDayCount: 30),
                              .init(currencyCode: "JPY", estimatedCost: 198765432, coveredDayCount: 12),
                              .init(currencyCode: "GBP", estimatedCost: 200, coveredDayCount: 30)]
            case "unpriced", "no-totals":
                currencies = [.init(currencyCode: "USD", estimatedCost: nil, coveredDayCount: 30)]
            default:
                currencies = [.init(currencyCode: "USD", estimatedCost: 2134.56, coveredDayCount: 30,
                                    isPartial: scenario == "partial")]
            }
            let payload = ShareStatsPayload(
                days: 30, periodEnd: Date(timeIntervalSince1970: 1_793_318_400),
                providers: scenario == "many-providers" ? Array(repeating: providers, count: 6).flatMap { $0 } : providers,
                topModels: ["no-models", "no-totals"].contains(scenario) ? [] : models,
                currencies: currencies, totalTokens: scenario == "no-totals" ? nil : 1_500_000_000,
                hasPartialTokens: scenario == "partial", hasPartialModels: scenario == "partial",
                periodEndTimeZone: .gmt)
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                let data = try #require(ShareStatsRenderer.pngData(for: payload, appearance: NSAppearance(named: appearance)))
                try data.write(to: directory.appendingPathComponent("\(scenario)-\(name).png"), options: .atomic)
            }
        }
    }
}
