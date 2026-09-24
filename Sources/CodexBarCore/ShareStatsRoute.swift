import Foundation

/// A data-free deep link from a widget into the aggregate usage share preview.
public enum ShareStatsRoute: Sendable, Equatable {
    case overview

    public static let overviewURL = URL(string: "codexbar://share-stats?version=1")!

    /// Accepts only the exact URL the widget emits, so extra query items, fragments,
    /// or future versions are ignored rather than partially honored.
    public static func parse(_ url: URL) -> Self? {
        url.absoluteString == self.overviewURL.absoluteString ? .overview : nil
    }
}
