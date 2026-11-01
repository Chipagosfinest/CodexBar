import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

struct WidgetTopModelsTests {
    private static func input(_ name: String, tokens: Int?, cost: Double?) -> WidgetSnapshot.ModelShareInput {
        WidgetSnapshot.ModelShareInput(modelName: name, totalTokens: tokens, costUSD: cost)
    }

    private static func day(_ date: String, _ models: [(String, Int?, Double?)]) -> CostUsageDailyReport.Entry {
        CostUsageDailyReport.Entry(
            date: date,
            inputTokens: nil,
            outputTokens: nil,
            totalTokens: nil,
            costUSD: nil,
            modelsUsed: models.map(\.0),
            modelBreakdowns: models.map {
                CostUsageDailyReport.ModelBreakdown(modelName: $0.0, costUSD: $0.2, totalTokens: $0.1)
            })
    }

    @Test
    func `fully priced models keep the leading three by spend share of all models`() throws {
        let leading = try #require(WidgetSnapshot.ModelShare.leading([
            Self.input("haiku", tokens: 9000, cost: 5),
            Self.input("opus", tokens: 100, cost: 60),
            Self.input("sonnet", tokens: 500, cost: 30),
            Self.input("legacy", tokens: 10, cost: 5),
        ]))

        #expect(leading.map(\.modelName) == ["opus", "sonnet", "haiku"])
        #expect(leading.map(\.share) == [0.6, 0.3, 0.05])
    }

    @Test
    func `an unpriced model switches the share to tokens`() throws {
        let leading = try #require(WidgetSnapshot.ModelShare.leading([
            Self.input("priced", tokens: 100, cost: 50),
            Self.input("unpriced", tokens: 300, cost: nil),
        ]))

        #expect(leading.map(\.modelName) == ["unpriced", "priced"])
        #expect(leading.map(\.share) == [0.75, 0.25])
    }

    @Test
    func `no comparable metric yields no top models`() {
        #expect(WidgetSnapshot.ModelShare.leading([]) == nil)
        #expect(WidgetSnapshot.ModelShare.leading([
            Self.input("a", tokens: nil, cost: 1),
            Self.input("b", tokens: 1, cost: nil),
        ]) == nil)
        #expect(WidgetSnapshot.ModelShare.leading([Self.input("idle", tokens: 0, cost: 0)]) == nil)
    }

    @Test
    func `history aggregation sums each model across days and stays with its provider`() throws {
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: nil,
            last30DaysTokens: nil,
            last30DaysCostUSD: nil,
            daily: [
                Self.day("2026-10-01", [("opus", 100, 6), ("sonnet", 300, 3)]),
                Self.day("2026-10-02", [("opus", 100, 6), ("haiku", 600, 1)]),
            ],
            updatedAt: Date(timeIntervalSince1970: 1_793_000_000))

        let leading = try #require(UsageStore.widgetTopModels(from: snapshot))

        #expect(leading.map(\.modelName) == ["opus", "sonnet", "haiku"])
        #expect(leading.first?.totalTokens == 200)
        #expect(leading.first?.costUSD == 12)
        #expect(abs((leading.first?.share ?? 0) - 0.75) < 1e-9)
    }

    @Test
    func `a day without a token count makes that model's token total unknown`() throws {
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: nil,
            last30DaysTokens: nil,
            last30DaysCostUSD: nil,
            daily: [
                Self.day("2026-10-01", [("opus", 100, 6)]),
                Self.day("2026-10-02", [("opus", nil, 6)]),
            ],
            updatedAt: Date(timeIntervalSince1970: 1_793_000_000))

        let leading = try #require(UsageStore.widgetTopModels(from: snapshot))
        #expect(leading.first?.totalTokens == nil)
        #expect(leading.first?.costUSD == 12)
    }

    @Test
    func `snapshots written before top models still decode`() throws {
        let entry = WidgetSnapshot.ProviderEntry(
            provider: .claude,
            updatedAt: Date(timeIntervalSince1970: 1_793_000_000),
            primary: nil,
            secondary: nil)
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(entry)) as? [String: Any])
        json.removeValue(forKey: "topModels")
        let decoded = try JSONDecoder().decode(
            WidgetSnapshot.ProviderEntry.self,
            from: JSONSerialization.data(withJSONObject: json))

        #expect(decoded.topModels == nil)
    }
}
