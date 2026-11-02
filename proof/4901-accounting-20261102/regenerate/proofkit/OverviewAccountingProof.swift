import AppKit
import CodexBarCore
import SwiftUI

@MainActor
enum OverviewAccountingProof {
    static func runIfRequested() -> Bool {
        guard let output = ProcessInfo.processInfo.environment["OVERVIEW_ACCOUNTING_PROOF"] else { return false }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.appearance = NSAppearance(named: .aqua)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_793_534_400)
        var reports: [[String: Any]] = []
        var charts: [(String, OverviewDailySpend)] = []
        CodexBarLocalizationOverride.$appLanguage.withValue("fr") {
            for scenario in [
                "Inconsistent $2 / models $3 + $1",
                "Unpriced request / known $2",
                "Excluded request / known $2",
                "Reconciled Codex + routing",
            ] {
                let inconsistent = scenario.hasPrefix("Inconsistent")
                let unpriced = scenario.hasPrefix("Unpriced")
                let excluded = scenario.hasPrefix("Excluded")
                let models: [CostUsageDailyReport.ModelBreakdown] = inconsistent ? [
                    .init(modelName: "fixture-max", costUSD: 3, totalTokens: 8),
                    .init(modelName: "fixture-mini", costUSD: 1, totalTokens: 2),
                ] : [
                    .init(modelName: "fixture-max", costUSD: 2, totalTokens: 8),
                    .init(
                        modelName: excluded ? "fixture-excluded" : "fixture-routing",
                        costUSD: nil,
                        totalTokens: excluded ? nil : 2,
                        incompleteRequestCount: excluded ? 2 : nil),
                ]
                let model = SpendDashboardModel.build(
                    inputs: [.init(
                        provider: unpriced || excluded ? .claude : .codex,
                        displayName: unpriced || excluded ? "Claude" : "Codex",
                        snapshot: CostUsageTokenSnapshot(
                            sessionTokens: nil, sessionCostUSD: nil, last30DaysTokens: nil, last30DaysCostUSD: nil,
                            historyDays: 7,
                            daily: [.init(
                                date: "2026-11-01",
                                inputTokens: 5,
                                outputTokens: 5,
                                totalTokens: 10,
                                costUSD: 2,
                                modelsUsed: nil,
                                modelBreakdowns: models,
                                unpricedRequestCount: unpriced || scenario.hasPrefix("Reconciled") ? 1 : nil)],
                            updatedAt: now))],
                    requestedDays: 7,
                    reportingPeriod: .rolling(days: 7),
                    now: now,
                    calendar: calendar,
                    preferredCurrencyCode: "USD")
                let daily = OverviewDailySpend.make(model: model)!
                let point = daily.points.last!
                let segments = daily.stacks[point.id]!
                reports.append([
                    "scenario": scenario,
                    "hover": point.hoverSummary ?? "",
                    "accessibility": point.accessibilityValue,
                    "segments": segments.map { ["tier": $0.tier.rawValue, "cost": $0.cost] as [String: Any] },
                    "modelCosts": model.groups[0].dailySummaries.last!.providers[0].modelCosts.map(\.cost),
                ])
                charts.append((scenario, daily))
            }
        }
        let data = try! JSONSerialization.data(withJSONObject: reports, options: [.prettyPrinted, .sortedKeys])
        try! data.write(to: URL(fileURLWithPath: output).appendingPathComponent("behavior.json"))
        let sha = ProcessInfo.processInfo.environment["PROOF_SHA"] ?? "unknown"
        let recordedReports = reports
        let view = VStack(alignment: .leading, spacing: 18) {
            Text("SYNTHETIC FIXTURES — built CodexBar app — French app / English system").bold()
            Text(sha).font(.system(size: 11, design: .monospaced))
            LazyVGrid(columns: [GridItem(.fixed(430)), GridItem(.fixed(430))], alignment: .leading, spacing: 18) {
                ForEach(Array(charts.enumerated()), id: \.offset) { index, chart in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(chart.0).bold()
                        OverviewStackedSpendChart(daily: chart.1)
                            .environment(\.menuUsageBarSelection, .constant(chart.1.points.last!.id))
                            .frame(width: 330)
                        Text("Production accessibility value: " + chart.1.points.last!.accessibilityValue)
                            .font(.system(size: 12, design: .monospaced))
                        Text("Actual model tiers: " + String(describing: recordedReports[index]["segments"]!))
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
        }.padding(24).frame(width: 920).background(Color(nsColor: .windowBackgroundColor))
        let host = NSHostingView(rootView: view)
        host.frame.size = host.fittingSize
        let window = NSWindow(
            contentRect: host.frame,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false)
        window.title = "CodexBar #4901 — synthetic accounting regression proof"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        Timer.scheduledTimer(withTimeInterval: 15, repeats: false) { _ in
            MainActor.assumeIsolated { NSApplication.shared.terminate(nil) }
        }
        withExtendedLifetime(window) { app.run() }
        return true
    }
}
