import AppKit

/// The pointer Snow Day shows in Christmas mode, picked in the menu.
enum FestivePointerStyle: String, CaseIterable {
    case candyCane, peppermint, plain
    var title: String {
        switch self {
        case .candyCane: "Candy Cane"
        case .peppermint: "Peppermint"
        case .plain: "Standard Pointer"
        }
    }
}

enum FestiveCursorArt {
    static var style: FestivePointerStyle = .candyCane
    /// The arrow for Christmas mode, or nil for the system's own.
    static var pointer: NSCursor? {
        switch style {
        case .candyCane: arrow
        case .peppermint: candy[0]
        case .plain: nil
        }
    }
    static func open(_ christmas: Bool) -> NSCursor { christmas && style != .plain ? openHand : .openHand }
    static func closed(_ christmas: Bool) -> NSCursor { christmas && style != .plain ? closedHand : .closedHand }

    static let arrow = tint(NSCursor.arrow)
    static let openHand = tint(NSCursor.openHand, stripeLight: true)
    static let closedHand = tint(NSCursor.closedHand, stripeLight: true)

    /// Candy stripes on a system pointer. A black pointer gets the stripes
    /// in its black; a white one with a black rim (the hands) gets them in
    /// its white and a dark red rim instead, and its soft shadow stays.
    static func tint(_ original: NSCursor, stripeLight: Bool = false) -> NSCursor {
        let image = original.image
        guard let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let colored = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels.width, pixelsHigh: pixels.height,
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                             colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return original }
        let source = NSBitmapImageRep(cgImage: pixels)
        for row in 0..<source.pixelsHigh {
            for column in 0..<source.pixelsWide {
                guard let color = source.colorAt(x: column, y: row)?.usingColorSpace(.deviceRGB) else { continue }
                let luminance = color.redComponent * 0.21 + color.greenComponent * 0.72 + color.blueComponent * 0.07
                let solid = color.alphaComponent > (stripeLight ? 0.6 : 0.22)
                let festive = stripeLight ? solid && luminance > 0.6 : luminance < 0.46 && solid
                let rim = stripeLight && solid && luminance < 0.46
                let light = 1 - CGFloat(row) / CGFloat(max(1, source.pixelsHigh - 1))
                let scale = CGFloat(source.pixelsWide) / max(1, image.size.width)
                let stripe = Int((CGFloat(column) + CGFloat(row) * 0.68) / (4.2 * scale)) % 2 == 0
                let pigment = stripe
                    ? NSColor(deviceRed: 0.81 + 0.12 * light, green: 0.11 + 0.06 * light,
                              blue: 0.20 + 0.05 * light, alpha: color.alphaComponent)
                    : NSColor(deviceRed: 1, green: 0.96 + 0.03 * light,
                              blue: 0.92 + 0.06 * light, alpha: color.alphaComponent)
                let deepRed = NSColor(deviceRed: 0.50, green: 0.04, blue: 0.10, alpha: color.alphaComponent)
                colored.setColor(festive ? pigment : rim ? deepRed : color, atX: column, y: row)
            }
        }
        colored.size = image.size
        let output = NSImage(size: image.size)
        output.addRepresentation(colored)
        return NSCursor(image: output, hotSpot: original.hotSpot)
    }

    static let candy: [NSCursor] = (0..<12).map { frame in
        let image = NSImage(size: CGSize(width: 26, height: 26), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 10.7
            let disk = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -0.7), blur: 1.4,
                          color: NSColor.black.withAlphaComponent(0.45).cgColor)
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in: disk)
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addEllipse(in: disk)
            ctx.clip()
            ctx.translateBy(x: center.x, y: center.y)
            ctx.setFillColor(NSColor(srgbRed: 0.83, green: 0.06, blue: 0.15, alpha: 1).cgColor)
            let step = CGFloat.pi / 3
            func point(_ radius: CGFloat, _ angle: CGFloat) -> CGPoint {
                CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            }
            for segment in 0..<6 {
                let angle = CGFloat(segment) * step - CGFloat(frame) * step / 12
                let end = angle + step * 0.49
                ctx.move(to: .zero)
                ctx.addCurve(to: point(radius, angle),
                             control1: point(3.2, angle - 1.9), control2: point(7.6, angle - 0.79))
                ctx.addArc(center: .zero, radius: radius, startAngle: angle, endAngle: end, clockwise: false)
                ctx.addCurve(to: .zero,
                             control1: point(7.6, end - 0.79), control2: point(3.2, end - 1.9))
                ctx.closePath()
                ctx.fillPath()
            }
            ctx.restoreGState()
            ctx.setStrokeColor(NSColor(srgbRed: 0.39, green: 0.04, blue: 0.08, alpha: 0.75).cgColor)
            ctx.setLineWidth(0.8)
            ctx.strokeEllipse(in: disk)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.62).cgColor)
            ctx.setLineWidth(1)
            ctx.setLineCap(.round)
            ctx.addArc(center: center, radius: radius - 2.1, startAngle: 1.10, endAngle: 2.34, clockwise: false)
            ctx.strokePath()
            return true
        }
        return NSCursor(image: image, hotSpot: CGPoint(x: 13, y: 13))
    }
}

