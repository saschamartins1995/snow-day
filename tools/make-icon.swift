import AppKit
// Draws the Snow Day app icon at 1024 × 1024 in the macOS template:
// a rounded square of 824 points with a soft shadow, a winter night with
// the Matterhorn, snow, falling flakes and a snowman in front.
let S: CGFloat = 1024
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: a) }
func grad(_ cols: [CGColor], _ locs: [CGFloat]) -> CGGradient { CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: cols as CFArray, locations: locs)! }
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)
// Shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: c(0, 0, 0, 0.35))
ctx.addPath(shape); ctx.setFillColor(c(0.1, 0.15, 0.3)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(shape); ctx.clip()
// Sky: deep night at the top, a blue glow toward the mountains.
ctx.drawLinearGradient(grad([c(0.05, 0.08, 0.22), c(0.13, 0.22, 0.47), c(0.36, 0.50, 0.78)], [0, 0.55, 1]),
                       start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 380), options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
// Stars.
var seed: UInt64 = 7
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat(seed >> 33) / CGFloat(UInt32.max >> 1) }
for _ in 0..<70 {
    let x = 110 + rnd() * 800, y = 640 + rnd() * 280, r = 1.2 + rnd() * 2.4
    ctx.setFillColor(c(1, 1, 1, 0.35 + rnd() * 0.55)); ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
}
// Moon glow.
ctx.drawRadialGradient(grad([c(1, 0.97, 0.88, 0.55), c(1, 0.97, 0.88, 0)], [0, 1]), startCenter: CGPoint(x: 770, y: 790), startRadius: 0,
                       endCenter: CGPoint(x: 770, y: 790), endRadius: 170, options: [])
