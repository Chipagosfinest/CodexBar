import Foundation
import Testing
@testable import CodexBarCore

/// Opt-in host-local acceptance benchmark; not intended as a cross-host CI deadline.
struct GrokTurnParsingPerformanceTests {
    @Test
    func `large local usage scans stay within ten cached timestamp parsing passes`() throws {
        let root = try #require(ProcessInfo.processInfo.environment["CODEXBAR_GROK_PARSER_BENCH_DIR"])
        let home = URL(fileURLWithPath: root, isDirectory: true)
        let session = home.appendingPathComponent("sessions/project/session")
        try FileManager.default.createDirectory(at: session, withIntermediateDirectories: true)
        let timestamp = "2026-11-05T12:34:56.123176+00:00"
        let count = 10_000
        let now = try #require(CostUsageScanner.dateFromTimestamp(timestamp))
        let records: [[String: Any]] = (0..<count).map { index in
            ["turnNumber": index, "endedAt": timestamp, "totalTokens": 7, "primaryModelId": "grok-fixture"]
        }
        let file = session.appendingPathComponent("usage.json")
        try JSONSerialization.data(withJSONObject: ["turns": records]).write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.modificationDate: now], ofItemAtPath: file.path)
        let clock = ContinuousClock()
        var parsed = 0
        let reference = clock.measure {
            for _ in 0..<count {
                if CostUsageScanner.dateFromTimestamp(timestamp) != nil { parsed += 1 }
            }
        }
        #expect(parsed == count)
        let start = clock.now
        let summary = GrokLocalSessionScanner.summarize(env: ["GROK_HOME": home.path], lookbackDays: 7, now: now)
        let scan = start.duration(to: clock.now)
        #expect(summary.totalTokens == count * 7)
        #expect(summary.sessionCount == 1)
        print("Grok parser benchmark turns=\(count) reference=\(reference) scan=\(scan)")
        #expect(scan < reference * 10, "A local scan exceeded ten cached timestamp passes: reference=\(reference), scan=\(scan)")
    }
}
