#if DEBUG
import CodexBarCore
import Foundation

/// Proof-build-only early CLI entry. No provider fetch/attempt or settings bootstrap is entered.
enum PackagedCooldownProof {
    static func runIfRequested() throws -> Bool {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard arguments.first == "--packaged-cooldown-proof" else { return false }
        precondition(!TestProcessSafety.isRunning, "Use a fresh CLI process without test environment markers")
        guard arguments.count == 5, let nonce = UUID(uuidString: arguments[2]) else {
            throw CocoaError(.coderInvalidValue)
        }
        precondition(arguments[3].hasPrefix("/") && arguments[4].hasPrefix("/"))
        let phase = arguments[1]
        let output = URL(fileURLWithPath: arguments[3], isDirectory: true)
        let profileRoot = URL(fileURLWithPath: arguments[4], isDirectory: true)
            .appendingPathComponent("nonexistent-cooldown-profile-\(nonce.uuidString)", isDirectory: true)
        // Derivation is pure: no profile directory/credential file is created or opened.
        let environment = ["CLAUDE_CONFIG_DIR": profileRoot.path]
        let keys = ClaudeOAuthDelegatedRefreshCoordinator.packagedProofCooldownKeys(environment: environment)
        let defaults = UserDefaults.standard
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let interval: TimeInterval = 300
        let pid = ProcessInfo.processInfo.processIdentifier
        let receiptURL = output.appendingPathComponent("\(phase).json")
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var receipt: [String: Any] = [
            "productSHA": "725fb4fdda831b5cca8bf265d2c066aa8ebc04ca",
            "instrumentedBuiltCLI": true,
            "ordinaryProviderRefresh": false,
            "phase": phase,
            "nonce": nonce.uuidString,
            "pid": pid,
            "profileIdentifier": keys.profile,
            "timestampKey": keys.timestamp,
            "intervalKey": keys.interval,
            "sharedProductionState": true,
            "standardPreferencesFallback": true,
            "testProcessSafetyIsRunning": false,
            "injectedDefaults": false,
            "taskLocalOverrides": false,
            "profilePathDerivedWithoutCredentialReads": true,
        ]
        switch phase {
        case "write":
            guard defaults.object(forKey: keys.timestamp) == nil,
                  defaults.object(forKey: keys.interval) == nil else { throw CocoaError(.fileWriteFileExists) }
            ClaudeOAuthDelegatedRefreshCoordinator.packagedProofRecordCooldown(
                now: now, cooldown: interval, environment: environment)
            precondition(defaults.double(forKey: keys.timestamp) == now.timeIntervalSince1970)
            precondition(defaults.double(forKey: keys.interval) == interval)
            precondition(ClaudeOAuthDelegatedRefreshCoordinator.isInCooldown(now: now, environment: environment))
            precondition(defaults.synchronize())
            receipt["persistedTimestamp"] = defaults.double(forKey: keys.timestamp)
            receipt["persistedInterval"] = defaults.double(forKey: keys.interval)
        case "read":
            let writeData = try Data(contentsOf: output.appendingPathComponent("write.json"))
            guard let previous = try JSONSerialization.jsonObject(with: writeData) as? [String: Any],
                  previous["nonce"] as? String == nonce.uuidString,
                  previous["profileIdentifier"] as? String == keys.profile,
                  let previousPID = previous["pid"] as? NSNumber,
                  previousPID.int32Value != pid else { throw CocoaError(.coderInvalidValue) }
            precondition(defaults.object(forKey: keys.timestamp) as? Double == now.timeIntervalSince1970)
            precondition(defaults.object(forKey: keys.interval) as? Double == interval)
            let current = ClaudeOAuthDelegatedRefreshCoordinator.isInCooldown(
                now: now.addingTimeInterval(1), environment: environment)
            let remaining = ClaudeOAuthDelegatedRefreshCoordinator.cooldownRemainingSeconds(
                now: now.addingTimeInterval(1), environment: environment)
            let expired = ClaudeOAuthDelegatedRefreshCoordinator.isInCooldown(
                now: now.addingTimeInterval(interval), environment: environment)
            precondition(current)
            precondition(remaining == 299)
            precondition(!expired)
            receipt["writerPID"] = previousPID
            receipt["freshProcess"] = true
            receipt["persistedTimestamp"] = defaults.double(forKey: keys.timestamp)
            receipt["persistedInterval"] = defaults.double(forKey: keys.interval)
            receipt["inCooldownAtPlusOne"] = current
            receipt["remainingAtPlusOne"] = remaining
            receipt["inCooldownAtExpiry"] = expired
        case "cleanup":
            // Deliberately do NOT call resetForTesting(): it removes unrelated prefixes.
            defaults.removeObject(forKey: keys.timestamp)
            defaults.removeObject(forKey: keys.interval)
            precondition(defaults.synchronize())
            precondition(defaults.object(forKey: keys.timestamp) == nil)
            precondition(defaults.object(forKey: keys.interval) == nil)
            receipt["removedOnlyNonceKeys"] = [keys.timestamp, keys.interval]
        default:
            throw CocoaError(.coderInvalidValue)
        }
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
            .write(to: receiptURL, options: .atomic)
        return true
    }
}
#endif
