import SwiftUI

struct ShareStatsCardView: View {
    static let size = CGSize(width: 1200, height: 630)

    let payload: ShareStatsPayload

    static func providerDisplayLimit(for providerCount: Int) -> Int {
        providerCount > 5 ? 4 : min(providerCount, 5)
    }

    static func providerPaletteIndex(
        for model: ShareStatsModelPayload,
        providers: [ShareStatsProviderPayload]) -> Int?
    {
        providers.firstIndex { $0.provider == model.provider }
    }

    private let background = Color(red: 0.078, green: 0.067, blue: 0.063)
    private let primary = Color(red: 0.96, green: 0.94, blue: 0.91)
    private let secondary = Color(red: 0.70, green: 0.66, blue: 0.62)
    private let accent = Color(red: 0.93, green: 0.56, blue: 0.36)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.header
            self.hero
                .padding(.top, 18)
            Rectangle()
                .fill(self.secondary.opacity(0.16))
                .frame(height: 1)
                .padding(.vertical, 17)
            self.rankings
                .frame(height: 286, alignment: .top)
            Spacer(minLength: 10)
            self.footer
        }
        .padding(.horizontal, 52)
        .padding(.vertical, 34)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background(self.background)
        .foregroundStyle(self.primary)
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 14) {
                ShareStatsMark(accent: self.accent)
                    .frame(width: 34, height: 34)
                Text("CodexBar")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
            }
            Spacer()
            Text("Usage · \(self.periodLabel)")
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .foregroundStyle(self.secondary)
        }
    }

    private var hero: some View {
        HStack(alignment: .center, spacing: 52) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tokens tracked")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(self.secondary)
                Text(self.trackedTokensText)
                    .font(.system(size: 104, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 25)
            .overlay(alignment: .leading) {
                Capsule().fill(self.accent).frame(width: 7, height: 92)
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("Estimated spend")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(self.secondary)
                if self.payload.currencies.isEmpty {
                    Text("No spend data available")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(self.secondary)
                } else {
                    ForEach(self.payload.currencies) { currency in
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(currency.currencyCode) · \(currency.coveredDayCount)/\(self.coverageDenominator)")
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(self.secondary)
                            Spacer()
                            Text(self.spendText(for: currency))
                                .font(.system(size: 32, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                }
            }
            .frame(width: 390, alignment: .leading)
        }
        .padding(.horizontal, 26)
        .frame(height: 150, alignment: .center)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.17, green: 0.12, blue: 0.10), Color(red: 0.12, green: 0.10, blue: 0.095)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.18), radius: 0, y: 5)
    }

    private var rankings: some View {
        HStack(alignment: .top, spacing: 46) {
            VStack(alignment: .leading, spacing: 11) {
                self.sectionHeader("Providers", detail: "\(self.payload.providers.count)")
                ForEach(
                    Array(self.payload.providers.prefix(self.providerDisplayLimit).enumerated()),
                    id: \.offset)
                { index, provider in
                    ShareStatsProviderRow(
                        rank: index + 1,
                        provider: provider,
                        days: self.payload.days,
                        color: ShareStatsPalette.color(at: index))
                }
                if self.payload.providers.count > self.providerDisplayLimit {
                    Text("+\(self.payload.providers.count - self.providerDisplayLimit) more configured")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(self.secondary)
                        .padding(.leading, 20)
                }
            }
            .frame(width: 554, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    self.sectionHeader("Top models", detail: self.payload.hasPartialModels ? "Partial" : "By usage")
                    if self.payload.topModels.isEmpty {
                        Text("No model breakdown recorded")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(self.secondary)
                            .padding(.top, 4)
                    } else {
                        ForEach(
                            Array(self.payload.topModels.prefix(3).enumerated()),
                            id: \.offset)
                        { index, model in
                            ShareStatsModelRow(
                                rank: self.payload.hasPartialModels ? nil : index + 1,
                                model: model,
                                color: self.color(for: model))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var providerDisplayLimit: Int {
        Self.providerDisplayLimit(for: self.payload.providers.count)
    }

    private var isAllTime: Bool {
        self.payload.days >= SpendDashboardSource.scanDays
    }

    private var periodLabel: String {
        self.isAllTime ? "All time" : "\(self.payload.days) days"
    }

    private var trackedTokensText: String {
        guard let tokens = self.payload.totalTokens else { return "—" }
        let formatted = ShareStatsFormatting.compactCount(tokens)
        return self.payload.hasPartialTokens ? "~\(formatted)" : formatted
    }

    private var coverageDenominator: String {
        self.isAllTime ? "all" : "\(self.payload.days)d"
    }

    private func spendText(for currency: ShareStatsCurrencyPayload) -> String {
        guard let cost = currency.estimatedCost else { return "Unavailable" }
        let formatted = ShareStatsFormatting.currency(cost, code: currency.currencyCode)
        return currency.isPartial ? "~\(formatted)" : formatted
    }

    private func color(for model: ShareStatsModelPayload) -> Color {
        guard let index = Self.providerPaletteIndex(for: model, providers: self.payload.providers) else {
            return self.secondary
        }
        return ShareStatsPalette.color(at: index)
    }

    private func sectionHeader(_ title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Spacer()
            Text(detail)
                .font(.system(size: 16, weight: .medium, design: .rounded))
        }
        .foregroundStyle(self.secondary)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Label("Local snapshot · no account details", systemImage: "lock.shield")
            Spacer()
            Text("Through \(ShareStatsFormatting.dataThrough(self.payload))")
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(self.secondary)
    }
}

private struct ShareStatsModelRow: View {
    let rank: Int?
    let model: ShareStatsModelPayload
    let color: Color

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(self.color)
                .frame(width: 5, height: 34)
            Text(self.rank.map { String(format: "%02d", $0) } ?? "·")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.62))
                .frame(width: 27, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(self.model.modelName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(self.model.providerName)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.62))
                    .lineLimit(1)
            }
            Spacer(minLength: 10)
            Text(self.detail)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.78, green: 0.74, blue: 0.69))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .frame(height: 58)
        .background(self.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(self.color.opacity(0.26), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.14), radius: 0, y: 2)
    }

    private var detail: String {
        if let cost = self.model.estimatedCost, cost.isFinite {
            return "~\(ShareStatsFormatting.currency(cost, code: self.model.currencyCode))"
        }
        return self.model.totalTokens.map(ShareStatsFormatting.compactCount) ?? "used"
    }
}