ctx.setFillColor(c(1, 0.98, 0.9)); ctx.fillEllipse(in: CGRect(x: 735, y: 755, width: 70, height: 70))
// Back ridge.
let ridge = CGMutablePath()
ridge.move(to: CGPoint(x: 100, y: 440))
ridge.addLine(to: CGPoint(x: 230, y: 520)); ridge.addLine(to: CGPoint(x: 330, y: 480)); ridge.addLine(to: CGPoint(x: 420, y: 540))
ridge.addLine(to: CGPoint(x: 924, y: 470)); ridge.addLine(to: CGPoint(x: 924, y: 300)); ridge.addLine(to: CGPoint(x: 100, y: 300)); ridge.closeSubpath()
ctx.addPath(ridge); ctx.setFillColor(c(0.55, 0.66, 0.86)); ctx.fillPath()
// The Matterhorn: a lit east face and a shaded north face.
let peak = CGPoint(x: 640, y: 800)
let lit = CGMutablePath()
lit.move(to: peak); lit.addLine(to: CGPoint(x: 600, y: 760)); lit.addLine(to: CGPoint(x: 560, y: 640))
lit.addLine(to: CGPoint(x: 470, y: 520)); lit.addLine(to: CGPoint(x: 380, y: 380)); lit.addLine(to: CGPoint(x: 360, y: 300)); lit.addLine(to: CGPoint(x: 720, y: 300))
lit.addLine(to: CGPoint(x: 700, y: 440)); lit.addLine(to: CGPoint(x: 665, y: 620)); lit.closeSubpath()
ctx.addPath(lit); ctx.setFillColor(c(0.96, 0.97, 1)); ctx.fillPath()
let shade = CGMutablePath()
shade.move(to: peak); shade.addLine(to: CGPoint(x: 665, y: 620)); shade.addLine(to: CGPoint(x: 700, y: 440))
shade.addLine(to: CGPoint(x: 720, y: 300)); shade.addLine(to: CGPoint(x: 924, y: 300)); shade.addLine(to: CGPoint(x: 860, y: 440)); shade.addLine(to: CGPoint(x: 760, y: 560)); shade.addLine(to: CGPoint(x: 700, y: 700)); shade.closeSubpath()
ctx.addPath(shade); ctx.setFillColor(c(0.62, 0.71, 0.89)); ctx.fillPath()
// Rock bands on the shaded face.
ctx.setStrokeColor(c(0.42, 0.50, 0.70, 0.7)); ctx.setLineWidth(5); ctx.setLineCap(.round)
for (a, b) in [((690, 690), (720, 640)), ((700, 600), (745, 560)), ((710, 520), (790, 480))] as [((CGFloat, CGFloat), (CGFloat, CGFloat))] {
    ctx.move(to: CGPoint(x: a.0, y: a.1)); ctx.addLine(to: CGPoint(x: b.0, y: b.1))
}
ctx.strokePath()
// Snowy foreground hills.
let hill = CGMutablePath()
hill.move(to: CGPoint(x: 100, y: 470))
hill.addCurve(to: CGPoint(x: 924, y: 400), control1: CGPoint(x: 360, y: 530), control2: CGPoint(x: 640, y: 360))
hill.addLine(to: CGPoint(x: 924, y: 100)); hill.addLine(to: CGPoint(x: 100, y: 100)); hill.closeSubpath()
ctx.saveGState(); ctx.addPath(hill); ctx.clip()
ctx.drawLinearGradient(grad([c(1, 1, 1), c(0.80, 0.87, 0.97)], [0, 1]), start: CGPoint(x: 0, y: 500), end: CGPoint(x: 0, y: 100), options: [])
ctx.restoreGState()
// A little chalet with a lit window on the hill.
ctx.setFillColor(c(0.45, 0.28, 0.17)); ctx.fill(CGRect(x: 760, y: 392, width: 92, height: 62))
let roof = CGMutablePath(); roof.move(to: CGPoint(x: 744, y: 450)); roof.addLine(to: CGPoint(x: 806, y: 500)); roof.addLine(to: CGPoint(x: 868, y: 450)); roof.closeSubpath()
ctx.addPath(roof); ctx.setFillColor(c(0.97, 0.98, 1)); ctx.fillPath()
ctx.drawRadialGradient(grad([c(1, 0.78, 0.35, 0.7), c(1, 0.78, 0.35, 0)], [0, 1]), startCenter: CGPoint(x: 806, y: 420), startRadius: 0, endCenter: CGPoint(x: 806, y: 420), endRadius: 60, options: [])
ctx.setFillColor(c(1, 0.83, 0.45)); ctx.fill(CGRect(x: 794, y: 408, width: 24, height: 22))
// The snowman.
func ball(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: c(0.1, 0.2, 0.45, 0.35))
    ctx.setFillColor(c(1, 1, 1)); ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r))
    ctx.restoreGState()
    ctx.saveGState(); ctx.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)); ctx.clip()
    ctx.drawRadialGradient(grad([c(1, 1, 1, 0), c(0.70, 0.79, 0.95, 0.9)], [0.55, 1]), startCenter: CGPoint(x: cx - r * 0.35, y: cy + r * 0.35), startRadius: 0,
                           endCenter: CGPoint(x: cx - r * 0.1, y: cy + r * 0.1), endRadius: r * 1.25, options: [])
    ctx.restoreGState()
}
let mx: CGFloat = 400
// Ground shadow.
ctx.setFillColor(c(0.45, 0.58, 0.85, 0.35)); ctx.fillEllipse(in: CGRect(x: mx - 170, y: 150, width: 340, height: 50))
ball(mx, 270, 140)
ball(mx, 460, 102)
ball(mx, 612, 76)
// Buttons.
ctx.setFillColor(c(0.13, 0.13, 0.17))
for y in [300, 380, 455] as [CGFloat] { ctx.fillEllipse(in: CGRect(x: mx - 10, y: y - 10, width: 20, height: 20)) }
// Scarf.
ctx.setFillColor(c(0.80, 0.10, 0.20))
ctx.addPath(CGPath(roundedRect: CGRect(x: mx - 92, y: 530, width: 184, height: 40), cornerWidth: 20, cornerHeight: 20, transform: nil)); ctx.fillPath()
let tail = CGMutablePath(); tail.move(to: CGPoint(x: mx + 40, y: 545)); tail.addLine(to: CGPoint(x: mx + 92, y: 440)); tail.addLine(to: CGPoint(x: mx + 130, y: 452)); tail.addLine(to: CGPoint(x: mx + 82, y: 552)); tail.closeSubpath()
ctx.addPath(tail); ctx.fillPath()
ctx.setFillColor(c(1, 1, 1, 0.9))
for x in stride(from: mx - 78, to: mx + 90, by: 36) { ctx.fill(CGRect(x: x, y: 532, width: 12, height: 36)) }
// Face.
ctx.setFillColor(c(0.13, 0.13, 0.17))
ctx.fillEllipse(in: CGRect(x: mx - 34, y: 622, width: 17, height: 17)); ctx.fillEllipse(in: CGRect(x: mx + 17, y: 622, width: 17, height: 17))
for (dx, dy) in [(-30, 590), (-15, 580), (0, 576), (15, 580), (30, 590)] as [(CGFloat, CGFloat)] { ctx.fillEllipse(in: CGRect(x: mx + dx - 5, y: dy - 5, width: 10, height: 10)) }
let nose = CGMutablePath(); nose.move(to: CGPoint(x: mx - 4, y: 616)); nose.addLine(to: CGPoint(x: mx + 70, y: 602)); nose.addLine(to: CGPoint(x: mx - 2, y: 600)); nose.closeSubpath()
ctx.addPath(nose); ctx.setFillColor(c(0.96, 0.52, 0.12)); ctx.fillPath()
// Bobble hat in red with a white brim and bobble.
let hat = CGMutablePath(); hat.move(to: CGPoint(x: mx - 70, y: 668)); hat.addCurve(to: CGPoint(x: mx + 60, y: 760), control1: CGPoint(x: mx - 60, y: 740), control2: CGPoint(x: mx + 10, y: 770))
hat.addCurve(to: CGPoint(x: mx + 72, y: 668), control1: CGPoint(x: mx + 75, y: 730), control2: CGPoint(x: mx + 76, y: 700)); hat.closeSubpath()
ctx.addPath(hat); ctx.setFillColor(c(0.82, 0.10, 0.20)); ctx.fillPath()
ctx.setFillColor(c(0.98, 0.98, 1)); ctx.addPath(CGPath(roundedRect: CGRect(x: mx - 82, y: 652, width: 164, height: 34), cornerWidth: 17, cornerHeight: 17, transform: nil)); ctx.fillPath()
ctx.fillEllipse(in: CGRect(x: mx + 44, y: 744, width: 40, height: 40))
// Falling snow in front.
for _ in 0..<55 {
    let x = 110 + rnd() * 800, y = 120 + rnd() * 800, r = 5 + rnd() * 11
    ctx.setFillColor(c(1, 1, 1, 0.55 + rnd() * 0.4)); ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
}
// A soft highlight along the top edge.
ctx.drawLinearGradient(grad([c(1, 1, 1, 0.16), c(1, 1, 1, 0)], [0, 1]), start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 760), options: [])
ctx.restoreGState()
ctx.addPath(shape); ctx.setStrokeColor(c(1, 1, 1, 0.12)); ctx.setLineWidth(2); ctx.strokePath()
let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
