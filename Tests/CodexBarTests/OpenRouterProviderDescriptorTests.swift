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
        let presentation = OpenRouterProviderDescriptor.descriptor.presentation.costPresentation(snapshot)
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
        let presentation = OpenRouterProviderDescriptor.descriptor.presentation.costPresentation(snapshot)
        #expect(presentation.menuCardStyle == .generic)
    }
}
