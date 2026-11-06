import CodexBarCore
import Foundation

let mode = CommandLine.arguments[1]
let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let now = Date(timeIntervalSince1970: 1_793_000_000)
let ages: [(String, TimeInterval)] = [("recent", 90), ("expired", 7200), ("future", -3600)]
let persistence = CloudSyncPersistence(fileURL: root.appendingPathComponent("engine-state.json"))

if mode == "create" {
    var snapshots: [String: AccountSnapshotSyncPayload] = [:]
    for (name, age) in ages {
        let usage = UsageSnapshot(
            primary: RateWindow(usedPercent: 20, windowMinutes: 10080, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            extraRateWindows: [NamedRateWindow(
                id: "cursor-grok-bot", title: "Grok Bot",
                window: RateWindow(usedPercent: 80, windowMinutes: 10080, resetsAt: nil, resetDescription: nil))],
            updatedAt: now.addingTimeInterval(-age),
            identity: ProviderIdentitySnapshot(
                providerID: .cursor, accountEmail: "fixture@example.test",
                accountOrganization: nil, loginMethod: "Cursor Pro", accountID: "fixture-account"))
        snapshots[name] = AccountSnapshotSyncPayload(
            provider: .cursor, deviceID: "synthetic-device", accountIdentity: "fixture-account",
            displayLabel: "Synthetic Cursor", usage: usage)
        let entry = CLIUsageCache.Entry(provider: .cursor, usage: usage)!
        try CLIUsageCache.write(CLIUsageCache(entries: [entry]), to: root.appendingPathComponent(name + ".json"))
    }
    try persistence.save(CloudSyncPersistence.Envelope(
        stateSerialization: nil, encodedSystemFields: [:], fleetSnapshots: snapshots))
}

let loaded = persistence.load()
precondition(loaded.fleetSnapshots.count == 3)
var rows: [[String: Any]] = []
for (name, age) in ages {
    let usage = loaded.fleetSnapshots[name]!.usage
    precondition(usage.primary?.usedPercent == 20)
    precondition(usage.extraRateWindows?.first?.window.usedPercent == 80)
    precondition(usage.identity?.accountID == "fixture-account")
    precondition(now.timeIntervalSince(usage.updatedAt) == age)
    let cache = CLIUsageCache.load(from: root.appendingPathComponent(name + ".json"))!
    let hit = cache.hit(for: .cursor, now: now)
    precondition((hit != nil) == (name == "recent"))
    rows.append([
        "case": name, "ageSeconds": age, "primary": usage.primary!.usedPercent,
        "bot": usage.extraRateWindows!.first!.window.usedPercent,
        "syncAccountPreserved": true, "cliCacheHit": hit != nil,
        "inferredSharedWeeklyPool": CursorProviderDescriptor.sharedWeeklyPool(snapshot: usage) != nil,
    ])
}
let result: [String: Any] = [
    "mode": mode, "loadedSyncSnapshots": loaded.fleetSnapshots.count, "cases": rows,
    "boundary": "Actual production Core and App persistence sources; synthetic source harness, not app launch",
]
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
