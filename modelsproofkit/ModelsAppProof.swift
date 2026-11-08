#if DEBUG
import AppKit
import CodexBarCore
import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
private final class ModelsProofState {
    var selectedDay = 15
    let output: URL
    let product: String
    let label: String

    init(output: URL, product: String, label: String) {
        self.output = output
        self.product = product
        self.label = label
        self.record()
    }

    var group: SpendDashboardModel.CurrencyGroup {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func entry(day: Int, cost: Double, unpriced: Int) -> CostUsageDailyReport.Entry {
            CostUsageDailyReport.Entry(
                date: String(format: "2026-07-%02d", day),
                inputTokens: nil,
                outputTokens: nil,
                totalTokens: 100,
                costUSD: cost,
                modelsUsed: nil,
                modelBreakdowns: [
                    .init(modelName: "fixture-alpha", costUSD: cost / 2, totalTokens: 50),
                    .init(modelName: "fixture-beta", costUSD: cost / 2, totalTokens: 50),
                ],
                unpricedRequestCount: unpriced)
        }
        let now = Date(timeIntervalSince1970: 1_784_179_200)
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: nil,
            last30DaysTokens: 200,
            last30DaysCostUSD: 8,
            historyDays: 2,
            historyCoverageIsEstablished: true,
            daily: [entry(day: 15, cost: 2, unpriced: 1), entry(day: 16, cost: 6, unpriced: 0)],
            updatedAt: now)
        let selected = calendar.date(from: DateComponents(year: 2026, month: 7, day: self.selectedDay))!
        return SpendDashboardModel.build(
            inputs: [.init(provider: .cursor, displayName: "Cursor", snapshot: snapshot)],
            requestedDays: 30,
            now: now,
            calendar: calendar,
            selectedDay: selected).groups[0]
    }

    func select(_ day: Int) {
        self.selectedDay = day
        self.record()
    }

    func record() {
        let group = self.group
        let ranking = SpendModelRanking.make(group)!
        let report: [String: Any] = [
            "synthetic": true,
            "productSHA": self.product,
            "label": self.label,
            "selectedDay": self.selectedDay,
            "knownWindowCost": group.totalCost.map { $0 as Any } ?? NSNull(),
            "windowHasPartialCost": group.hasPartialCost,
            "modelHistoryComplete": group.modelHistoryCompleteness == .complete,
            "rankingPartial": ranking.isPartial,
            "basis": ranking.basis == .cost ? "cost" : "other",
            "rows": ranking.rows.map { row in
                [
                    "model": row.model.modelName,
                    "value": row.value,
                    "share": row.share.map { $0 as Any } ?? NSNull(),
                ] as [String: Any]
            },
        ]
        do {
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: self.output.appendingPathComponent("day-\(self.selectedDay).json"), options: .atomic)
            try data.write(to: self.output.appendingPathComponent("current.json"), options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("Models proof report failure: \(error)\n".utf8))
            exit(3)
        }
    }
}

private struct ModelsProofView: View {
    let state: ModelsProofState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SYNTHETIC BUILT-APP MODELS PROOF — \(self.state.label)")
                    .font(.headline)
                Text("Product SHA: \(self.state.product)")
                    .font(.system(size: 10, design: .monospaced))
                Text("Opt-in entry: normal account discovery and transports bypassed")
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.yellow.opacity(0.18))
            HStack {
                Button("Select partial day (July 15)") { self.state.select(15) }
                    .accessibilityIdentifier("models-proof-select-partial")
                Button("Select complete day (July 16)") { self.state.select(16) }
                    .accessibilityIdentifier("models-proof-select-complete")
                Text("Selected: July \(self.state.selectedDay)").monospacedDigit()
            }
            ScrollView {
                SpendDashboardCurrencySection(
                    group: self.state.group,
                    requestedDays: 30,
                    hidePersonalInfo: true,
                    initialDetailSection: .models,
                    onSelectDay: { date in
                        var calendar = Calendar(identifier: .gregorian)
                        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                        self.state.select(calendar.component(.day, from: date))
                    })
                    .id(self.state.selectedDay)
                    .padding(16)
            }
        }
        .padding(16)
        .frame(width: 920, height: 820)
        .environment(\.locale, Locale(identifier: "en_US"))
    }
}

enum ModelsAppProof {
    @MainActor
    static func runIfRequested() -> Bool {
        let environment = ProcessInfo.processInfo.environment
        guard let outputPath = environment["CODEXBAR_MODELS_APP_PROOF_OUT"] else { return false }
        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        } catch {
            FileHandle.standardError.write(Data("Models proof output unavailable\n".utf8))
            exit(2)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.appearance = NSAppearance(named: .aqua)
        let state = ModelsProofState(
            output: output,
            product: environment["CODEXBAR_MODELS_PRODUCT_SHA"] ?? "missing",
            label: environment["CODEXBAR_MODELS_PROOF_LABEL"] ?? "missing")
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 820),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false)
        window.title = "CodexBar Models — synthetic actual-app proof"
        window.contentView = NSHostingView(rootView: ModelsProofView(state: state))
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        withExtendedLifetime((window, state)) { app.run() }
        return true
    }
}
#endif
