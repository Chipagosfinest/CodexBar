#if DEBUG && canImport(JavaScriptCore)
import AppKit
import CodexBarCore
import CoreGraphics
import Foundation

/// BEGIN PURE FOOTER ORACLE
struct FooterOracleObservation {
    var baselineBoundInOpenMenus = true
    var correctNestedScope = true
    var rootTracked = true
    var sameRootEpoch = true
    var sameMoreEpoch = true
    var bothOriginalMenuWindowsVisible = true
    var deadlineExpired = false
    var ownedCompletionFinished = false
    var postCompletionRebuildObserved = false
    var storeHas42AndNoError = false
    var currentCardReplaced = false
    var currentViewReplaced = false
    var freshFingerprintPresent = false
    var currentViewInOriginalMoreWindow = false
}

enum FooterOracleDecision: Equatable {
    case waiting(String)
    case accepted
    case failed(String)
}

func footerOracleDecision(_ state: FooterOracleObservation) -> FooterOracleDecision {
    guard state.baselineBoundInOpenMenus, state.correctNestedScope else { return .failed("wrong-scope-or-baseline") }
    guard state.rootTracked, state.sameRootEpoch, state.sameMoreEpoch,
          state.bothOriginalMenuWindowsVisible else { return .failed("menu-closed-or-reopened") }
    guard !state.deadlineExpired else { return .failed("replacement-deadline-expired") }
    guard state.ownedCompletionFinished, state.postCompletionRebuildObserved else {
        return .waiting("owned-completion-and-rebuild-pending")
    }
    guard state.storeHas42AndNoError, state.currentCardReplaced, state.currentViewReplaced,
          state.freshFingerprintPresent, state.currentViewInOriginalMoreWindow
    else {
        return .waiting("interim-render-awaiting-complete-fresh-payload")
    }
    return .accepted
}

// END PURE FOOTER ORACLE

