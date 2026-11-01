import Foundation

/// How much compute a model spends per request, read from its public model id.
///
/// Size words win over effort words, so `o4-mini-high` is fast: the model class sets the cost, the
/// effort suffix only tunes it. Ids with neither (Sonnet, `gpt-5`, `gpt-5-codex`) are standard.
/// Reasoning effort recorded per turn is not part of the cost history these rows come from, so a
/// GPT row reads as high only when its id says so (`-high`, `-max`, `-pro`).
public enum ModelEffortTier: String, CaseIterable, Sendable, Codable, Comparable {
    case high
    case standard
    case fast

    private static let fastWords: Set<String> = [
        "haiku", "mini", "nano", "flash", "lite", "small", "fast", "low", "minimal", "instant",
    ]
    private static let highWords: Set<String> = [
        "opus", "max", "pro", "high", "xhigh", "ultra", "o1", "o3",
    ]

    public static func classify(_ modelName: String) -> ModelEffortTier {
        let words = Set(modelName.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if !words.isDisjoint(with: self.fastWords) { return .fast }
        if !words.isDisjoint(with: self.highWords) { return .high }
        return .standard
    }

    /// One muted slate hue, stepped by effort. Light surfaces run deep (high) to a pale tint (fast);
    /// dark surfaces keep the same order of emphasis, so high is the step that stands out most from
    /// graphite and fast sits closest to it. Every step clears 2:1 against its surface.
    public func color(dark: Bool) -> ProviderColor {
        switch (self, dark) {
        case (.high, false): ProviderColor(hex: 0x284A8B)
        case (.standard, false): ProviderColor(hex: 0x5779A9)
        case (.fast, false): ProviderColor(hex: 0x9AB3D4)
        case (.high, true): ProviderColor(hex: 0xB9D3F5)
        case (.standard, true): ProviderColor(hex: 0x7497CA)
        case (.fast, true): ProviderColor(hex: 0x435B85)
        }
    }

    /// Legend examples: public model names, so the key needs no translated copy.
    public var legendExamples: String {
        switch self {
        case .high: "Opus · o3 · Pro"
        case .standard: "Sonnet · GPT-5"
        case .fast: "Haiku · mini · Flash"
        }
    }

    public static func < (lhs: ModelEffortTier, rhs: ModelEffortTier) -> Bool {
        lhs.order < rhs.order
    }

    private var order: Int {
        switch self {
        case .high: 0
        case .standard: 1
        case .fast: 2
        }
    }
}
