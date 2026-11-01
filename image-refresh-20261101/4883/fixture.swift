#if DEBUG
import AppKit
import CodexBarCore
import Observation
import SwiftUI

// Local-only fixture. Enters before normal settings, accounts, watchdogs, or transports.
@MainActor
enum RealBehaviorProof {
    static let startedAt = Date()
    static var resetAt = startedAt.addingTimeInterval(66)

    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--real-behavior-proof") else { return false }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        let delegate = Delegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
        return true
    }

    @Observable @MainActor final class State {
        var model: UsageMenuCardView.Model
        init() { self.model = RealBehaviorProof.model("healthy") }
    }
    struct Card: View {
        let state: State
        let monitor: MenuCardRefreshMonitor
        let fallback: UsageMenuCardView.Model
        var body: some View {
            UsageMenuCardView(model: fallback, width: 310)
                .environment(\.menuCardRefreshMonitor, self.monitor)
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                .environment(\.colorScheme, .light)
        }
    }
    @MainActor private final class Delegate: NSObject, NSApplicationDelegate {
        let state = State()
        lazy var monitor = MenuCardRefreshMonitor(
            resolveModel: { [state] _ in state.model },
            isProviderRefreshActive: { _ in false })
        var item: NSStatusItem?
        var timer: Timer?
        var window: NSWindow?
        var menu: NSMenu?
        var phase = ""
        var lastTick = -1
        var menuIsOpen = false
        var host: NSHostingView<Card>?
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CODEXBAR_REAL_PROOF_DIR"]!)
        func applicationDidFinishLaunching(_ notification: Notification) {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            self.item = item
            item.button?.title = "CB Proof"
            item.button?.setAccessibilityIdentifier("codexbar-real-behavior-proof")
            let menu = NSMenu(title: "CodexBar synthetic proof")
            menu.appearance = NSAppearance(named: .aqua)
            let label = ProcessInfo.processInfo.environment["CODEXBAR_REAL_PROOF_LABEL"] ?? "Synthetic fixture"
            menu.addItem(NSMenuItem(title: "SYNTHETIC • \(label)", action: nil, keyEquivalent: ""))
            menu.addItem(.separator())
            let hosting = NSHostingView(rootView: Card(state: state, monitor: self.monitor, fallback: state.model))
            hosting.appearance = NSAppearance(named: .aqua)
            hosting.frame = NSRect(x: 0, y: 0, width: 310, height: hosting.fittingSize.height)
            self.host = hosting
            let card = MenuCardMenuItem()
            card.view = hosting
            menu.addItem(card)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "Quit synthetic proof", action: #selector(self.quit), keyEquivalent: "")
            quit.target = self
            menu.addItem(quit)
            item.menu = menu
            self.menu = menu
            let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 820, height: 560),
                styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "CodexBar Synthetic Proof — \(label)"
            window.isReleasedWhenClosed = false
            let banner = NSTextField(labelWithString: "Synthetic data only • No accounts or transports")
            banner.frame = NSRect(x: 20, y: 520, width: 780, height: 22)
            window.contentView?.addSubview(banner)
            let button = NSButton(title: "Open native usage menu", target: self, action: #selector(self.openMenu(_:)))
            button.frame = NSRect(x: 90, y: 45, width: 260, height: 36)
            window.contentView?.addSubview(button)
            self.window = window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.update() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
            self.update()
        }
        func update() {
            let open = root.appendingPathComponent("open")
            if FileManager.default.fileExists(atPath: open.path), !menuIsOpen {
                try? FileManager.default.removeItem(at: open)
                menuIsOpen = true
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    self.menu?.popUp(positioning: nil, at: NSPoint(x: 20, y: 520), in: self.window?.contentView)
                    self.menuIsOpen = false
                }
            }
            let next = (try? String(contentsOf: root.appendingPathComponent("phase"), encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "healthy"
            let tick = Int(Date().timeIntervalSince(RealBehaviorProof.startedAt))
            guard next != phase || (next.hasPrefix("tick") && tick != lastTick) else { return }
            lastTick = tick
            if next == "refreshing", phase != "refreshing" {
                self.monitor.beginManualRefresh(frozenModels: [.claude: state.model], provider: .claude)
            }
            if next.hasPrefix("tick"), !phase.hasPrefix("tick") {
                RealBehaviorProof.resetAt = Date().addingTimeInterval(66)
            }
            let wasRefreshing = phase == "refreshing"
            phase = next
            state.model = RealBehaviorProof.model(next)
            if wasRefreshing && next != "refreshing" { self.monitor.endManualRefresh(for: .claude) }
            if next == "failed" {
                assert(state.model.metrics.first?.percent == 89)
            }
            if let host {
                host.layoutSubtreeIfNeeded()
                host.frame.size = NSSize(width: 310, height: host.fittingSize.height)
            }
            let resolved = self.monitor.model(for: .claude, fallback: RealBehaviorProof.model("healthy"))
            let reset = resolved.metrics.first?.resetText ?? "none"
            let monitoring = self.monitor.isManualRefreshInFlight(for: .claude)
            let receipt = "manual=\(monitoring) resolved=\(resolved.metrics.first?.percent ?? -1) reset=\(reset) phase=\(next) primary=\(state.model.metrics.first?.percent ?? -1) subtitle=\(state.model.subtitleText)\n"
            try? receipt.write(to: root.appendingPathComponent("receipt.txt"), atomically: true, encoding: .utf8)
            FileHandle.standardOutput.write(Data(receipt.utf8))
        }
        @objc func openMenu(_ sender: NSButton) {
            self.menu?.popUp(positioning: nil, at: NSPoint(x: 20, y: 520), in: sender.window?.contentView)
        }
        @objc func quit() { NSApp.terminate(nil) }
    }
    static func model(_ phase: String) -> UsageMenuCardView.Model {
        let now = Date()
        let low = phase == "critical"
        let ticks = phase == "tick11" || phase == "tick88"
        let high = phase == "tick88"
        let value = ticks ? (high ? 88.0 : 11.0) : (low ? 90.0 : 89.0)
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: value, windowMinutes: 300,
                resetsAt: ticks ? Self.resetAt : Self.startedAt.addingTimeInterval(3 * 3600 + 11 * 60), resetDescription: nil),
            secondary: RateWindow(usedPercent: ticks ? (high ? 88 : 11) : 40, windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(3 * 86400 + 20 * 3600), resetDescription: nil),
            tertiary: RateWindow(usedPercent: ticks ? (high ? 88 : 11) : 20, windowMinutes: 10080,
                resetsAt: now.addingTimeInterval(3 * 86400 + 20 * 3600), resetDescription: nil),
            providerCost: ProviderCostSnapshot(used: high ? 888.88 : 111.11, limit: 2000,
                currencyCode: "USD", period: "Monthly", updatedAt: Self.startedAt),
            updatedAt: Self.startedAt,
            identity: ProviderIdentitySnapshot(providerID: .claude, accountEmail: nil,
                accountOrganization: nil, loginMethod: "Max"))
        let tokens = CostUsageTokenSnapshot(sessionTokens: high ? 88800 : 11100,
            sessionCostUSD: high ? 8.88 : 1.11, last30DaysTokens: high ? 888_000_000 : 111_000_000,
            last30DaysCostUSD: high ? 888.88 : 111.11,
            costProvenance: .listPriceEstimate, daily: [], updatedAt: Self.startedAt)
        return UsageMenuCardView.Model.make(.init(
            provider: .claude, metadata: ProviderDefaults.metadata[.claude]!, snapshot: snapshot,
            credits: nil, creditsError: nil, dashboardError: nil, tokenSnapshot: tokens,
            tokenError: nil, account: AccountInfo(email: nil, plan: nil),
            isRefreshing: phase == "refreshing", lastError: phase == "failed" ? "Synthetic refresh failed. Retaining last usage." : nil,
            usageBarsShowUsed: true, resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: true, costSummaryInlineEnabled: false, tokenCostMenuSectionEnabled: true,
            showOptionalCreditsAndExtraUsage: true, hidePersonalInfo: true, usesLiveSubtitle: true,
            preferredCurrencyCode: "USD", now: now))
    }
}
#endif
