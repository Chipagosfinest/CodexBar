import Foundation
import Testing
@testable import CodexBarCore

struct OpenRouterProviderDescriptorTests {
    @Test
    func `usage dashboard opens Activity rather than credit settings`() {
        #expect(OpenRouterProviderDescriptor.descriptor.metadata.dashboardURL == "https://openrouter.ai/activity")
    }

    @Test
    func `costPresenter uses payAsYouGoSpend when no limit is configured`() {
        let snapshot = UsageSnapshot(
            primary: nil,
            secondary: nil,
            tertiary: nil,
            providerCost: ProviderCostSnapshot(
                used: 5.25,
                limit: 0,
                currencyCode: "USD",
                period: "This month",
                balance: 24.75,
                updatedAt: Date()),
            updatedAt: Date())
        let presentation = OpenRouterProviderDescriptor.descriptor.presentation.cost(snapshot: snapshot)
        #expect(presentation.menuCardStyle == .payAsYouGoSpend)
    }

    @Test
    func `costPresenter uses generic when key limit is configured`() {
        let snapshot = UsageSnapshot(
            primary: nil,
            secondary: nil,
            tertiary: nil,
            providerCost: ProviderCostSnapshot(
                used: 5.25,
                limit: 50.0,
                currencyCode: "USD",
                period: "This month",
                balance: 24.75,
                updatedAt: Date()),
            updatedAt: Date())
        let presentation = OpenRouterProviderDescriptor.descriptor.presentation.cost(snapshot: snapshot)
        #expect(presentation.menuCardStyle == .generic)
    }

    @Test(arguments: BundledPluginTestSupport.engines)
    func `plugin omits cost snapshot when capped key has unknown usage`(engine: ProviderPluginEngineKind) async throws {
        // When /key returns only a limit without usage, limit_remaining, or reset window,
        // quotaUsed is unknown and no fake $0.00 spend is emitted.
        let snapshot = try await OpenRouterLimitTestSupport.snapshot(
            engine: engine,
            keyBody: #"{"data":{"limit":30}}"#)
        #expect(snapshot.primary == nil)
        #expect(snapshot.providerCost == nil)
    }

    @Test(arguments: BundledPluginTestSupport.engines)
    func `plugin labels non-resetting capped spend as cumulative usage`(engine: ProviderPluginEngineKind) async throws {
        // When a capped key has cumulative usage and no recognized reset window,
        // period is explicitly "Total usage" instead of nil (which would default to "This month").
        let snapshot = try await OpenRouterLimitTestSupport.snapshot(
            engine: engine,
            keyBody: #"{"data":{"limit":20,"usage":5}}"#)
        let cost = try #require(snapshot.providerCost)
        #expect(cost.limit == 20)
        #expect(cost.used == 5)
        #expect(cost.period == "Total usage")
        #expect(cost.balance == 1.90)
    }

    @Test(arguments: BundledPluginTestSupport.engines)
    func `plugin leaves prepaid balance unavailable when credits request fails`(
        engine: ProviderPluginEngineKind) async throws
    {
        // When /credits fails (e.g. HTTP 403), balance remains nil rather than falling back
        // to remaining key quota ($15), which is a spending cap rather than prepaid credit.
        let snapshot = try await OpenRouterLimitTestSupport.snapshot(
            engine: engine,
            keyBody: #"{"data":{"limit":20,"usage":5}}"#,
            creditsStatus: 403)
        let cost = try #require(snapshot.providerCost)
        #expect(cost.limit == 20)
        #expect(cost.used == 5)
        #expect(cost.period == "Total usage")
        #expect(cost.balance == nil)
    }

    @Test(arguments: BundledPluginTestSupport.engines)
    func `plugin projects uncapped pay-as-you-go spend and credits balance`(
        engine: ProviderPluginEngineKind) async throws
    {
        let snapshot = try await OpenRouterLimitTestSupport.snapshot(
            engine: engine,
            keyBody: #"{"data":{"usage_monthly":12.50}}"#)
        let cost = try #require(snapshot.providerCost)
        #expect(cost.limit == 0)
        #expect(cost.used == 12.50)
        #expect(cost.period == "This month")
        #expect(cost.balance == 1.90)
        let presentation = OpenRouterProviderDescriptor.descriptor.presentation.cost(snapshot: snapshot)
        #expect(presentation.menuCardStyle == .payAsYouGoSpend)
    }
}