class FestiveCursorSurface: NSView {
    var festiveCursor = false {
        didSet { window?.invalidateCursorRects(for: self) }
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if festiveCursor, let pointer = FestiveCursorArt.pointer { addCursorRect(visibleRect, cursor: pointer) }
    }
}

/// Christmas pictures for the system's other pointers.
extension FestiveCursorArt {
    /// A text cursor as a little candy cane: red and white stripes, a dark
    /// red rim so it shows on white text fields, a light halo for dark ones.
    static func candyBeam(like original: NSCursor, vertical: Bool) -> NSCursor {
        let size = original.image.size
        let image = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.translateBy(x: original.hotSpot.x, y: size.height - original.hotSpot.y)
            if vertical { ctx.rotate(by: .pi / 2) }
            let half = min(size.width, size.height) * 0.46
            let stem: CGFloat = 1.3, serif: CGFloat = 3.4, bar: CGFloat = 1.15
            let shape = CGMutablePath()
            shape.addRoundedRect(in: CGRect(x: -stem, y: -half, width: stem * 2, height: half * 2),
                                 cornerWidth: stem * 0.8, cornerHeight: stem * 0.8)
            for end: CGFloat in [-1, 1] {
                shape.addRoundedRect(in: CGRect(x: -serif, y: end * half - bar, width: serif * 2, height: bar * 2),
                                     cornerWidth: bar * 0.9, cornerHeight: bar * 0.9)
            }
            ctx.addPath(shape)
            ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.85).cgColor)
            ctx.setLineWidth(2.2)
            ctx.setLineJoin(.round)
            ctx.strokePath()
            ctx.saveGState()
            ctx.addPath(shape)
            ctx.clip()
            ctx.setFillColor(NSColor(srgbRed: 1, green: 0.97, blue: 0.94, alpha: 1).cgColor)
            ctx.fill(CGRect(x: -serif - 2, y: -half - 2, width: serif * 2 + 4, height: half * 2 + 4))
            ctx.setFillColor(NSColor(srgbRed: 0.84, green: 0.10, blue: 0.20, alpha: 1).cgColor)
            var y = -half - serif * 2
            while y < half + serif {
                let band = CGMutablePath()
                band.move(to: CGPoint(x: -serif - 2, y: y))
                band.addLine(to: CGPoint(x: serif + 2, y: y + 2.6))
                band.addLine(to: CGPoint(x: serif + 2, y: y + 4.4))
                band.addLine(to: CGPoint(x: -serif - 2, y: y + 1.8))
                band.closeSubpath()
                ctx.addPath(band)
                y += 3.6
            }
            ctx.fillPath()
            ctx.restoreGState()
            ctx.addPath(shape)
            ctx.setStrokeColor(NSColor(srgbRed: 0.45, green: 0.04, blue: 0.10, alpha: 0.9).cgColor)
            ctx.setLineWidth(0.6)
            ctx.strokePath()
            return true
        }
        return NSCursor(image: image, hotSpot: original.hotSpot)
    }

    /// The resize pointers as little fir trees, one for each way the edge
    /// can move: a tree pointing up and one pointing down for an edge that
    /// moves up and down, sideways ones for left and right. `angles` are
    /// the directions in degrees, 0 to the right and 90 up.
    static func firTrees(_ angles: [CGFloat]) -> NSCursor {
        let side: CGFloat = 28
        let image = NSImage(size: CGSize(width: side, height: side), flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.translateBy(x: side / 2, y: side / 2)
            for angle in angles {
                ctx.saveGState()
                ctx.rotate(by: angle * .pi / 180)
                // Pointing along +x: trunk near the middle, the tip outside.
                let tree = CGMutablePath()
                let tiers: [(base: CGFloat, top: CGFloat, half: CGFloat)] = [(3.6, 9.0, 4.9), (6.9, 11.4, 3.7), (9.4, 13.4, 2.5)]
                for tier in tiers {
                    tree.move(to: CGPoint(x: tier.base, y: -tier.half))
                    tree.addQuadCurve(to: CGPoint(x: tier.top, y: 0), control: CGPoint(x: tier.base + (tier.top - tier.base) * 0.55, y: -tier.half * 0.35))
                    tree.addQuadCurve(to: CGPoint(x: tier.base, y: tier.half), control: CGPoint(x: tier.base + (tier.top - tier.base) * 0.55, y: tier.half * 0.35))
                    tree.closeSubpath()
                }
                let trunk = CGRect(x: 1.4, y: -0.9, width: 2.6, height: 1.8)
                // A light rim all round, so the tree shows on dark windows too.
                ctx.addPath(tree)
                ctx.addRect(trunk)
                ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor)
                ctx.setLineWidth(2.4)
                ctx.setLineJoin(.round)
                ctx.strokePath()
                ctx.setFillColor(NSColor(srgbRed: 0.42, green: 0.25, blue: 0.13, alpha: 1).cgColor)
                ctx.fill(trunk)
                ctx.addPath(tree)
                ctx.setFillColor(NSColor(srgbRed: 0.09, green: 0.43, blue: 0.21, alpha: 1).cgColor)
                ctx.fillPath()
                ctx.addPath(tree)
                ctx.setStrokeColor(NSColor(srgbRed: 0.03, green: 0.22, blue: 0.10, alpha: 0.9).cgColor)
                ctx.setLineWidth(0.6)
                ctx.strokePath()
                // Snow on the edges of the boughs, a star at the tip, a bauble.
                ctx.setFillColor(NSColor.white.cgColor)
                for tier in tiers {
                    ctx.fillEllipse(in: CGRect(x: tier.base - 0.2, y: -tier.half - 0.4, width: 1.6, height: 1.2))
                    ctx.fillEllipse(in: CGRect(x: tier.base - 0.2, y: tier.half - 0.8, width: 1.6, height: 1.2))
                }
                ctx.setFillColor(NSColor(srgbRed: 1, green: 0.82, blue: 0.25, alpha: 1).cgColor)
                ctx.fillEllipse(in: CGRect(x: 12.6, y: -1.0, width: 2.0, height: 2.0))
                ctx.setFillColor(NSColor(srgbRed: 0.86, green: 0.10, blue: 0.18, alpha: 1).cgColor)
                ctx.fillEllipse(in: CGRect(x: 6.0, y: 0.6, width: 1.7, height: 1.7))
                ctx.restoreGState()
            }
            return true
        }
        return NSCursor(image: image, hotSpot: CGPoint(x: side / 2, y: side / 2))
    }

    /// Every system pointer Snow Day dresses up, with its Christmas picture.
    /// The arrow follows the chosen style; everything else is the same for
    /// both festive styles.
    static func festivePairs() -> [(plain: NSCursor, festive: () -> NSCursor)] {
        var pairs: [(NSCursor, () -> NSCursor)] = [
            (.iBeam, { candyBeam(like: .iBeam, vertical: false) }),
            (.iBeamCursorForVerticalLayout, { candyBeam(like: .iBeamCursorForVerticalLayout, vertical: true) }),
            (.openHand, { openHand }), (.closedHand, { closedHand }),
            (.resizeUpDown, { firTrees([90, 270]) }), (.resizeUp, { firTrees([90]) }), (.resizeDown, { firTrees([270]) }),
            (.resizeLeftRight, { firTrees([0, 180]) }), (.resizeLeft, { firTrees([180]) }), (.resizeRight, { firTrees([0]) })
        ]
        pairs.append((.pointingHand, { tint(.pointingHand, stripeLight: true) }))
        for plain in [NSCursor.crosshair, .operationNotAllowed, .dragLink, .dragCopy, .contextualMenu, .disappearingItem] {
            pairs.append((plain, { tint(plain) }))
        }
        if #available(macOS 15.0, *) {
            // Window edges and corners: the trees point the way the edge moves.
            let edges: [(NSCursor.FrameResizePosition, CGFloat)] = [
                (.right, 0), (.topRight, 45), (.top, 90), (.topLeft, 135),
                (.left, 180), (.bottomLeft, 225), (.bottom, 270), (.bottomRight, 315)]
            for (position, out) in edges {
                pairs.append((NSCursor.frameResize(position: position, directions: .all), { firTrees([out, out + 180]) }))
                pairs.append((NSCursor.frameResize(position: position, directions: .outward), { firTrees([out]) }))
                pairs.append((NSCursor.frameResize(position: position, directions: .inward), { firTrees([out + 180]) }))
            }
            pairs.append((NSCursor.columnResize(directions: .all), { firTrees([0, 180]) }))
            pairs.append((NSCursor.columnResize(directions: .left), { firTrees([180]) }))
            pairs.append((NSCursor.columnResize(directions: .right), { firTrees([0]) }))
            pairs.append((NSCursor.rowResize(directions: .all), { firTrees([90, 270]) }))
            pairs.append((NSCursor.rowResize(directions: .up), { firTrees([90]) }))
            pairs.append((NSCursor.rowResize(directions: .down), { firTrees([270]) }))
            for plain in [NSCursor.zoomIn, .zoomOut] { pairs.append((plain, { tint(plain) })) }
        }
        return pairs
    }
}

