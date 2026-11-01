import AppKit
import CodexBarCore
import SwiftUI
import Testing
import WidgetKit
@testable import CodexBarWidget

/// Local-only render of the #4887 review fixes. Synthetic data, no accounts, no Keychain.
@MainActor
struct ReviewFixWidgetRenderTests {
    static func entry(sonnetUsed: Double?) -> WidgetSnapshot.ProviderEntry {
        let live = Date()
        return WidgetSnapshot.ProviderEntry(
            provider: .claude,
            updatedAt: live.addingTimeInterval(-120),
            primary: RateWindow(usedPercent: 34, windowMinutes: 300,
                                resetsAt: live.addingTimeInterval(3 * 3600 + 53 * 60), resetDescription: nil),
            secondary: RateWindow(usedPercent: 61, windowMinutes: 10080,
                                  resetsAt: live.addingTimeInterval(3 * 86400 + 20 * 3600), resetDescription: nil),
            tertiary: sonnetUsed.map {
                RateWindow(usedPercent: $0, windowMinutes: 10080,
                           resetsAt: live.addingTimeInterval(3 * 86400 + 20 * 3600), resetDescription: nil)
            },
            creditsRemaining: nil,
            codeReviewRemainingPercent: nil,
            tokenUsage: .init(
                sessionCostUSD: 4.21, sessionTokens: 15_200_000,
                last30DaysCostUSD: 1254.24, last30DaysTokens: 812_400_000, updatedAt: live),
            dailyUsage: [])
    }

    static func tile(_ entry: WidgetSnapshot.ProviderEntry, _ size: WidgetTileSize) -> some View {
        let frame: CGSize = switch size {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        }
        return UsageTile(entry: entry, size: size) {
            TileHeader(provider: entry.provider, updatedAt: entry.updatedAt, size: size)
        }
        .padding(14)
        .frame(width: frame.width, height: frame.height)
        .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
        RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        else { return nil }
        rep.size = size
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return rep.representation(using: .png, properties: [:])
    }

    @Test
    func `render review fix widgets`() throws {
        guard let out = ProcessInfo.processInfo.environment["CODEXBAR_REDESIGN_PROOF_DIR"] else { return }
        let dir = URL(fileURLWithPath: out, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let modes: [(String, WidgetRenderingMode?)] = [("full", nil), ("accented", .accented), ("vibrant", .vibrant)]
        let sheet = VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(modes.enumerated()), id: \.offset) { _, mode in
                HStack(alignment: .top, spacing: 14) {
                    Text(mode.0).font(.caption).frame(width: 60, alignment: .leading)
                    Self.tile(Self.entry(sonnetUsed: 92), .small)
                    Self.tile(Self.entry(sonnetUsed: 92), .medium)
                    Self.tile(Self.entry(sonnetUsed: nil), .medium)
                }
                .environment(\.widgetRenderingModeOverride, mode.1)
            }
        }
        .padding(16)
        for (scheme, appearance) in [(ColorScheme.light, NSAppearance.Name.aqua), (.dark, .darkAqua)] {
            let framed = sheet
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                .environment(\.colorScheme, scheme)
                .background(Color(nsColor: .windowBackgroundColor))
            let data = try #require(Self.png(framed, appearance: appearance))
            try data.write(to: dir.appendingPathComponent("widget-reviewfix-\(scheme == .light ? "light" : "dark").png"))
        }
    }
}
