import AppKit
import CodexBarCore
import Foundation
import SwiftUI
import Testing
@testable import CodexBar

/// Measurement probe (not a regression): renders a typical six-provider roster through the production
/// Overview row view in both layouts and reports per-row and total heights.
@MainActor
struct CompactOverviewHeightProbeTests {
    private static let width: CGFloat = 340

    @Test
    func `report compact and detailed overview heights for a typical roster`() throws {
        let roster: [(UsageProvider, String, [(String, Double, String, String?)])] = [
            (.claude, "Claude", [
                ("Session", 64, "Resets in 2h 10m", "On pace"),
                ("Weekly", 41, "Resets in 3d", "Ahead of pace by 6%"),
                ("Sonnet", 92, "Resets in 3d", nil),
            ]),
            (.codex, "Codex", [
                ("Session", 18, "Resets in 4h 2m", "On pace"),
                ("Weekly", 57, "Resets in 5d", "Behind pace by 3%"),
            ]),
            (.cursor, "Cursor", [
                ("Plan usage", 73, "Resets Nov 21", nil),
                ("On-demand", 12, "Resets Nov 21", "$6.00 of $50.00"),
            ]),
            (.gemini, "Gemini", [
                ("Pro", 35, "Resets in 18h", nil),
                ("Flash", 8, "Resets in 18h", nil),
            ]),
            (.copilot, "Copilot", [
                ("Premium requests", 66, "Resets Dec 1", "198 of 300"),
            ]),
            (.zai, "z.ai", [
                ("Weekly", 25, "Resets in 2d", nil),
            ]),
        ]
        var report: [[String: Any]] = []
        var totals: [MergedOverviewLayout: CGFloat] = [.compact: 0, .detailed: 0]
        var compactRows: [UsageMenuCardView.Model] = []
        for (provider, name, windows) in roster {
            let model = try Self.model(provider: provider, name: name, windows: windows)
            compactRows.append(model)
            var row: [String: Any] = ["provider": name, "windows": windows.count]
            for layout in [MergedOverviewLayout.compact, .detailed] {
                let height = Self.height(model, layout: layout)
                totals[layout, default: 0] += height
                row[layout.rawValue] = Double(height.rounded())
            }
            report.append(row)
        }
        let summary: [String: Any] = [
            "width": Double(Self.width),
            "rows": report,
            "compactRowsTotal": Double(totals[.compact]!.rounded()),
            "detailedRowsTotal": Double(totals[.detailed]!.rounded()),
        ]
        let json = try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
        print("OVERVIEW_PROBE \(String(decoding: json, as: UTF8.self))")
        if let directory = ProcessInfo.processInfo.environment["CODEXBAR_OVERVIEW_PROBE_DIR"] {
            let base = URL(fileURLWithPath: directory)
            try json.write(to: base.appendingPathComponent("overview-heights.json"))
            for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
                for layout in [MergedOverviewLayout.compact, .detailed] {
                    let stack = VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(compactRows.enumerated()), id: \.offset) { index, model in
                            if index > 0 { Divider() }
                            OverviewMenuCardRowView(model: model, storageText: nil, width: Self.width, layout: layout)
                        }
                    }
                    .frame(width: Self.width)
                    .background(Color(nsColor: .windowBackgroundColor))
                    let host = NSHostingView(rootView: stack)
                    host.appearance = NSAppearance(named: appearance)
                    host.frame = CGRect(origin: .zero, size: host.fittingSize)
                    host.layoutSubtreeIfNeeded()
                    if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                        host.cacheDisplay(in: host.bounds, to: rep)
                        try rep.representation(using: .png, properties: [:])?
                            .write(to: base.appendingPathComponent("overview-\(layout.rawValue)-\(name).png"))
                    }
                }
            }
        }
    }

    private static func height(_ model: UsageMenuCardView.Model, layout: MergedOverviewLayout) -> CGFloat {
        NSHostingController(rootView: OverviewMenuCardRowView(
            model: model, storageText: nil, width: self.width, layout: layout))
            .sizeThatFits(in: CGSize(width: self.width, height: CGFloat.greatestFiniteMagnitude)).height
    }

    private static func model(
        provider: UsageProvider,
        name: String,
        windows: [(String, Double, String, String?)]) throws -> UsageMenuCardView.Model
    {
        try UsageMenuCardView.Model(
            provider: provider,
            providerName: name,
            email: "",
            subtitleText: "Updated just now",
            subtitleStyle: .info,
            planText: "Pro",
            metrics: windows.enumerated().map { index, window in
                .init(
                    id: "w\(index)",
                    title: window.0,
                    percent: window.1,
                    percentStyle: .used,
                    resetText: window.2,
                    detailText: window.3,
                    detailLeftText: nil,
                    detailRightText: nil,
                    pacePercent: nil,
                    paceOnTop: true)
            },
            usageNotes: [],
            providerDetails: [],
            openAIAPIUsage: nil,
            inlineUsageDashboard: nil,
            providerCost: nil,
            tokenUsage: nil,
            placeholder: nil,
            progressColor: .blue)
    }
}