/// Proof-only early app startup. Never included in the product branch.
@MainActor
enum PackagedFooterProof {
    private static let productionPatchSHA = "574c1c7468735d813b979c1ff2c83963807df36ebee2a5caa229adf28ab3f961"
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--packaged-footer-proof") else { return false }
        let env = ProcessInfo.processInfo.environment
        precondition(env["SWIFT_TESTING"] == "1")
        precondition(env["CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS"] == "1")
        precondition(env["CODEXBAR_TEST_CODEX_FILE_ISOLATION"] == "1")
        precondition(env["CODEXBAR_TEST_SESSION_FILE_ISOLATION"] == "1")
        precondition(env["CODEXBAR_ALLOW_TEST_KEYCHAIN_ACCESS"] != "1")
        precondition(env["CODEXBAR_TEST_CODEX_FILE_FIXTURES"] == nil)
        precondition(SettingsStore.isRunningTests)
        guard let rootPath = env["PACKAGED_FOOTER_PROOF_ROOT"], rootPath.hasPrefix("/"),
              let outputPath = env["PACKAGED_FOOTER_PROOF_OUTPUT"], outputPath.hasPrefix("/"),
              let nonceText = env["PACKAGED_FOOTER_PROOF_NONCE"], let nonce = UUID(uuidString: nonceText),
              env["PACKAGED_FOOTER_PROOF_PRODUCT_SHA"] == "e8a0cca51036fa8f30362a0710754d812ace34a3",
              env["PACKAGED_FOOTER_PROOF_CANDIDATE_PATCH_SHA"] == Self.productionPatchSHA
        else { preconditionFailure("Require disposable paths, UUID and exact product SHA") }
        KeychainAccessGate.isDisabled = true
        configureUsageFormatterLocalizationProvider()
        precondition(URLProtocol.registerClass(FooterProofRejectHTTP.self))
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = Delegate(
            root: URL(fileURLWithPath: rootPath, isDirectory: true),
            output: URL(fileURLWithPath: outputPath, isDirectory: true),
            nonce: nonce)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
        return true
    }

    @MainActor
    private final class Delegate: NSObject, NSApplicationDelegate {
        let root: URL
        let output: URL
        let nonce: UUID
        var settings: SettingsStore?
        var store: UsageStore?
        var controller: StatusItemController?
        var plugin: UserProviderPlugin?
        var rootMenu: NSMenu?
        var oldCard: NSMenuItem?
        var oldView: NSView?
        var freshFingerprint: String?
        var baselineFingerprint: String?
        var baselineMore: NSMenu?
        var baselineRootWindowID = 0
        var baselineMoreWindowID = 0
        var moreBegins = 0
        var moreEnds = 0
        var moreBeginsAtTrigger = 0
        var moreEndsAtTrigger = 0
        var ownedCompletionFinished = false
        var postCompletionRebuilds = 0
        var observedRebuildScopes: [String] = []
        var lastOracleReason = "not-started"
        var baselineReceipt: [String: Any] = [:]
        var lastOracleObservation: [String: Bool] = [:]
        var timer: Timer?
        var phase = "starting"
        var events: [[String: Any]] = []
        var rootBegins = 0
        var rootEnds = 0
        var beginsAtTrigger = 0
        var endsAtTrigger = 0
        var phaseStarted = Date()
        var forbiddenRefreshes = 0
        var resultInPlace = false
        let transport = FooterProofDenyTransport()

        init(root: URL, output: URL, nonce: UUID) {
            self.root = root
            self.output = output
            self.nonce = nonce
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func applicationDidFinishLaunching(_: Notification) {
            do {
                try self.prepare()
            } catch {
                preconditionFailure("Footer proof setup failed: \(error)")
            }
        }

        private func prepare() throws {
            try FileManager.default.createDirectory(at: self.output, withIntermediateDirectories: true)
            let providers = self.root.appendingPathComponent("providers", isDirectory: true)
            try FileManager.default.createDirectory(at: providers, withIntermediateDirectories: true)
            let source = """
            defineProvider({
              id: "packaged-footer-fixture",
              name: "Synthetic Overflow Meter",
              topLevel: false,
              endpoints: ["https://footer-proof.example.test"],
              settings: [],
              fetchUsage() { return { primary: { usedPercent: 42 } }; },
            });
            """
            try Data(source.utf8).write(to: providers.appendingPathComponent("fixed-fixture.js"), options: .atomic)
            let loader = UserProviderPluginLoader(
                providersDirectory: providers,
                cacheDirectory: self.root.appendingPathComponent("plugin-cache"),
                transport: self.transport)
            let loaded = UserProviderPluginRegistry.refresh(loader: loader)
            precondition(loaded.count == 1)
            let plugin = try self.require(loaded.first?.plugin)
            precondition(plugin.manifest.id.rawValue == "packaged-footer-fixture")
            precondition(!plugin.manifest.topLevel)
            self.plugin = plugin
            let approvals = ProviderPluginApprovalStore(fileURL: self.root.appendingPathComponent("approvals.json"))
            try approvals.record(plugin.approvalBinding(settings: [:]))
            let settings = try self.makeSettings(plugin: plugin)
            self.settings = settings
            let store = UsageStore(
                fetcher: UsageFetcher(environment: [:]),
                browserDetection: BrowserDetection(homeDirectory: self.root.path, cacheTTL: 0),
                settings: settings,
                historicalUsageHistoryStore: HistoricalUsageHistoryStore(
                    fileURL: self.root.appendingPathComponent("historical.json")),
                startupBehavior: .testing,
                environmentBase: [:],
                pluginApprovalStore: approvals,
                widgetSnapshotURL: self.root.appendingPathComponent("widget.json"),
                cliUsageCacheURL: self.root.appendingPathComponent("cli-cache.json"),
                widgetTimelineReloader: {})
            self.store = store
            store._test_providerRefreshOverride = { [weak self] _ in
                self?.forbiddenRefreshes += 1
                preconditionFailure("First-party provider refresh forbidden")
            }
            store._test_tokenUsageResultLoaderOverride = { _, _, _, _, _, _ in
                preconditionFailure("Cost refresh forbidden")
            }
            store._test_widgetSnapshotSaveOverride = { _ in }
            let now = Date()
            for provider in [UsageProvider.claude, .codex] {
                store._setSnapshotForTesting(UsageSnapshot(
                    primary: RateWindow(
                        usedPercent: 40,
                        windowMinutes: 300,
                        resetsAt: now.addingTimeInterval(3600),
                        resetDescription: nil),
                    secondary: nil,
                    updatedAt: now), provider: provider)
            }
            store.snapshots[plugin.manifest.id] = UsageSnapshot(
                primary: RateWindow(usedPercent: 5, windowMinutes: nil, resetsAt: nil, resetDescription: nil),
                secondary: nil,
                updatedAt: now)
            store.errors[plugin.manifest.id] = "Synthetic prior refresh failure"
            // Defer automatic open-menu fetching only. Explicit plugin completion still uses the real guarded
            // scheduler.
            StatusItemController.setMenuOpenRefreshDelayForTesting(.seconds(3600))
            let controller = StatusItemController(
                store: store,
                settings: settings,
                account: AccountInfo(email: nil, plan: nil),
                updater: DisabledUpdaterController(),
                preferencesSelection: PreferencesSelection(),
                statusBar: .system,
                menuCardRenderingEnabled: true,
                menuRefreshEnabled: true,
                observeProviderConfigNotifications: false)
            self.controller = controller
            let menu = try self.require(controller.mergedMenu)
            self.rootMenu = menu
            controller.populateMenu(menu, provider: nil)
            let overflow = try self.require(menu.items.first {
                ($0.representedObject as? String) == "overviewOverflow"
            }?.submenu)
            let card = try self.require(overflow.items.first {
                ($0.representedObject as? String) == "pluginCard:\(plugin.manifest.id.rawValue)"
            })
            _ = try self.require(card.view)
            // Baseline identity is bound only after the native menus are actually open at the nonce trigger.
            precondition(!menu.items
                .contains { ($0.representedObject as? String) == "pluginCard:\(plugin.manifest.id.rawValue)" })
            controller.statusItem.button?.setAccessibilityIdentifier("codexbar-packaged-footer-proof")
            controller.statusItem.button?.toolTip = "SYNTHETIC footer proof — open More before triggering refresh"
            self.observeTracking()
            self.phase = "ready-initial-5-error"
            self.record("ready-initial")
            try self.writeReceipt()
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func makeSettings(plugin: UserProviderPlugin) throws -> SettingsStore {
            let defaults = FooterProofDefaults(values: [
                "debugDisableKeychainAccess": true, "codexbar.legacySecretsMigrationCompleted": true,
                "providerDetectionCompleted": true, "openAIWebAccessEnabled": false,
                "debugFileLoggingEnabled": false, "launchAtLogin": false,
                AppGroupSupport.migrationVersionKey: AppGroupSupport.migrationVersion,
            ])
            let config = CodexBarConfigStore(fileURL: self.root.appendingPathComponent("config.json"))
            try config.save(CodexBarConfig(providers: UsageProvider.allCases.map {
                ProviderConfig(id: $0.instanceID, enabled: $0 == .claude || $0 == .codex)
            }))
            let empty = FooterProofEmptyCredentials()
            let settings = SettingsStore(
                userDefaults: defaults,
                configStore: config,
                zaiTokenStore: empty,
                syntheticTokenStore: empty,
                codexCookieStore: empty,
                claudeCookieStore: empty,
                cursorCookieStore: empty,
                opencodeCookieStore: empty,
                factoryCookieStore: empty,
                minimaxCookieStore: empty,
                minimaxAPITokenStore: empty,
                kimiTokenStore: empty,
                augmentCookieStore: empty,
                ampCookieStore: empty,
                copilotTokenStore: empty,
                tokenAccountStore: FooterProofAccounts(root: self.root),
                performInitialProviderDetection: false)
            settings.agentSessionsEnabled = false
            settings.agentSessionsRemoteEnabled = false
            settings.providerStorageFootprintsEnabled = false
            settings.statusChecksEnabled = false
            settings.openAIWebAccessEnabled = false
            settings.usageBarsShowUsed = true
            settings.costUsageEnabled = false
            settings.refreshFrequency = .manual
            settings.refreshAllProvidersOnMenuOpen = false
            settings.codexLocalSessionCostLedgerEnabled = false
            settings.codexExternalOAuthSourcesAllowed = false
            settings.mergeIcons = true
            settings.mergedMenuLastSelectedWasOverview = true
            settings.mergedOverviewLayout = .compact
            settings.mergedOverviewAllAccounts = true
            settings.multiAccountMenuLayout = .stacked
            settings._test_codexReconciliationEnvironment = ["HOME": self.root.path]
            settings.setPluginEnabled(plugin.manifest.id, enabled: true)
            settings.setProviderOrder([.claude, .codex, plugin.manifest.id])
            for index in 0..<14 {
                settings.addTokenAccount(
                    provider: .claude,
                    label: "Synthetic account \(index)",
                    token: "fixture-\(index)")
            }
            return settings
        }

        private func observeTracking() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.trackingBegan(_:)),
                name: NSMenu.didBeginTrackingNotification,
                object: nil)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(self.trackingEnded(_:)),
                name: NSMenu.didEndTrackingNotification,
                object: nil)
        }

        @objc private func trackingBegan(_ notification: Notification) {
            self.recordTracking(notification, began: true)
        }

        @objc private func trackingEnded(_ notification: Notification) {
            self.recordTracking(notification, began: false)
        }

        private func recordTracking(_ notification: Notification, began: Bool) {
            guard let menu = notification.object as? NSMenu else { return }
            if menu === self.rootMenu {
                if began { self.rootBegins += 1 } else { self.rootEnds += 1 }
                self.record(began ? "root-tracking-began" : "root-tracking-ended")
            } else if menu === self.baselineMore || menu.supermenu === self.rootMenu {
                let currentOverflow = self.rootMenu?.items.first {
                    ($0.representedObject as? String) == "overviewOverflow"
                }?.submenu
                if menu === self.baselineMore || menu === currentOverflow {
                    if began { self.moreBegins += 1 } else { self.moreEnds += 1 }
                }
                self.record(began ? "child-tracking-began" : "child-tracking-ended")
            }
        }

        private func tick() {
            do {
                let trigger = self.output.appendingPathComponent("trigger-refresh.json")
                if self.phase == "ready-initial-5-error", FileManager.default.fileExists(atPath: trigger.path) {
                    let data = try Data(contentsOf: trigger)
                    let command = try self.require(JSONSerialization.jsonObject(with: data) as? [String: String])
                    precondition(command["nonce"] == self.nonce.uuidString)
                    precondition(command["action"] == "refresh-fixed-fixture")
                    try FileManager.default.removeItem(at: trigger)
                    self.beginRefresh(command: command)
                }
                self.checkReplacement()
                try self.writeReceipt()
            } catch { preconditionFailure("Footer proof control failed: \(error)") }
        }

        private func visibleOwnedMenuWindowIDs() -> Set<Int> {
            let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]] ?? []
            return Set(windows.compactMap { window in
                guard (window[kCGWindowOwnerPID as String] as? Int) == Int(ProcessInfo.processInfo.processIdentifier),
                      (window[kCGWindowLayer as String] as? Int) == 101 else { return nil }
                return window[kCGWindowNumber as String] as? Int
            })
        }

        private func failProof(_ reason: String) {
            guard !self.phase.hasPrefix("failed:") else { return }
            self.phase = "failed:" + reason
            self.lastOracleReason = reason
            self.record("oracle-failed:" + reason)
            // Preserve the real menu and diagnostic state for native capture; no assertion abort.
        }

        private func beginRefresh(command: [String: String]) {
            guard let controller, let menu = self.rootMenu, let store, let plugin,
                  let rootID = command["rootWindowID"].flatMap(Int.init),
                  let moreID = command["moreWindowID"].flatMap(Int.init), rootID != moreID,
                  controller.openMenus[ObjectIdentifier(menu)] === menu,
                  self.rootBegins > self.rootEnds,
                  store.snapshots[plugin.manifest.id]?.primary?.usedPercent == 5,
                  store.errors[plugin.manifest.id] == "Synthetic prior refresh failure",
                  let overflow = menu.items.first(where: {
                      ($0.representedObject as? String) == "overviewOverflow"
                  })?.submenu, overflow.supermenu === menu,
                  let card = overflow.items.first(where: {
                      ($0.representedObject as? String) == "pluginCard:\(plugin.manifest.id.rawValue)"
                  }), let view = card.view,
                  let rootWindow = menu.items.compactMap({ $0.view?.window }).first,
                  let moreWindow = view.window,
                  rootWindow.isVisible, moreWindow.isVisible,
                  rootWindow.windowNumber == rootID, moreWindow.windowNumber == moreID,
                  self.visibleOwnedMenuWindowIDs().isSuperset(of: [rootID, moreID])
            else {
                self.failProof("nonce-baseline-not-bound-to-actually-open-owned-menus")
                return
            }
            self.oldCard = card
            self.oldView = view
            self.baselineMore = overflow
            self.baselineRootWindowID = rootID
            self.baselineMoreWindowID = moreID
            self.baselineFingerprint = UserPluginMenuCardView.fingerprint(
                snapshot: store.snapshots[plugin.manifest.id],
                error: store.errors[plugin.manifest.id],
                resetStyle: controller.settings.resetTimeDisplayStyle)
            self.beginsAtTrigger = self.rootBegins
            self.endsAtTrigger = self.rootEnds
            self.moreBeginsAtTrigger = self.moreBegins
            self.moreEndsAtTrigger = self.moreEnds
            self.baselineReceipt = [
                "rootWindowID": rootID, "moreWindowID": moreID,
                "rootMenuIdentity": String(describing: ObjectIdentifier(menu)),
                "moreMenuIdentity": String(describing: ObjectIdentifier(overflow)),
                "cardIdentity": String(describing: ObjectIdentifier(card)),
                "viewIdentity": String(describing: ObjectIdentifier(view)),
                "fingerprint": self.baselineFingerprint ?? "",
                "rootBegins": self.rootBegins, "rootEnds": self.rootEnds,
                "moreBegins": self.moreBegins, "moreEnds": self.moreEnds,
            ]
            self.phase = "refreshing-fixed-plugin"
            self.phaseStarted = Date()
            // Same real guarded rebuild observer seam and completion ordering used by the production regression.
            controller._test_openMenuRebuildObserver = { [weak self, weak menu] rebuilt in
                guard let self, let menu else { return }
                let scope: String
                if rebuilt === menu {
                    scope = "root"
                } else if rebuilt === self.baselineMore, rebuilt.supermenu === menu {
                    scope = "baseline-more"
                } else {
                    return
                }
                if self.ownedCompletionFinished {
                    self.postCompletionRebuilds += 1
                    self.observedRebuildScopes.append(scope)
                }
                self.record("production-" + scope + "-rebuild-observed")
            }
            self.record("baseline-bound-in-actually-open-menus")
            self.record("explicit-plugin-refresh-started")
            Task { @MainActor in
                await store.refreshUserPlugin(plugin.manifest.id)
                guard !self.phase.hasPrefix("failed:") else { return }
                self.freshFingerprint = UserPluginMenuCardView.fingerprint(
                    snapshot: store.snapshots[plugin.manifest.id],
                    error: store.errors[plugin.manifest.id],
                    resetStyle: controller.settings.resetTimeDisplayStyle)
                self.ownedCompletionFinished = true
                self.phase = "awaiting-guarded-rebuild"
                controller.refreshOpenMenusAfterUserPluginRefresh(plugin.manifest.id)
                self.record("explicit-plugin-refresh-completed")
            }
        }

        private func checkReplacement() {
            guard self.phase == "refreshing-fixed-plugin" || self.phase == "awaiting-guarded-rebuild",
                  let controller, let menu = self.rootMenu, let plugin, let store,
                  let oldCard = self.oldCard, let oldView = self.oldView
            else { return }
            let overflow = menu.items.first { ($0.representedObject as? String) == "overviewOverflow" }?.submenu
            let card = overflow?.items
                .first { ($0.representedObject as? String) == "pluginCard:\(plugin.manifest.id.rawValue)" }
            let view = card?.view
            let fingerprintPresent = self.freshFingerprint.map { fingerprint in
                controller.menuCardHeightCache.keys.contains {
                    $0.id == "pluginCard:\(plugin.manifest.id.rawValue)" && $0.fingerprint == fingerprint
                }
            } ?? false
            let windows = self.visibleOwnedMenuWindowIDs()
            let observation = FooterOracleObservation(
                baselineBoundInOpenMenus: !self.baselineReceipt.isEmpty,
                // Temporary absence is an interim render; a present card under a wrong parent fails.
                // Missing card/view still cannot satisfy replacement or original-window attachment.
                correctNestedScope: (overflow.map { $0.supermenu === menu } ?? true) &&
                    (card.map { $0.menu === overflow } ?? true),
                rootTracked: controller.openMenus[ObjectIdentifier(menu)] === menu,
                sameRootEpoch: self.rootBegins == self.beginsAtTrigger && self.rootEnds == self.endsAtTrigger,
                sameMoreEpoch: self.moreBegins == self.moreBeginsAtTrigger && self.moreEnds == self.moreEndsAtTrigger,
                bothOriginalMenuWindowsVisible: windows.isSuperset(of: [
                    self.baselineRootWindowID,
                    self.baselineMoreWindowID,
                ]),
                deadlineExpired: Date().timeIntervalSince(self.phaseStarted) >= 15,
                ownedCompletionFinished: self.ownedCompletionFinished,
                postCompletionRebuildObserved: self.postCompletionRebuilds > 0,
                storeHas42AndNoError: store.snapshots[plugin.manifest.id]?.primary?.usedPercent == 42 &&
                    store.errors[plugin.manifest.id] == nil,
                currentCardReplaced: card.map { $0 !== oldCard } ?? false,
                currentViewReplaced: view.map { $0 !== oldView } ?? false,
                freshFingerprintPresent: fingerprintPresent,
                currentViewInOriginalMoreWindow: view?.window?.windowNumber == self.baselineMoreWindowID)
            self.lastOracleObservation = [
                "baselineBoundInOpenMenus": observation.baselineBoundInOpenMenus,
                "correctNestedScope": observation.correctNestedScope,
                "sameRootEpoch": observation.sameRootEpoch,
                "sameMoreEpoch": observation.sameMoreEpoch,
                "deadlineExpired": observation.deadlineExpired,
                "ownedCompletionFinished": observation.ownedCompletionFinished,
                "postCompletionRebuildObserved": observation.postCompletionRebuildObserved,
                "storeHas42AndNoError": observation.storeHas42AndNoError,
                "currentCardReplaced": observation.currentCardReplaced,
                "currentViewReplaced": observation.currentViewReplaced,
                "freshFingerprintPresent": observation.freshFingerprintPresent,
                "currentViewInOriginalMoreWindow": observation.currentViewInOriginalMoreWindow,
                "rootTracked": observation.rootTracked,
                "bothOriginalMenuWindowsVisible": observation.bothOriginalMenuWindowsVisible,
            ]
            switch footerOracleDecision(observation) {
            case let .waiting(reason):
                if self.lastOracleReason != reason {
                    self.lastOracleReason = reason
                    self.record("oracle-waiting:" + reason)
                }
            case .accepted:
                self.resultInPlace = true
                self.phase = "replaced-in-open-root-native-capture-required"
                self.lastOracleReason = "accepted-after-owned-completion-and-rebuild"
                self.record("captured-card-and-view-replaced")
            case let .failed(reason):
                self.failProof(reason)
            }
        }

        private func record(_ event: String) {
            self.events.append([
                "event": event,
                "at": ISO8601DateFormatter().string(from: Date()),
                "rootBegins": self.rootBegins,
                "rootEnds": self.rootEnds,
                "moreBegins": self.moreBegins,
                "moreEnds": self.moreEnds,
                "postCompletionRebuilds": self.postCompletionRebuilds,
            ])
        }

        private func writeReceipt() throws {
            let receipt: [String: Any] = [
                "synthetic": true, "proofOnlyEarlyStartup": true, "ordinaryAppStartup": false,
                "productSHA": "e8a0cca51036fa8f30362a0710754d812ace34a3",
                "productionCandidatePatchSHA256": "574c1c7468735d813b979c1ff2c83963807df36ebee2a5caa229adf28ab3f961",
                "productionCandidateSourceSHA256": "9792aa446f3edd603aa0445ee1c5085b765707a6c62281d5e224086073759524",
                "nonce": self.nonce.uuidString,
                "phase": self.phase, "events": self.events, "rootBegins": self.rootBegins, "rootEnds": self.rootEnds,
                "moreBegins": self.moreBegins, "moreEnds": self.moreEnds,
                "initialUsedPercent": 5, "successfulUsedPercent": 42,
                "initialError": "Synthetic prior refresh failure", "finalErrorExpectedNil": true,
                "cardAndViewReplacedInOpenRoot": self.resultInPlace,
                "forbiddenFirstPartyRefreshes": self.forbiddenRefreshes,
                "pluginTransportRequests": self.transport.requestCount,
                "blockedHTTPRequests": FooterProofRejectHTTP.requestCount,
                "nativeCaptureRequired": true,
                "baselineActuallyOpen": self.baselineReceipt,
                "freshFingerprint": self.freshFingerprint ?? "not-yet-completed",
                "ownedCompletionFinished": self.ownedCompletionFinished,
                "postCompletionRebuilds": self.postCompletionRebuilds,
                "observedRebuildScopes": self.observedRebuildScopes,
                "lastOracleReason": self.lastOracleReason,
                "lastOracleObservation": self.lastOracleObservation,
            ]
            try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys, .prettyPrinted])
                .write(to: self.output.appendingPathComponent("runtime-receipt.json"), options: .atomic)
        }

        private func require<T>(_ value: T?) throws -> T {
            guard let value else { throw CocoaError(.coderValueNotFound) }
            return value
        }

        func applicationWillTerminate(_: Notification) {
            self.timer?.invalidate()
            self.settings?.configFileWatcher?.stop()
            self.store?.stopSharedSpendDashboardPublication()
            self.controller?._test_openMenuRebuildObserver = nil
            self.controller?.releaseStatusItemsForTesting()
            StatusItemController.resetMenuOpenRefreshDelayForTesting()
            URLProtocol.unregisterClass(FooterProofRejectHTTP.self)
        }
    }
}

