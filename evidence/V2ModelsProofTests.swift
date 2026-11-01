import AppKit
import CodexBarCore
import SwiftUI
import Testing
@testable import CodexBar

@MainActor
struct V2ModelsProofTests {
    @Test
    func `render usage and spend models lens`() throws {
        guard ProcessInfo.processInfo.environment["CODEXBAR_REDESIGN_PROOF_DIR"] != nil else { return }
        try CodexBarLocalizationOverride.$appLanguage.withValue("en") {
            for (name, unpriced, partial) in [
                ("usage-spend-models", false, false),
                ("usage-spend-models-unpriced", true, false),
                ("usage-spend-models-partial", false, true),
            ] {
                let section = SpendDashboardCurrencySection(
                    group: V2ProofTests.dashboardGroup(unpricedModel: unpriced, partialModels: partial),
                    requestedDays: 30,
                    initialDetailSection: .models)
                    .padding(20)
                    .frame(width: 640)
                try V2ProofTests().write(name, section, scale: 1)
            }
        }
    }
}