/// Shows the Christmas pointers everywhere macOS would show its own: on the
/// desktop, in the village, over Finder and over other apps' windows.
/// Snow Day never takes a click for it; it only swaps the picture. macOS
/// lets a background app change the pointer once it says so on its window
/// server connection. Apps set their pointer again on every mouse movement,
/// so the swap follows each movement at once, not on a clock.
final class FestivePointerKeeper {
    private typealias MainConnection = @convention(c) () -> Int32
    private typealias SetProperty = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32
    private typealias CursorSeed = @convention(c) () -> Int32

    private let seed: CursorSeed?
    private var lastSeed: Int32 = -1
    private var timer: Timer?
    private var monitors: [Any] = []
    /// System picture → how to make its Christmas one, and the ones made.
    private var recipes: [String: () -> NSCursor] = [:]
    private var made: [String: NSCursor] = [:]
    /// Christmas picture → the system one it stands for, to put back.
    private var originals: [String: NSCursor] = [:]

    init() {
        let symbols = UnsafeMutableRawPointer(bitPattern: -2)
        if let main = dlsym(symbols, "CGSMainConnectionID"), let set = dlsym(symbols, "CGSSetConnectionProperty") {
            let connection = unsafeBitCast(main, to: MainConnection.self)()
            _ = unsafeBitCast(set, to: SetProperty.self)(connection, connection,
                                                         "SetsCursorInBackground" as CFString, kCFBooleanTrue)
        }
        seed = dlsym(symbols, "CGSCurrentCursorSeed").map { unsafeBitCast($0, to: CursorSeed.self) }
    }

