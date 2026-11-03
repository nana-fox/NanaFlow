import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
for locale in ["en-US", "zh-Hans"] {
    let directory = root.appendingPathComponent(locale)
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter { $0.pathExtension == "png" }.sorted { $0.path < $1.path }
    precondition(files.count == 4, "Expected four store screenshots per locale")
    for file in files {
        let bitmap = NSBitmapImageRep(data: try Data(contentsOf: file))!
        precondition(bitmap.pixelsWide == 2880 && bitmap.pixelsHigh == 1800, file.path)
        precondition(!bitmap.hasAlpha, "Screenshot must be opaque: \(file.path)")
        print("\(locale)/\(file.lastPathComponent): 2880x1800, hasAlpha=no")
        if file.lastPathComponent == "01-focus-menu.png" {
            // This fixed rectangle contains only the real timer digits in the
            // final marketing frame, excluding the phase title and cycle dots.
            var rows: [Int] = []
            for y in 930..<1250 {
                for x in 550..<1580 {
                    let color = bitmap.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
                    if color.redComponent < 0.35 && color.greenComponent < 0.35 && color.blueComponent < 0.35 {
                        rows.append(y)
                        break
                    }
                }
            }
            let height = (rows.max() ?? 0) - (rows.min() ?? 0) + 1
            precondition(height >= 160, "Timer digit ink height must be >=160px")
            print("  actual timer digit ink height: \(height)px (>=160px)")
        }
    }
}
