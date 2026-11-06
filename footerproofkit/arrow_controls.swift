import AppKit
import Foundation

/// Only creates synthetic offline bitmap controls; no application, event or preferences access.
@main
struct ArrowControls {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        for scale in [1, 2] {
            for direction in ["down", "up", "blank"] {
                let image = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: 300 * scale,
                    pixelsHigh: 200 * scale,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bytesPerRow: 0,
                    bitsPerPixel: 0)!
                let bytes = image.bitmapData!
                for index in 0..<(image.bytesPerRow * image.pixelsHigh) {
                    bytes[index] = 255
                }
                if direction != "blank" {
                    for x in -4...4 {
                        let y = direction == "down" ? 176 - abs(x) : 172 + abs(x)
                        for px in 0..<scale {
                            for py in 0..<scale {
                                let offset = (y * scale + py) * image.bytesPerRow + ((150 + x) * scale + px) * 4
                                for channel in 0..<3 {
                                    bytes[offset + channel] = 128
                                }
                            }
                        }
                    }
                }
                try image.representation(using: .png, properties: [:])!
                    .write(to: root.appendingPathComponent("\(direction)-\(scale)x.png"))
            }
        }
    }
}
