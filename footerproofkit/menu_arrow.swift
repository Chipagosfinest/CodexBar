import AppKit
import Foundation

/// Reads existing screen pixels only. Requires the native down-chevron in the observed menu footer.
@main
struct NativeMenuArrow {
    static func main() {
        do {
            try self.inspect()
        } catch {
            fputs("No verified native down-arrow: \(error)\n", stderr)
            exit(2)
        }
    }

    static func inspect() throws {
        let a = CommandLine.arguments
        guard a.count == 10,
              let image = try NSBitmapImageRep(data: Data(contentsOf: URL(fileURLWithPath: a[1]))),
              let rx = Double(a[2]), let ry = Double(a[3]), let rw = Double(a[4]), let rh = Double(a[5]),
              let dx = Double(a[6]), let dy = Double(a[7]), let dw = Double(a[8]), let dh = Double(a[9]),
              [rx, ry, rw, rh, dx, dy, dw, dh].allSatisfy(\.isFinite), rw > 50, rh > 40, dw > 0, dh > 0
        else { throw CocoaError(.fileReadCorruptFile) }
        let sx = Double(image.pixelsWide) / dw
        let sy = Double(image.pixelsHigh) / dh
        guard abs(sx - sy) < 0.02, sx >= 1,
              rx >= dx, ry >= dy, rx + rw <= dx + dw, ry + rh <= dy + dh
        else { throw CocoaError(.validationMissingMandatoryProperty) }
        let center = rx + rw / 2
        let x0 = Int(((center - 11 - dx) * sx).rounded(.down))
        let x1 = Int(((center + 11 - dx) * sx).rounded(.up))
        let y0 = Int(((ry + rh - 22 - dy) * sy).rounded(.down))
        let y1 = Int(((ry + rh - 4 - dy) * sy).rounded(.up))
        guard x0 >= 0, y0 >= 0, x1 < image.pixelsWide, y1 < image.pixelsHigh else {
            throw CocoaError(.validationMissingMandatoryProperty)
        }
        var points: [(Double, Double)] = []
        for y in y0...y1 {
            for x in x0...x1 {
                guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let components = [c.redComponent, c.greenComponent, c.blueComponent]
                let low = components.min()!, high = components.max()!
                if low > 0.2, high < 0.72, high - low < 0.10 {
                    points.append((Double(x) / sx + dx, Double(y) / sy + dy))
                }
            }
        }
        guard let minX = points.map(\.0).min(), let maxX = points.map(\.0).max(),
              let minY = points.map(\.1).min(), let maxY = points.map(\.1).max(),
              (6...14).contains(maxX - minX + 1 / sx), (3...9).contains(maxY - minY + 1 / sy),
              points.count >= Int(9 * sx * sy), points.count <= Int(65 * sx * sy)
        else { throw CocoaError(.validationMissingMandatoryProperty) }
        let middle = (minX + maxX) / 2
        let centerPoints = points.filter { abs($0.0 - middle) <= 1.5 }
        let edgePoints = points.filter { abs($0.0 - middle) >= (maxX - minX) / 2 - 1.5 }
        guard !centerPoints.isEmpty, !edgePoints.isEmpty else { throw CocoaError(.validationMissingMandatoryProperty) }
        let centerY = centerPoints.map(\.1).reduce(0, +) / Double(centerPoints.count)
        let edgeY = edgePoints.map(\.1).reduce(0, +) / Double(edgePoints.count)
        guard centerY > edgeY + 1.2 else { throw CocoaError(.validationMissingMandatoryProperty) }
        let result: [String: Any] = [
            "x": middle,
            "y": (minY + maxY) / 2,
            "pixelCount": points.count,
            "scale": sx,
            "bounds": [
                "x": minX,
                "y": minY,
                "w": maxX - minX + 1 / sx,
                "h": maxY - minY + 1 / sy,
            ],
            "downChevronObserved": true,
        ]
        try print(String(data: JSONSerialization.data(withJSONObject: result, options: .sortedKeys), encoding: .utf8)!)
    }
}
