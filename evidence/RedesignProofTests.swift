import AppKit
import CodexBarCore
import SwiftUI
import Testing
@testable import CodexBar

/// Local-only proof renderer for the design sweep. Synthetic data, no accounts, no Keychain.
@MainActor
struct RedesignProofTests {
    static let now = Date(timeIntervalSince1970: 1_793_000_000)
    static let width: CGFloat = 310

    var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["CODEXBAR_REDESIGN_PROOF_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    static func claudeModel(
        session: Double, weekly: Double, sonnet: Double,
        lastError: String? = nil, isRefreshing: Bool = false, showsUsed: Bool = true) throws -> UsageMenuCardView.Model
    {
        let snapshot = UsageSnapshot(
            primary: RateWindow(
                usedPercent: session, windowMinutes: 300,
                resetsAt: Self.now.addingTimeInterval(3 * 3600 + 53 * 60), resetDescription: nil),
            secondary: RateWindow(
                usedPercent: weekly, windowMinutes: 10080,
                resetsAt: Self.now.addingTimeInterval(3 * 86400 + 20 * 3600), resetDescription: nil),
            tertiary: RateWindow(
                usedPercent: sonnet, windowMinutes: 10080,
                resetsAt: Self.now.addingTimeInterval(3 * 86400 + 20 * 3600), resetDescription: nil),
            providerCost: ProviderCostSnapshot(
                used: 412.5, limit: 2000, currencyCode: "USD", period: "Monthly", updatedAt: Self.now),
            updatedAt: Self.now,
            identity: ProviderIdentitySnapshot(
                providerID: .claude, accountEmail: "dev@example.com", accountOrganization: nil,
                loginMethod: "Max"))
        let tokens = CostUsageTokenSnapshot(
            sessionTokens: 15200, sessionCostUSD: 4.21,
            last30DaysTokens: 218_000_000, last30DaysCostUSD: 1254.24,
            costProvenance: .listPriceEstimate, daily: [], updatedAt: Self.now)
        return try UsageMenuCardView.Model.make(.init(
            provider: .claude,
            metadata: #require(ProviderDefaults.metadata[.claude]),
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboardError: nil,
            tokenSnapshot: tokens,
            tokenError: nil,
            account: AccountInfo(email: nil, plan: nil),
            isRefreshing: isRefreshing,
            lastError: lastError,
            usageBarsShowUsed: showsUsed,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: true,
            costSummaryInlineEnabled: false,
            tokenCostMenuSectionEnabled: true,
            showOptionalCreditsAndExtraUsage: true,
            hidePersonalInfo: false,
            usesLiveSubtitle: false,
            preferredCurrencyCode: "USD",
            now: Self.now))
    }

    static func png(_ view: some View, appearance: NSAppearance.Name) -> Data? {
        let hosting = NSHostingView(rootView: AnyView(view))
        hosting.appearance = NSAppearance(named: appearance)
        let size = hosting.fittingSize
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = hosting.appearance
        window.contentView = hosting
        defer {
            window.contentView = nil
            window.close()
        }
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return nil }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    func write(_ name: String, _ view: some View) throws {
        guard let dir = self.outputDirectory else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for (appearance, scheme, suffix) in [
            (NSAppearance.Name.aqua, ColorScheme.light, "light"),
            (NSAppearance.Name.darkAqua, ColorScheme.dark, "dark"),
        ] {
            let framed = view
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                .environment(\.colorScheme, scheme)
                .background(Color(nsColor: .windowBackgroundColor))
            let data = try #require(Self.png(framed, appearance: appearance))
            try data.write(to: dir.appendingPathComponent("\(name)-\(suffix).png"))
        }
    }

    @Test
    func `render claude menu card`() throws {
        guard self.outputDirectory != nil else { return }
        try CodexBarLocalizationOverride.$appLanguage.withValue("en") {
            let model = try Self.claudeModel(session: 34, weekly: 61, sonnet: 92)
            try self.write("menu-card-claude", UsageMenuCardView(model: model, width: Self.width))
            let error = try Self.claudeModel(
                session: 34, weekly: 61, sonnet: 92,
                lastError: "Claude Code credentials changed. Click Refresh to retry.")
            try self.write("menu-card-claude-error", UsageMenuCardView(model: error, width: Self.width))
        }
    }

    @Test
    func `render ticking values column`() throws {
        guard self.outputDirectory != nil else { return }
        try CodexBarLocalizationOverride.$appLanguage.withValue("en") {
            let models = try [(11.0, 18.0, 41.0), (48.0, 70.0, 88.0), (100.0, 81.0, 19.0)].map {
                try Self.claudeModel(session: $0.0, weekly: $0.1, sonnet: $0.2)
            }
            let column = HStack(alignment: .top, spacing: 0) {
                ForEach(Array(models.enumerated()), id: \.offset) { _, model in
                    UsageMenuCardView(model: model, width: Self.width)
                }
            }
            try self.write("menu-card-ticking-values", column)
        }
    }
}
