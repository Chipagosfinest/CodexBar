#if DEBUG
import AppKit
import CodexBarCore
import WidgetKit

/// Evidence-only fixture; never included on the product PR branch.
@MainActor
enum WidgetHostProof {
    static func runIfRequested() -> Bool {
        guard let index = CommandLine.arguments.firstIndex(of: "--widget-host-proof"),
              CommandLine.arguments.indices.contains(index + 1) else { return false }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Delegate(root: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
        return true
    }

    @MainActor
    final class Delegate: NSObject, NSApplicationDelegate {
        let root: URL
        var window: NSWindow!
        var label: NSTextField!
        var timer: Timer?
        var phase = ""
        init(root: URL) { self.root = root }
        func applicationDidFinishLaunching(_ notification: Notification) {
            self.window = NSWindow(
                contentRect: NSRect(x: 20, y: 15, width: 900, height: 65),
                styleMask: [.titled],
                backing: .buffered,
                defer: false)
            self.window.title = "PR 4890 — SYNTHETIC DATA ONLY"
            self.label = NSTextField(labelWithString: "")
            self.label.frame = NSRect(x: 10, y: 5, width: 880, height: 55)
            self.label.maximumNumberOfLines = 3
            self.label.frame.size.width = 650
            self.window.contentView?.addSubview(self.label)
            let button = NSButton(title: "Use incomplete history", target: self, action: #selector(self.incomplete))
            button.frame = NSRect(x: 670, y: 15, width: 210, height: 32)
            self.window.contentView?.addSubview(button)
            self.window.orderFrontRegardless()
            self.tick()
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }

        @objc func incomplete() {
            try! "incomplete".write(to: self.root.appendingPathComponent("phase"), atomically: true, encoding: .utf8)
            self.tick()
        }

        func tick() {
            let next = (try? String(contentsOf: self.root.appendingPathComponent("phase"), encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "complete"
            guard next != self.phase else { return }
            self.phase = next
            let incomplete = next == "incomplete"
            let now = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let days = (0..<14).map { offset in
                CostUsageDailyReport.Entry(
                    date: formatter.string(from: now.addingTimeInterval(Double(offset - 13) * 86400)),
                    inputTokens: nil, outputTokens: nil, totalTokens: 100, costUSD: 10,
                    modelsUsed: ["fixture-alpha", "fixture-beta"],
                    modelBreakdowns: [
                        .init(
                            modelName: "fixture-alpha",
                            costUSD: 8,
                            totalTokens: 80,
                            incompleteRequestCount: incomplete && offset == 13 ? 1 : 0),
                        .init(modelName: "fixture-beta", costUSD: 2, totalTokens: 20),
                    ])
            }
            let history = CostUsageTokenSnapshot(
                sessionTokens: 100,
                sessionCostUSD: 10,
                last30DaysTokens: 1400,
                last30DaysCostUSD: 140,
                daily: days,
                updatedAt: now)
            let shares = UsageStore.widgetTopModels(from: history)
            precondition(incomplete ? shares == nil : shares?.count == 2)
            let entry = WidgetSnapshot.ProviderEntry(
                provider: .claude,
                updatedAt: now,
                primary: RateWindow(
                    usedPercent: 25,
                    windowMinutes: 300,
                    resetsAt: nil,
                    resetDescription: nil),
                secondary: nil,
                tokenUsage: .init(
                    sessionCostUSD: 10,
                    sessionTokens: 100,
                    last30DaysCostUSD: 140,
                    last30DaysTokens: 1400),
                dailyUsage: days.map { .init(
                    dayKey: $0.date,
                    totalTokens: $0.totalTokens,
                    costUSD: $0.costUSD) },
                topModels: shares)
            let snapshot = WidgetSnapshot(entries: [entry], enabledProviders: [.claude], generatedAt: now)
            guard let container = AppGroupSupport.currentContainerURL() else {
                fatalError("Real app group unavailable; fallback is forbidden for this proof")
            }
            WidgetSnapshotStore.save(snapshot)
            WidgetSelectionStore.saveSelectedProvider(.claude)
            let decoded = WidgetSnapshotStore.load()!
            precondition(decoded.entries.first?.topModels?.count == shares?.count)
            WidgetCenter.shared.reloadAllTimelines()
            let sha = Bundle.main.object(forInfoDictionaryKey: "CodexGitCommit") as? String ?? "unknown"
            self.label.stringValue = "SYNTHETIC ONLY | \(next) | product 6f97fb9d7\nfixture build \(sha)\nReal app-group save/load + WidgetKit reload; provider fetching bypassed"
            let report: [String: Any] = [
                "phase": next,
                "productSHA": "6f97fb9d7",
                "fixtureSHA": sha,
                "group": AppGroupSupport.currentGroupID(),
                "containerIsGroupContainer": container.path.contains("Group Containers"),
                "incompleteRequestCount": days.last!.incompleteRequestCount,
                "matchingDayTokens": days.last!.totalTokens!,
                "matchingDayCost": days.last!.costUSD!,
                "decodedModelCount": decoded.entries.first?.topModels?.count ?? 0,
                "dailyPointCount": decoded.entries.first!.dailyUsage.count,
                "models": shares?.map { ["name": $0.modelName, "share": $0.share] } ?? [],
                "reloadAllTimelines": true,
            ]
            try! JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
                .write(to: self.root.appendingPathComponent("\(next)-transport.json"))
        }
    }
}
#endif