private final class FooterProofDenyTransport: ProviderHTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var requestCount: Int {
        self.lock.withLock { self.count }
    }

    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        self.lock.withLock { self.count += 1 }
        throw URLError(.notConnectedToInternet)
    }
}

private final class FooterProofRejectHTTP: URLProtocol {
    private static let lock = NSLock()
    private nonisolated(unsafe) static var count = 0
    static var requestCount: Int {
        self.lock.withLock { self.count }
    }

    override static func canInit(with request: URLRequest) -> Bool {
        ["http", "https"].contains(request.url?.scheme ?? "")
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.withLock { Self.count += 1 }
        self.client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}

private struct FooterProofEmptyCredentials: ZaiTokenStoring, SyntheticTokenStoring, CookieHeaderStoring,
    MiniMaxCookieStoring, MiniMaxAPITokenStoring, KimiTokenStoring, CopilotTokenStoring
{
    func loadToken() throws -> String? { nil }
    func storeToken(_: String?) throws {}
    func loadCookieHeader() throws -> String? { nil }
    func storeCookieHeader(_: String?) throws {}
}

private final class FooterProofAccounts: ProviderTokenAccountStoring, @unchecked Sendable {
    let root: URL
    private let lock = NSLock()
    private var accounts: [UsageProvider: ProviderTokenAccountData] = [:]
    init(root: URL) { self.root = root }
    func loadAccounts() throws -> [UsageProvider: ProviderTokenAccountData] {
        self.lock.withLock { self.accounts }
    }

