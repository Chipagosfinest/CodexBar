import Foundation

/// A data-free deep link from a widget into the aggregate usage share preview.
public enum ShareStatsRoute: Sendable, Equatable {
    case overview

    public static let overviewURL = URL(string: "codexbar://share-stats?version=1")!

    public static func parse(_ url: URL) -> Self? {
        guard url.absoluteString == self.overviewURL.absoluteString,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.caseInsensitiveCompare("codexbar") == .orderedSame,
              components.host?.caseInsensitiveCompare("share-stats") == .orderedSame,
              components.port == nil,
              components.user == nil,
              components.password == nil,
              components.path.isEmpty,
              components.fragment == nil,
              components.queryItems == [URLQueryItem(name: "version", value: "1")]
        else { return nil }
        return .overview
    }
}
