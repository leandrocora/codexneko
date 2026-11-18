import AppKit
import Foundation

// Documentation mockup with fictitious accounts and the actual mascot artwork.
// Uses only bitmap drawing, without reading profiles or capturing the desktop.
guard CommandLine.arguments.count == 3,
      let cat = NSImage(contentsOfFile: CommandLine.arguments[1]) else {
    fputs("Usage: render-manager-preview CatMale.png output.png\n", stderr)
    exit(1)
}
let width = 980, height = 910
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width * 2, pixelsHigh: height * 2,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
let cg = NSGraphicsContext.current!.cgContext
cg.scaleBy(x: 2, y: 2)
cg.translateBy(x: 0, y: CGFloat(height))
cg.scaleBy(x: 1, y: -1)
NSGraphicsContext.current?.imageInterpolation = .high
func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
            green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let bg: UInt32 = 0x111318, surface: UInt32 = 0x1B1E25, outline: UInt32 = 0x343A46
func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat, _ fill: UInt32, _ stroke: UInt32? = nil) {
    let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: r, yRadius: r)
    color(fill).setFill(); path.fill()
    if let stroke = stroke { color(stroke).setStroke(); path.lineWidth = 1.4; path.stroke() }
}
func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ weight: NSFont.Weight = .regular, _ ink: UInt32 = 0xF4F5F7) {
    let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color(ink)]
    let string = NSAttributedString(string: value, attributes: attributes)
    let height = string.size().height
    NSGraphicsContext.saveGraphicsState()
    cg.translateBy(x: x, y: y + height); cg.scaleBy(x: 1, y: -1)
    string.draw(at: .zero)
    NSGraphicsContext.restoreGraphicsState()
}
func image(_ image: NSImage, _ rect: CGRect) {
    var source = CGRect(origin: .zero, size: image.size)
    if let raw = image.cgImage(forProposedRect: &source, context: nil, hints: nil) {
        cg.saveGState(); cg.translateBy(x: rect.minX, y: rect.maxY); cg.scaleBy(x: 1, y: -1)
        cg.draw(raw, in: CGRect(origin: .zero, size: rect.size)); cg.restoreGState()
    }
}
box(0, 0, 980, 910, 0, 0x090B0F)
box(30, 25, 920, 860, 28, bg, outline)
for (x, ink) in [(60, UInt32(0xFF5F57)), (90, UInt32(0xFFBD2E)), (120, UInt32(0x28C840))] {
    box(CGFloat(x - 9), 45, 18, 18, 9, ink)
}
text("Contas Codex", 67, 110, 38, .bold)
text("3 contas · CodexNeko 1.0", 67, 157, 18, .regular, 0x9BA2B0)
box(667, 114, 246, 52, 26, 0x2386FF)
text("+", 690, 123, 27, .regular)
text("Adicionar conta", 724, 129, 20, .medium)
let catWidth: CGFloat = 143
let catHeight = catWidth * cat.size.height / cat.size.width
image(cat, CGRect(x: 67, y: 205 + (76 - catHeight) / 2, width: catWidth, height: catHeight))
box(229, 215, 191, 52, 19, surface, outline)
text("1 de 3 abertas.", 248, 229, 19, .semibold)
for (index, name, letter, ink) in [(0, "Principal", "P", UInt32(0x129CB2)), (1, "Trabalho", "T", UInt32(0x7940D4)), (2, "Projetos", "P", UInt32(0x197D6B))] {
    let y = CGFloat(295 + index * 134)
    box(67, y, 846, 117, 22, surface, outline)
    box(91, y + 24, 69, 69, 34.5, ink)
    text(letter, 115, y + 39, 31, .semibold)
    text(name, 187, y + 21, 26, .semibold)
    let running = index == 0
    box(187, y + 64, running ? 133 : 155, 28, 14, running ? 0x183225 : 0x252932)
    box(198, y + 74, 8, 8, 4, running ? 0x35BB58 : 0x818895)
    text(running ? "Em execução" : "Não está aberta", 214, y + 69, 14, .medium, running ? 0x45D577 : 0xA1A7B1)
    box(733, y + 37, 111, 43, 21, running ? 0x2C313C : 0x1D3554)
    text(running ? "Mostrar" : "Abrir", running ? 753 : 766, y + 47, 19, .medium, running ? 0xF4F5F7 : 0x68A9FF)
    text("···", 869, y + 40, 26, .medium, 0xAFB5C1)
}
text("CONEXÕES", 72, 724, 13, .semibold, 0x9BA2B0)
box(67, 749, 846, 79, 22, surface, outline)
text("↗", 99, 770, 27, .regular, 0x9BA2B0)
text("Conecte na conta certa", 153, 764, 20, .semibold)
text("Ao conectar um plugin, escolha a janela que iniciou a conexão.", 153, 794, 14, .regular, 0x9BA2B0)
text("?", 868, 774, 24, .regular, 0x9BA2B0)
text("Atualizar     Arquivadas (0)", 70, 851, 12, .regular, 0x9BA2B0)
text("Personalizar     Ajuda  ·  Coradini", 710, 851, 12, .regular, 0x9BA2B0)
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print("Documentation mockup rendered with fictitious accounts.")
