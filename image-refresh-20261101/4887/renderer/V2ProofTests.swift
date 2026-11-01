import AppKit
import CodexBarCore
import SwiftUI
import WidgetKit
import Testing
@testable import CodexBar
@testable import CodexBarWidget

/// Local-only proof renderer for the v2 design sweep. Synthetic data, no accounts, no Keychain.
@MainActor
struct V2ProofTests {
    static let now = Date(timeIntervalSince1970: 1_793_000_000)

    var outputDirectory: URL? {
        ProcessInfo.processInfo.environment["CODEXBAR_REDESIGN_PROOF_DIR"].map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    static func png(_ view: some View, appearance: NSAppearance.Name, scale: CGFloat = 2) -> Data? {
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
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        let pixels = NSSize(width: size.width * scale, height: size.height * scale)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(pixels.width), pixelsHigh: Int(pixels.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    func write(_ name: String, _ view: some View, schemes: [ColorScheme] = [.light, .dark], scale: CGFloat = 2) throws {
        guard let dir = self.outputDirectory else { return }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for scheme in schemes {
            let appearance: NSAppearance.Name = scheme == .light ? .aqua : .darkAqua
            let framed = VStack(alignment: .leading, spacing: 8) {
                Text("SYNTHETIC FIXTURE · PR #4887 · " + String(ProcessInfo.processInfo.environment["PR_IMAGE_HEAD", default: ""].prefix(10)))
                    .font(.system(size: 11, design: .monospaced)).padding(8)
                view
            }
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                .environment(\.colorScheme, scheme)
                .background(Color(nsColor: .windowBackgroundColor))
            let data = try #require(Self.png(framed, appearance: appearance, scale: scale))
            try data.write(to: dir.appendingPathComponent("\(name)-\(scheme == .light ? "light" : "dark").png"))
        }
    }

    // MARK: - Share card

    static func sharePayload(models: Int = 4) -> ShareStatsPayload {
        let providers = [
            ShareStatsProviderPayload(
                provider: .claude, providerName: "Claude", subscriptionName: "Max",
                currencyCode: "USD", totalTokens: 812_400_000, estimatedCost: 1254.24, coveredDayCount: 30),
            ShareStatsProviderPayload(
                provider: .codex, providerName: "Codex", subscriptionName: "Pro",
                currencyCode: "USD", totalTokens: 386_000_000, estimatedCost: 431.80, coveredDayCount: 30),
            ShareStatsProviderPayload(
                provider: .cursor, providerName: "Cursor", subscriptionName: "Cursor Pro",
                currencyCode: "USD", totalTokens: 41_200_000, estimatedCost: 38.10, coveredDayCount: 22),
        ]
        let allModels = [
            ShareStatsModelPayload(
                provider: .claude, providerName: "Claude", modelName: "Claude",
                currencyCode: "USD", totalTokens: 812_400_000, estimatedCost: 1254.24),
            ShareStatsModelPayload(
                provider: .codex, providerName: "Codex", modelName: "GPT",
                currencyCode: "USD", totalTokens: 352_000_000, estimatedCost: 402.10),
            ShareStatsModelPayload(
                provider: .cursor, providerName: "Cursor", modelName: "Gemini",
                currencyCode: "USD", totalTokens: 41_200_000, estimatedCost: 38.10),
            ShareStatsModelPayload(
                provider: .codex, providerName: "Codex", modelName: "o3",
                currencyCode: "USD", totalTokens: 34_000_000, estimatedCost: 29.70),
        ]
        return ShareStatsPayload(
            days: 30,
            periodEnd: Self.now,
            providers: providers,
            topModels: Array(allModels.prefix(models)),
            currencies: [ShareStatsCurrencyPayload(currencyCode: "USD", estimatedCost: 1724.14, coveredDayCount: 30)],
            totalTokens: 1_239_600_000,
            periodEndTimeZone: TimeZone(identifier: "America/New_York")!)
    }

    @Test
    func `render share card`() throws {
        guard self.outputDirectory != nil else { return }
        try CodexBarLocalizationOverride.$appLanguage.withValue("en") {
            try self.write("share-card", ShareStatsCardView(payload: Self.sharePayload()), scale: 1)
            try self.write(
                "share-card-sparse", ShareStatsCardView(payload: Self.sharePayload(models: 1)),
                scale: 1)
            let base = Self.sharePayload()
            let partial = ShareStatsPayload(
                days: 30, periodEnd: base.periodEnd, providers: base.providers, topModels: base.topModels,
                currencies: [ShareStatsCurrencyPayload(
                    currencyCode: "USD", estimatedCost: 1724.14, coveredDayCount: 22, isPartial: true)],
                totalTokens: base.totalTokens, hasPartialTokens: true, hasPartialModels: true,
                periodEndTimeZone: base.periodEndTimeZone)
            try self.write("share-card-partial", ShareStatsCardView(payload: partial), scale: 1)
            let manyProviders = base.providers + [UsageProvider.gemini, .copilot, .openrouter].map {
                ShareStatsProviderPayload(
                    provider: $0, providerName: ProviderDefaults.metadata[$0]?.displayName ?? "Provider",
                    subscriptionName: nil, currencyCode: "USD", totalTokens: 1_000_000, estimatedCost: 1,
                    coveredDayCount: 30)
            }
            let multi = ShareStatsPayload(
                days: 7, periodEnd: base.periodEnd, providers: manyProviders, topModels: base.topModels,
                currencies: [
                    ShareStatsCurrencyPayload(currencyCode: "USD", estimatedCost: 1724.14, coveredDayCount: 7),
                    ShareStatsCurrencyPayload(currencyCode: "GBP", estimatedCost: 12, coveredDayCount: 3),
                    ShareStatsCurrencyPayload(currencyCode: "EUR", estimatedCost: nil, coveredDayCount: 0),
                ],
                totalTokens: base.totalTokens, periodEndTimeZone: base.periodEndTimeZone)
            try self.write("share-card-multicurrency", ShareStatsCardView(payload: multi), scale: 1)
            let empty = ShareStatsPayload(
                days: 30, periodEnd: base.periodEnd, providers: base.providers, topModels: [],
                currencies: base.currencies, totalTokens: base.totalTokens, hasPartialModels: true,
                periodEndTimeZone: base.periodEndTimeZone)
            try self.write("share-card-no-models", ShareStatsCardView(payload: empty), scale: 1)
        }
    }

    // MARK: - Usage & Spend

    static func dashboardGroup(unpricedModel: Bool = false, partialModels: Bool = false) -> SpendDashboardModel.CurrencyGroup {
        let calendar = Calendar(identifier: .gregorian)
        let end = calendar.startOfDay(for: Self.now)
        let start = calendar.date(byAdding: .day, value: -29, to: end)!
        let providers = [
            SpendDashboardModel.ProviderRow(
                id: "claude", rank: 1, provider: .claude, displayName: "Claude",
                totalTokens: 812_400_000, totalCost: 1254.24, coveredDayCount: 30),
            SpendDashboardModel.ProviderRow(
                id: "codex", rank: 2, provider: .codex, displayName: "Codex",
                totalTokens: 386_000_000, totalCost: 431.80, coveredDayCount: 30),
            SpendDashboardModel.ProviderRow(
                id: "cursor", rank: 3, provider: .cursor, displayName: "Cursor",
                totalTokens: 41_200_000, totalCost: 38.10, coveredDayCount: 22),
        ]
        let modelSpecs: [(UsageProvider, String, String, Int, Double)] = [
            (.claude, "Claude", "claude-opus-4-1", 402_000_000, 811.40),
            (.claude, "Claude", "claude-sonnet-4-5", 371_000_000, 402.30),
            (.codex, "Codex", "gpt-5-codex", 301_000_000, 344.90),
            (.codex, "Codex", "gpt-5", 51_000_000, 57.20),
            (.claude, "Claude", "claude-haiku-4-5", 39_400_000, 40.54),
            (.cursor, "Cursor", "gemini-2.5-pro", 28_200_000, 26.40),
            (.codex, "Codex", "o3", 34_000_000, 29.70),
            (.cursor, "Cursor", "cursor-small", 13_000_000, 11.70),
        ]
        let models = modelSpecs.sorted { $0.4 > $1.4 }.enumerated().map { index, spec in
            SpendDashboardModel.ModelRow(
                rank: index + 1, provider: spec.0, providerName: spec.1, modelName: spec.2,
                totalTokens: spec.3, totalCost: unpricedModel && spec.2 == "cursor-small" ? nil : spec.4)
        }
        var points: [SpendDashboardModel.DailyPoint] = []
        for offset in 0..<30 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let wave = 0.6 + 0.4 * sin(Double(offset) / 3.0)
            var stack = 0.0
            for (id, provider, name, base) in [
                ("claude", UsageProvider.claude, "Claude", 41.0),
                ("codex", UsageProvider.codex, "Codex", 14.0),
                ("cursor", UsageProvider.cursor, "Cursor", 1.3),
            ] {
                let cost = base * wave
                points.append(.init(
                    sourceID: id, provider: provider, providerName: name, day: day,
                    cost: cost, stackStart: stack, stackEnd: stack + cost))
                stack += cost
            }
        }
        return SpendDashboardModel.CurrencyGroup(
            currencyCode: "USD",
            providers: providers,
            models: models,
            dailyPoints: points,
            totalTokens: 1_239_600_000,
            totalCost: 1724.14,
            coveredDayCount: 30,
            chartDomain: start...calendar.date(byAdding: .day, value: 1, to: end)!,
            modelHistoryCompleteness: partialModels ? .incomplete : .complete,
            incompleteModelProviders: partialModels ? [.cursor] : [],
            provenance: .listPriceEstimate,
            timeZone: TimeZone(identifier: "America/New_York")!)
    }

    @Test
    func `render usage and spend section`() throws {
        guard self.outputDirectory != nil else { return }
        try CodexBarLocalizationOverride.$appLanguage.withValue("en") {
            let section = SpendDashboardCurrencySection(group: Self.dashboardGroup(), requestedDays: 30)
                .padding(20)
                .frame(width: 640)
            try self.write("usage-spend", section, scale: 1)
        }
    }

}
