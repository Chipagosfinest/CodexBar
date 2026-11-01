import AppKit
import CodexBarCore

extension MenuBarLayoutRenderer {
    /// Session and weekly as stacked bars, or one bar for single-window providers. Pre-tinted because attributed-title
    /// attachments are not template-tinted, but still flagged as a mask so stale rendering can join the status image.
    /// Only a window at its limit shows red, and the footprint never changes.
    static func usageMetersToken(
        data: MenuBarLayoutRenderData,
        style: TokenStyle,
        options: MenuBarLayoutRenderOptions)
        -> (value: NSAttributedString, accessibilityText: String?)
    {
        // A model-scoped weekly limit takes the weekly bar once it is the tighter of the two, so it can still warn.
        let weeklyWindow: PercentWindow = if let scoped = self.window(.scopedWeekly, data: data),
                                             scoped.remainingPercent < self.window(.weekly, data: data)?
                                             .remainingPercent ?? .infinity
        {
            .scopedWeekly
        } else {
            .weekly
        }
        let windows: [(window: PercentWindow, rate: MenuBarLayoutRenderWindow)] =
            [PercentWindow.session, weeklyWindow].compactMap { window in
                self.window(window, data: data).map { (window, $0) }
            }
        let resolved = windows.isEmpty
            ? [PercentWindow.automatic].compactMap { window in self.window(window, data: data).map { (window, $0) } }
            : windows
        guard !resolved.isEmpty else {
            return self.textToken(
                self.missingValue,
                accessibilityText: L("Usage bar unavailable"),
                attributes: style.attributes)
        }
        let bars = resolved.map { entry in
            UsageMeterBar(
                fill: (options.showUsed ? entry.rate.usedPercent : entry.rate.remainingPercent).clamped(to: 0...100),
                isCritical: !options.isStale
                    && entry.rate.remainingPercent <= UsageMenuCardView.Model.Metric.nearLimitRemainingPercent)
        }
        let size = NSSize(width: Self.usageMeterWidth, height: Self.usageMeterHeight)
        let image = self.usageMetersImage(bars: bars, size: size, tint: style.foregroundColor)
        let attachment = NSTextAttachment()
        attachment.image = image
        attachment.bounds = NSRect(
            x: 0,
            y: self.attachmentYOrigin(height: size.height, style: style),
            width: size.width,
            height: size.height)
        let accessibility = resolved.map { entry in
            let text = self.percentValue(
                window: entry.window,
                rateWindow: entry.rate,
                automaticText: nil,
                estimated: data.quotaIsEstimated,
                showUsed: options.showUsed).text
            return L("%@ %@", self.windowAccessibilityLabel(entry.window, data: data), text)
        }.joined(separator: ", ")
        return (self.attachmentText(attachment, style: style), accessibility)
    }

    struct UsageMeterBar: Equatable {
        let fill: Double
        let isCritical: Bool
    }

    static let usageMeterWidth: CGFloat = 24
    static let usageMeterHeight: CGFloat = 12

    static func usageMetersImage(bars: [UsageMeterBar], size: NSSize, tint: NSColor) -> NSImage {
        let hasCritical = bars.contains(where: \.isCritical)
        let gap: CGFloat = 2
        let barHeight = bars.count > 1
            ? ((size.height - gap * CGFloat(bars.count - 1)) / CGFloat(bars.count)).rounded(.down)
            : 6
        let total = barHeight * CGFloat(bars.count) + gap * CGFloat(bars.count - 1)
        let image = NSImage(size: size, flipped: true) { rect in
            var y = ((rect.height - total) / 2).rounded()
            let radius = min(barHeight / 2, 2)
            let base = tint
            for bar in bars {
                let track = NSRect(x: 0, y: y, width: rect.width, height: barHeight)
                // The track carries the warning too: an exhausted window has no fill when bars show what is left.
                (bar.isCritical ? NSColor.systemRed : base).withAlphaComponent(0.32).setFill()
                NSBezierPath(roundedRect: track, xRadius: radius, yRadius: radius).fill()
                var filled = track
                // A nonzero window always shows a sliver; an empty one stays an empty track.
                filled.size.width = bar.fill > 0 ? max(barHeight, rect.width * bar.fill / 100) : 0
                if filled.width > 0 {
                    (bar.isCritical ? NSColor.systemRed : base).setFill()
                    NSBezierPath(roundedRect: filled, xRadius: radius, yRadius: radius).fill()
                }
                y += barHeight + gap
            }
            return true
        }
        image.isTemplate = !hasCritical
        return image
    }
}