private struct ShareStatsProviderRow: View {
    let rank: Int
    let provider: ShareStatsProviderPayload
    let days: Int
    let color: Color

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(self.color)
                .frame(width: 6, height: 30)
            Text(String(format: "%02d", self.rank))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.62))
                .frame(width: 27, alignment: .leading)
            HStack(spacing: 8) {
                Text(self.provider.providerName)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                if let subscriptionName = self.provider.subscriptionName {
                    Text("· \(subscriptionName)")
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.70, green: 0.66, blue: 0.62))
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 12)
            Text(self.detail)
                .font(.system(size: 18, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color(red: 0.78, green: 0.74, blue: 0.69))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 12)
        .frame(height: 54)
        .background(self.color.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(self.color.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 0, y: 2)
    }

    private var detail: String {
        var metrics: [String] = []
        if let tokens = self.provider.totalTokens {
            metrics.append(ShareStatsFormatting.compactCount(tokens))
        }
        if let cost = self.provider.estimatedCost, cost.isFinite {
            metrics.append("~\(ShareStatsFormatting.currency(cost, code: self.provider.currencyCode))")
            if self.provider.coveredDayCount < self.days {
                metrics.append("\(self.provider.coveredDayCount)/\(self.days)d")
            }
        } else {
            metrics.append("Spend unavailable")
        }
        return metrics.isEmpty ? "connected" : metrics.joined(separator: " · ")
    }
}

private enum ShareStatsPalette {
    static let colors = [
        Color(red: 1.00, green: 0.60, blue: 0.38),
        Color(red: 0.60, green: 0.66, blue: 1.00),
        Color(red: 0.38, green: 0.84, blue: 0.72),
        Color(red: 0.95, green: 0.79, blue: 0.41),
        Color(red: 0.44, green: 0.77, blue: 0.96),
        Color(red: 0.95, green: 0.55, blue: 0.67),
    ]

    static func color(at index: Int) -> Color {
        self.colors[index % self.colors.count]
    }
}

private struct ShareStatsMark: View {
    let accent: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array([0.38, 0.68, 1.0].enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(self.accent)
                    .frame(width: 5, height: 28 * height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
