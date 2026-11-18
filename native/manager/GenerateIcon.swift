import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
guard CommandLine.arguments.count > 3,
      let artwork = NSImage(contentsOfFile: CommandLine.arguments[3]), artwork.isValid else {
    fputs("Missing app icon artwork PNG\n", stderr)
    exit(1)
}
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let representations: [(String, Int)] = [("icon_16x16",16),("icon_16x16@2x",32),("icon_32x32",32),("icon_32x32@2x",64),
                                      ("icon_128x128",128),("icon_128x128@2x",256),("icon_256x256",256),("icon_256x256@2x",512),
                                      ("icon_512x512",512),("icon_512x512@2x",1024)]
for (name, pixels) in representations {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                 isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    NSGraphicsContext.current?.imageInterpolation = .high
    context.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
    artwork.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
                 from: .zero, operation: .sourceOver, fraction: 1,
                 respectFlipped: false, hints: [.interpolation: NSImageInterpolation.high])
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent(name + ".png"))
}

// A modern ICNS is a sized container of PNG representations. Write it directly
// so building does not depend on the icon conversion service being available.
let iconEntries = [("icon_16x16", "icp4"), ("icon_32x32", "icp5"), ("icon_32x32@2x", "icp6"),
                   ("icon_128x128", "ic07"), ("icon_256x256", "ic08"), ("icon_512x512", "ic09"),
                   ("icon_512x512@2x", "ic10"), ("icon_16x16@2x", "ic11"),
                   ("icon_32x32@2x", "ic12"), ("icon_128x128@2x", "ic13"), ("icon_256x256@2x", "ic14")]
func sizedBlock(_ type: String, _ contents: Data) -> Data {
    var result = Data(type.utf8)
    var length = UInt32(contents.count + 8).bigEndian
    withUnsafeBytes(of: &length) { result.append(contentsOf: $0) }
    result.append(contents)
    return result
}
var contents = Data()
for (name, type) in iconEntries {
    contents.append(sizedBlock(type, try Data(contentsOf: output.appendingPathComponent(name + ".png"))))
}
let iconURL = CommandLine.arguments.count > 2 ? URL(fileURLWithPath: CommandLine.arguments[2]) : output.deletingLastPathComponent().appendingPathComponent("MultiCodex.icns")
try sizedBlock("icns", contents).write(to: iconURL)
