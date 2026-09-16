import Foundation
import Testing
@testable import CodexBar
@testable import CodexBarCore

struct ShareStatsRouteTests {
    @Test
    func `accepts the canonical data free overview route`() {
        #expect(ShareStatsRoute.parse(ShareStatsRoute.overviewURL) == .overview)
    }

    @Test(arguments: [
        "codexbar://share-stats",
        "codexbar://share-stats?version=2",
        "codexbar://share-stats?version=1&provider=codex",
        "codexbar://share-stats?version=1&version=1",
        "codexbar://share-stats?version=%31",
        "codexbar://share-stats?version=1#preview",
        "codexbar://share-stats/path?version=1",
        "codexbar://share-stats%2Fpath?version=1",
        "codexbar://user@share-stats?version=1",
        "codexbar://user%3Asecret@share-stats?version=1",
        "codexbar://share-stats:443?version=1",
        "https://share-stats?version=1",
        "codexbar://other?version=1",
    ])
    func `rejects routes that carry an unsupported destination or data`(raw: String) throws {
        let url = try #require(URL(string: raw))
        #expect(ShareStatsRoute.parse(url) == nil)
    }

    @Test
    func `retains a cold launch route until the app can present it`() {
        var handoff = ShareStatsRouteHandoff()
        handoff.enqueue(.overview)
        handoff.enqueue(.overview)

        #expect(!handoff.deliverIfPossible { _ in false })
        #expect(handoff.pendingRoute == .overview)

        var delivered: [ShareStatsRoute] = []
        #expect(handoff.deliverIfPossible {
            delivered.append($0)
            return true
        })
        #expect(delivered == [.overview])
        #expect(handoff.pendingRoute == nil)
    }
}
