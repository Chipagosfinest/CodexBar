#if DEBUG
import AppKit
import CodexBarCore
import Foundation

/// Proof-build-only early startup. This file is never added to the product branch.
@MainActor
enum PackagedMenuProof {
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains("--packaged-chart-proof") else { return false }
        let env = ProcessInfo.processInfo.environment
        // These existing test-safety markers must be present BEFORE SettingsStore static initialization.
        precondition(env["SWIFT_TESTING"] == "1")
        precondition(env["CODEXBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS"] == "1")
        precondition(env["CODEXBAR_TEST_CODEX_FILE_ISOLATION"] == "1")
        precondition(env["CODEXBAR_TEST_SESSION_FILE_ISOLATION"] == "1")
        precondition(env["CODEXBAR_ALLOW_TEST_KEYCHAIN_ACCESS"] != "1")
        precondition(env["CODEXBAR_TEST_CODEX_FILE_FIXTURES"] == nil)
        precondition(SettingsStore.isRunningTests)
        configureUsageFormatterLocalizationProvider()
        guard let outputPath = env["PACKAGED_CHART_PROOF_OUTPUT"],
              let rootPath = env["PACKAGED_CHART_PROOF_ROOT"],
              let productSHA = env["PACKAGED_CHART_PROOF_PRODUCT_SHA"]
        else { preconditionFailure("Proof requires output, disposable root, and product SHA") }
        precondition(productSHA == "c16893bbe515695c74a5c7d594b083ce641c3d20")
        KeychainAccessGate.isDisabled = true
        precondition(URLProtocol.registerClass(PackagedProofRejectHTTP.self))
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let delegate = Delegate(
            output: URL(fileURLWithPath: outputPath, isDirectory: true),
            root: URL(fileURLWithPath: rootPath, isDirectory: true),
            productSHA: productSHA)
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
        return true
    }

    @MainActor
    private final class Delegate: NSObject, NSApplicationDelegate {
        let output: URL
        let root: URL
        let productSHA: String
        var settings: SettingsStore?
        var store: UsageStore?
        var controller: StatusItemController?
        var receiptTimer: Timer?
        var knownDayID = ""
        var expectedReceipt: [String: Any] = [:]
        var forbiddenRefreshes = 0

        init(output: URL, root: URL, productSHA: String) {
            self.output = output
            self.root = root
            self.productSHA = productSHA
        }

        func applicationDidFinishLaunching(_: Notification) {
            do {
                try self.prepare()
            } catch {
                preconditionFailure("Synthetic proof setup failed: \(error)")
            }
        }

        private func prepare() throws {
            try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: self.output, withIntermediateDirectories: true)
            let defaults = PackagedProofDefaults(values: [
                "debugDisableKeychainAccess": true,
                "codexbar.legacySecretsMigrationCompleted": true,
                "providerDetectionCompleted": true,
                AppGroupSupport.migrationVersionKey: AppGroupSupport.migrationVersion,
                "openAIWebAccessEnabled": false,
                "debugFileLoggingEnabled": false,
                "launchAtLogin": false,
            ])
            let configStore = CodexBarConfigStore(fileURL: self.root.appendingPathComponent("config.json"))
            try configStore.save(CodexBarConfig(providers: UsageProvider.allCases.map {
                ProviderConfig(id: $0.instanceID, enabled: $0 == .claude || $0 == .codex)
            }))
            let empty = PackagedProofEmptyCredentials()
            let settings = SettingsStore(
                userDefaults: defaults,
                configStore: configStore,
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
                tokenAccountStore: PackagedProofEmptyAccounts(root: self.root),
                performInitialProviderDetection: false)
            self.settings = settings
            settings.agentSessionsEnabled = false
            settings.agentSessionsRemoteEnabled = false
            settings.providerStorageFootprintsEnabled = false
            settings.statusChecksEnabled = false
            settings.openAIWebAccessEnabled = false
            settings.refreshFrequency = .manual
            settings.costUsageEnabled = true // Display seeded history; startup and all loaders below remain disabled.
            settings.costReportingPeriod = .rolling(days: 2)
            settings.costUsageBucketTimeZoneIdentifier = "UTC"
            settings.hidePersonalInfo = true
            settings.codexLocalSessionCostLedgerEnabled = false
            settings.openCodexUsageLogsEnabled = false
            settings.codexExternalOAuthSourcesAllowed = false
            settings.mergeIcons = true
            settings.mergedMenuLastSelectedWasOverview = true
            let isolatedEnvironment = [
                "HOME": self.root.path,
                "CODEX_HOME": self.root.appendingPathComponent("codex").path,
            ]
            settings._test_codexReconciliationEnvironment = isolatedEnvironment
            let fetcher = UsageFetcher(environment: [:])
            let store = UsageStore(
                fetcher: fetcher,
                browserDetection: BrowserDetection(homeDirectory: self.root.path, cacheTTL: 0),
                costUsageFetcher: CostUsageFetcher(cacheRoot: self.root.appendingPathComponent("cost-cache")),
                settings: settings,
                startupBehavior: .testing,
                environmentBase: [:],
                widgetSnapshotURL: self.root.appendingPathComponent("widget.json"),
                cliUsageCacheURL: self.root.appendingPathComponent("cli-cache.json"),
                widgetTimelineReloader: {})
            self.store = store
            store._test_providerRefreshOverride = { [weak self] _ in
                self?.forbiddenRefreshes += 1
                preconditionFailure("Provider refresh forbidden in packaged synthetic proof")
            }
            store._test_tokenUsageResultLoaderOverride = { _, _, _, _, _, _ in
                preconditionFailure("Cost refresh forbidden in packaged synthetic proof")
            }
            store._test_widgetSnapshotSaveOverride = { _ in }
            let now = Date()
            let calendar = settings.costUsageBucketCalendar
            let today = calendar.startOfDay(for: now)
            let yesterday = try self.require(calendar.date(byAdding: .day, value: -1, to: today))
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyy-MM-dd"
            func day(_ date: Date, cost: Double?) -> CostUsageDailyReport.Entry {
                .init(
                    date: formatter.string(from: date),
                    inputTokens: 5,
                    outputTokens: 5,
                    totalTokens: 10,
                    costUSD: cost,
                    modelsUsed: nil,
                    modelBreakdowns: nil)
            }
            for (provider, costs) in [
                (UsageProvider.claude, [day(yesterday, cost: nil), day(today, cost: 2)]),
                (.codex, [day(yesterday, cost: 0), day(today, cost: 3)]),
            ] {
                store._setSnapshotForTesting(UsageSnapshot(
                    primary: RateWindow(
                        usedPercent: 20,
                        windowMinutes: 300,
                        resetsAt: now.addingTimeInterval(3600),
                        resetDescription: nil),
                    secondary: nil,
                    updatedAt: now), provider: provider)
                store.publishTokenSnapshot(CostUsageTokenSnapshot(
                    sessionTokens: nil,
                    sessionCostUSD: nil,
                    last30DaysTokens: nil,
                    last30DaysCostUSD: nil,
                    historyDays: 2,
                    daily: costs,
                    updatedAt: now), for: provider)
            }
            let controller = StatusItemController(
                store: store,
                settings: settings,
                account: AccountInfo(email: nil, plan: nil),
                updater: DisabledUpdaterController(),
                preferencesSelection: PreferencesSelection(),
                statusBar: .system,
                menuCardRenderingEnabled: true,
                menuRefreshEnabled: false,
                observeProviderConfigNotifications: false)
            self.controller = controller
            let menu = try self.require(controller.mergedMenu)
            controller.populateMenu(menu, provider: nil)
            try self.validateChart(controller: controller, now: now, today: today, formatter: formatter)
            controller.statusItem.button?.setAccessibilityIdentifier("codexbar-packaged-chart-proof")
            precondition(menu.items.contains {
                ($0.representedObject as? String) == "overviewSpendSummary"
            })
            controller.statusItem.button?.toolTip = "SYNTHETIC chart proof — $5 known day, incomplete range"
            try self.writeReceipt()
            self.receiptTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { try? self?.writeReceipt() }
            }
            if let timer = self.receiptTimer { RunLoop.main.add(timer, forMode: .common) }
        }

        private func validateChart(
            controller: StatusItemController, now: Date, today: Date, formatter: DateFormatter) throws
        {
            let model = controller.overviewSpendDashboardModel(providers: [.claude, .codex], now: now)
            let group = try self.require(model.groups.first)
            precondition(group.providers.first { $0.provider == .claude }?.totalCost == nil)
            precondition(group.providers.first { $0.provider == .codex }?.totalCost == 3)
            let daily = try self.require(OverviewDailySpend.make(model: model))
            let pointID = "\(today.timeIntervalSince1970)"
            self.knownDayID = pointID
            precondition(daily.points.first { $0.id == pointID }?.value == 5)
            let segments = try self.require(daily.stacks[pointID])
            precondition(segments.map(\.cost).reduce(0, +) == 5)
            let claude = try self.require(daily.legend.first { $0.provider == .claude })
            let codex = try self.require(daily.legend.first { $0.provider == .codex })
            precondition(daily.share(of: claude, pointID: nil) == nil)
            precondition(daily.share(of: codex, pointID: nil) == nil)
            precondition(abs((daily.share(of: claude, pointID: pointID) ?? -1) - 0.4) < 0.000_001)
            precondition(abs((daily.share(of: codex, pointID: pointID) ?? -1) - 0.6) < 0.000_001)
            self.expectedReceipt = [
                "synthetic": true, "proofOnlyEarlyStartup": true,
                "productSHA": self.productSHA, "ordinaryAppStartup": false,
                "actualStatusItemController": true, "actualMergedMenu": true,
                "knownDay": formatter.string(from: today), "knownDayPointID": pointID,
                "knownDayUSD": 5, "claudeDayUSD": 2, "codexDayUSD": 3,
                "claudeHoveredShare": 0.4, "codexHoveredShare": 0.6,
                "rangeSharesUnknown": true, "providerTransportAllowed": false,
                "menuRefreshDisabled": true, "openMenuCountExpectedZeroBecauseRefreshDisabled": true,
            ]
        }

        private func require<T>(_ value: T?) throws -> T {
            guard let value else { throw CocoaError(.coderValueNotFound) }
            return value
        }

        private func writeReceipt() throws {
            var receipt = self.expectedReceipt
            receipt["forbiddenProviderRefreshes"] = self.forbiddenRefreshes
            receipt["blockedHTTPRequests"] = PackagedProofRejectHTTP.requestCount
            receipt["openMenuCount"] = self.controller?.openMenus.count ?? 0
            receipt["overviewSelected"] = self.settings?.mergedMenuLastSelectedWasOverview ?? false
            receipt["updatedAt"] = ISO8601DateFormatter().string(from: Date())
            try JSONSerialization.data(withJSONObject: receipt, options: [.sortedKeys, .prettyPrinted])
                .write(to: self.output.appendingPathComponent("runtime-receipt.json"), options: .atomic)
        }

        func applicationWillTerminate(_: Notification) {
            self.receiptTimer?.invalidate()
            self.controller?.releaseStatusItemsForTesting()
            self.store?.stopSharedSpendDashboardPublication()
            self.settings?.configFileWatcher?.stop()
            URLProtocol.unregisterClass(PackagedProofRejectHTTP.self)
        }
    }
}

private final class PackagedProofRejectHTTP: URLProtocol {
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

private struct PackagedProofEmptyCredentials: ZaiTokenStoring, SyntheticTokenStoring, CookieHeaderStoring,
    MiniMaxCookieStoring, MiniMaxAPITokenStoring, KimiTokenStoring, CopilotTokenStoring
{
    func loadToken() throws -> String? { nil }
    func storeToken(_: String?) throws {}
    func loadCookieHeader() throws -> String? { nil }
    func storeCookieHeader(_: String?) throws {}
}

private final class PackagedProofEmptyAccounts: ProviderTokenAccountStoring, @unchecked Sendable {
    let root: URL
    init(root: URL) { self.root = root }
    func loadAccounts() throws -> [UsageProvider: ProviderTokenAccountData] { [:] }
    func storeAccounts(_: [UsageProvider: ProviderTokenAccountData]) throws {}
    func ensureFileExists() throws -> URL { self.root.appendingPathComponent("unused-accounts.json") }
}

final class PackagedProofDefaults: UserDefaults, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Any]

    init(values: [String: Any] = [:]) {
        self.values = values
        super.init(suiteName: "PackagedProofDefaults-\(UUID().uuidString)")!
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
