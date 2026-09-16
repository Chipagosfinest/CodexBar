import CodexBarCore

struct ShareStatsRouteHandoff: Equatable {
    private(set) var pendingRoute: ShareStatsRoute?

    mutating func enqueue(_ route: ShareStatsRoute) {
        // There is one idempotent destination; retain it across cold launch and coalesce repeats.
        self.pendingRoute = route
    }

    @discardableResult
    mutating func deliverIfPossible(_ deliver: (ShareStatsRoute) -> Bool) -> Bool {
        guard let route = self.pendingRoute, deliver(route) else { return false }
        self.pendingRoute = nil
        return true
    }
}
