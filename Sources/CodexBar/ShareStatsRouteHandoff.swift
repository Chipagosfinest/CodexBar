import CodexBarCore

struct ShareStatsRouteHandoff: Equatable {
    private(set) var pendingRoute: ShareStatsRoute?

    mutating func enqueue(_ route: ShareStatsRoute) {
        self.pendingRoute = route
    }

    @discardableResult
    mutating func deliverIfPossible(_ deliver: (ShareStatsRoute) -> Bool) -> Bool {
        guard let route = self.pendingRoute, deliver(route) else { return false }
        self.pendingRoute = nil
        return true
    }
}