    /// A small fingerprint of a pointer picture: size, hot spot and a coarse
    /// look at its pixels. Enough to tell the system's arrow from ours.
    static func mark(_ cursor: NSCursor) -> String {
        let size = cursor.image.size, spot = cursor.hotSpot
        guard let image = cursor.image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let ctx = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 64,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data else { return "\(size)\(spot)" }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 16))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        var alpha = 0, red = 0, green = 0
        for index in 0..<256 {
            alpha += Int(pixels[index * 4 + 3]) / 32
            red += Int(pixels[index * 4]) / 64
            green += Int(pixels[index * 4 + 1]) / 64
        }
        return "\(size)\(spot)-\(alpha)-\(red)-\(green)"
    }

    var active: Bool { timer != nil }

    /// The Christmas picture for a system pointer, or nil if it has none.
    func festive(for system: NSCursor) -> NSCursor? { festive(forMark: Self.mark(system)) }

    private func festive(forMark mark: String) -> NSCursor? {
        if let ready = made[mark] { return ready }
        guard let recipe = recipes[mark] else { return nil }
        let picture = recipe()
        made[mark] = picture
        originals[Self.mark(picture)] = originals[Self.mark(picture)] ?? NSCursor.arrow
        return picture
    }

    private func learn() {
        recipes = [:]; made = [:]; originals = [:]
        if let pointer = FestiveCursorArt.pointer {
            recipes[Self.mark(.arrow)] = { pointer }
            originals[Self.mark(pointer)] = .arrow
        }
        for pair in FestiveCursorArt.festivePairs() {
            let mark = Self.mark(pair.plain)
            // Two system pointers with the same picture (some resize
            // variants) share one Christmas picture.
            guard recipes[mark] == nil else { continue }
            let plain = pair.plain
            let recipe = pair.festive
            recipes[mark] = { [unowned self] in
                let picture = recipe()
                self.originals[Self.mark(picture)] = plain
                return picture
            }
        }
    }

    func start() {
        guard timer == nil, seed != nil else { return }
        learn()
        lastSeed = -1
        // Apps set their own pointer again as the mouse moves: answer each
        // movement straight away, and once more a moment later, after the
        // app under the mouse has had its turn.
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
                                             .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in self?.moved() }) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.moved(); return event
        }) {
            monitors.append(local)
        }
        // And a quiet check for changes without movement (a busy app, a
        // window opening under the mouse). One tiny system call a frame.
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.check() }
        timer.tolerance = 0.004
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        check()
    }

    private func moved() {
        lastSeed = -1
        check()
        for delay in [0.004, 0.012, 0.03] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.check() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
        lastSeed = -1
        // Leave the screen with the system's own pointer.
        if let current = NSCursor.currentSystem, let original = originals[Self.mark(current)] { original.set() }
    }

    /// Picks the style again, for example after it changed in the menu.
    func restyle() {
        guard active else { return }
        stop()
        start()
    }

    private func check() {
        guard let seed, timer != nil else { return }
        let now = seed()
        guard now != lastSeed else { return }
        lastSeed = now
        guard let current = NSCursor.currentSystem, let festive = festive(forMark: Self.mark(current)) else { return }
        festive.set()
        lastSeed = seed()
    }
}