    func storeAccounts(_ accounts: [UsageProvider: ProviderTokenAccountData]) throws {
        self.lock.withLock { self.accounts = accounts }
    }

    func ensureFileExists() throws -> URL { self.root.appendingPathComponent("unused-accounts.json") }
}

final class FooterProofDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any]

    init(values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "FooterProofDefaults-\(UUID().uuidString)")!
    }

    override func object(forKey defaultName: String) -> Any? {
        self.lock.withLock { self.values[defaultName] }
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        self.lock.withLock { self.values[defaultName] = value }
    }

    override func removeObject(forKey defaultName: String) {
        self.set(nil as Any?, forKey: defaultName)
    }

    override func bool(forKey defaultName: String) -> Bool {
        (self.object(forKey: defaultName) as? NSNumber)?.boolValue ?? false
    }

    override func integer(forKey defaultName: String) -> Int {
        (self.object(forKey: defaultName) as? NSNumber)?.intValue ?? 0
    }

    override func float(forKey defaultName: String) -> Float {
        (self.object(forKey: defaultName) as? NSNumber)?.floatValue ?? 0
    }

    override func double(forKey defaultName: String) -> Double {
        (self.object(forKey: defaultName) as? NSNumber)?.doubleValue ?? 0
    }

    override func string(forKey defaultName: String) -> String? {
        self.object(forKey: defaultName) as? String
    }

    override func array(forKey defaultName: String) -> [Any]? {
        self.object(forKey: defaultName) as? [Any]
    }

    override func dictionary(forKey defaultName: String) -> [String: Any]? {
        self.object(forKey: defaultName) as? [String: Any]
    }

    override func data(forKey defaultName: String) -> Data? {
        self.object(forKey: defaultName) as? Data
    }

    override func stringArray(forKey defaultName: String) -> [String]? {
        self.object(forKey: defaultName) as? [String]
    }

    override func url(forKey defaultName: String) -> URL? {
        self.object(forKey: defaultName) as? URL
    }

    override func set(_ value: Bool, forKey defaultName: String) {
        self.set(value as Any, forKey: defaultName)
    }

    override func set(_ value: Int, forKey defaultName: String) {
        self.set(value as Any, forKey: defaultName)
    }

    override func set(_ value: Float, forKey defaultName: String) {
        self.set(value as Any, forKey: defaultName)
    }

    override func set(_ value: Double, forKey defaultName: String) {
        self.set(value as Any, forKey: defaultName)
    }

    override func set(_ url: URL?, forKey defaultName: String) {
        self.set(url as Any?, forKey: defaultName)
    }

    override func dictionaryRepresentation() -> [String: Any] {
        self.lock.withLock { self.values }
    }
}

#endif
