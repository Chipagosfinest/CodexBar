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
            for (name, unpriced) in [("usage-spend-models", false), ("usage-spend-models-unpriced", true)] {
                let section = SpendDashboardCurrencySection(
                    group: V2ProofTests.dashboardGroup(unpricedModel: unpriced),
                    requestedDays: 30,
                    initialDetailSection: .models)
                    .padding(20)
                    .frame(width: 640)
                try V2ProofTests().write(name, section, scale: 1)
            }
        }
    }
}
