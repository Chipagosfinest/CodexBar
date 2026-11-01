import AppKit
import CodexBarCore
import SwiftUI
import Testing
import WidgetKit
@testable import CodexBar
@testable import CodexBarWidget

@MainActor
extension V2ProofTests {
    // MARK: - Widgets

    static func widgetEntry(provider: UsageProvider = .claude, sonnet: Double = 92) -> WidgetSnapshot.ProviderEntry {
        // Widgets read the real clock for freshness and countdowns, so the fixture must too.
        let live = Date()
        let calendar = Calendar(identifier: .gregorian)
        let daily = (0..<14).map { offset -> WidgetSnapshot.DailyUsagePoint in
            let day = calendar.date(byAdding: .day, value: offset - 13, to: live)!
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(identifier: "UTC")
            let cost = 30 + 25 * sin(Double(offset) / 2.0)
            return .init(dayKey: formatter.string(from: day), totalTokens: Int(cost * 600_000), costUSD: cost)
        }
        return WidgetSnapshot.ProviderEntry(
            provider: provider,
            updatedAt: live.addingTimeInterval(-120),
            primary: RateWindow(
                usedPercent: 34, windowMinutes: 300,
                resetsAt: live.addingTimeInterval(3 * 3600 + 53 * 60), resetDescription: nil),
            secondary: RateWindow(
                usedPercent: 61, windowMinutes: 10080,
                resetsAt: live.addingTimeInterval(3 * 86400 + 20 * 3600), resetDescription: nil),
            tertiary: RateWindow(
                usedPercent: sonnet, windowMinutes: 10080,
                resetsAt: live.addingTimeInterval(3 * 86400 + 20 * 3600), resetDescription: nil),
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: .init(
                sessionCostUSD: 4.21, sessionTokens: 15_200_000,
                last30DaysCostUSD: 1254.24, last30DaysTokens: 812_400_000, updatedAt: live),
            dailyUsage: daily)
    }

    static func tile(_ entry: WidgetSnapshot.ProviderEntry, _ size: WidgetTileSize) -> some View {
        let frame: CGSize = switch size {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        }
        return UsageTile(entry: entry, size: size) {
            TileHeader(provider: entry.provider, updatedAt: entry.updatedAt, size: size)
        }
        .padding(14)
        .frame(width: frame.width, height: frame.height)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

}

@MainActor
struct V2WidgetProofTests {
    @Test
    func `render usage widgets`() throws {
        guard V2ProofTests().outputDirectory != nil else { return }
        try CodexBarLocalizationOverride.$appLanguage.withValue("en") {
            let entry = V2ProofTests.widgetEntry()
            for (size, name) in [(WidgetTileSize.small, "small"), (.medium, "medium"), (.large, "large")] {
                try V2ProofTests().write("widget-usage-\(name)", V2ProofTests.tile(entry, size).padding(12))
            }
            let rows: [(WidgetSnapshot.ProviderEntry, WidgetRenderingMode?)] = [
                (V2ProofTests.widgetEntry(), nil),
                (V2ProofTests.widgetEntry(provider: .gemini, sonnet: 40), nil),
                (V2ProofTests.widgetEntry(provider: .codex, sonnet: 30), nil),
                (V2ProofTests.widgetEntry(), WidgetRenderingMode.accented),
            ]
            let sheet = VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(alignment: .top, spacing: 14) {
                        V2ProofTests.tile(row.0, .small)
                        V2ProofTests.tile(row.0, .medium)
                        V2ProofTests.tile(row.0, .large)
                    }
                    .environment(\.widgetRenderingModeOverride, row.1)
                }
            }
            .padding(16)
            try V2ProofTests().write("widget-sheet", sheet)
        }
    }
}
