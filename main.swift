import AppKit
import ApplicationServices
import QuartzCore

private let binWidth: CGFloat = 8
private let heightBand: CGFloat = 48
private let floorY: CGFloat = 0.5
private let windowCornerRadius: CGFloat = 16
private let ledgeCapacity: CGFloat = 11
private let groundCapacity: CGFloat = 13
private let buildupRate: CGFloat = 1.20
private let distantSnowShare: CGFloat = 0.20
private let snowfallSideMargin: CGFloat = 20
// Background flakes stay airborne longer and take a larger share of the particle budget.
private let ledgeDeposit: CGFloat = 0.026 * buildupRate / 0.680
private let groundDeposit: CGFloat = 0.031 * buildupRate / 0.955
private let bladeTip: CGFloat = 67
private let plowLoadLimit: CGFloat = 12
private let snowmanBaseRadius: CGFloat = 24
private let buildStripHeight: CGFloat = 140
private let white = NSColor(calibratedRed: 0.95, green: 0.98, blue: 1, alpha: 1)
private let ice = NSColor(calibratedRed: 0.65, green: 0.80, blue: 0.94, alpha: 1)

private enum SnowPaint {
    static let drift = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            NSColor(srgbRed: 0.63, green: 0.77, blue: 0.88, alpha: 0.95).cgColor,
            NSColor(srgbRed: 0.83, green: 0.91, blue: 0.97, alpha: 0.98).cgColor,
            white.cgColor,
            NSColor.white.cgColor
        ] as CFArray, locations: [0, 0.34, 0.77, 1])!

    static let sphere = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            NSColor.white.cgColor,
            NSColor(srgbRed: 0.96, green: 0.98, blue: 1, alpha: 1).cgColor,
            NSColor(srgbRed: 0.84, green: 0.91, blue: 0.96, alpha: 1).cgColor,
            NSColor(srgbRed: 0.65, green: 0.79, blue: 0.90, alpha: 1).cgColor
        ] as CFArray, locations: [0, 0.34, 0.72, 1])!

    // One shaded sphere at the largest supported Retina size; rolling grains stay vector drawn.
    static let sphereImage: CGImage = {
        let ctx = CGContext(data:nil,width:148,height:148,bitsPerComponent:8,bytesPerRow:0,
                            space:CGColorSpace(name:CGColorSpace.sRGB)!,
                            bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x:2,y:2)
        ctx.addEllipse(in:CGRect(x:1,y:1,width:72,height:72))
        ctx.clip()
        ctx.drawRadialGradient(sphere,startCenter:CGPoint(x:37-36*0.36,y:37+36*0.44),startRadius:0,
                               endCenter:CGPoint(x:37+36*0.13,y:37-36*0.12),endRadius:36*1.03,
                               options:[.drawsAfterEndLocation])
        return ctx.makeImage()!
    }()

    static let lantern = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            NSColor(srgbRed: 1, green: 0.81, blue: 0.49, alpha: 0.30).cgColor,
            NSColor(srgbRed: 1, green: 0.72, blue: 0.40, alpha: 0.12).cgColor,
            NSColor(srgbRed: 1, green: 0.66, blue: 0.35, alpha: 0).cgColor
        ] as CFArray, locations: [0, 0.55, 1])!

    static let edge = NSColor(srgbRed: 0.30, green: 0.43, blue: 0.58, alpha: 0.44).cgColor
    static let glint = NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.79).cgColor
    static let grain = NSColor(srgbRed: 0.43, green: 0.61, blue: 0.76, alpha: 0.21).cgColor

    static func fillDrift(_ path: CGPath, base: CGFloat, crest: CGFloat, in ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(drift, start: CGPoint(x: 0, y: base),
                               end: CGPoint(x: 0, y: crest), options: [.drawsAfterEndLocation])
        ctx.restoreGState()
        ctx.setStrokeColor(edge)
        ctx.setLineWidth(0.65)
        ctx.addPath(path)
        ctx.strokePath()
    }
}

enum SnowDepth {
    case distant, middle, near

    static func random() -> Self {
        let layer = Double.random(in: 0..<1)
        if layer < distantSnowShare { return .distant }
        return layer < 0.76 ? .middle : .near
    }

    var scale: CGFloat {
        switch self {
        case .distant: 0.61
        case .middle: 1
        case .near: 1.12
        }
    }
}

struct Flake {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var radius: CGFloat
    var phase: CGFloat = .random(in: 0...6.28)
    var crystal = false
    var looseSnow: CGFloat = 0
    var push: CGVector = .zero
    var windVelocity: CGFloat = 0
    var hasBounced = false
    var depth: SnowDepth = .middle
    var frostShard = false
    var powderClump = false
}

private enum FlakeLanding {
    case missed
    case settled
    case rebounded(Flake)
}

struct SnowWind {
    private let prevailing: CGFloat
    private let shearPhase: CGFloat

    init(time: CGFloat) {
        let swell = sin(time * 0.19)
        let gust = max(0, sin(time * 0.38 - 0.86))
        prevailing = swell * (12 + 34 * gust * gust * gust)
        shearPhase = time * 0.43
    }

    func speed(at y: CGFloat) -> CGFloat {
        let nearGround = 0.42 + 0.58 * min(1, max(0, (y - floorY) / 160))
        return (prevailing + 5.5 * sin(y * 0.009 - shearPhase)) * nearGround
    }
}

private func firstContact(in rect: CGRect, from start: CGPoint, to end: CGPoint) -> CGFloat? {
    var enter: CGFloat = 0
    var exit: CGFloat = 1
    for (value, delta, lower, upper) in [
        (start.x, end.x - start.x, rect.minX, rect.maxX),
        (start.y, end.y - start.y, rect.minY, rect.maxY)
    ] {
        if delta == 0 {
            guard value >= lower && value <= upper else { return nil }
            continue
        }
        let a = (lower - value) / delta
        let b = (upper - value) / delta
        enter = max(enter, min(a, b))
        exit = min(exit, max(a, b))
        if enter > exit { return nil }
    }
    return enter
}

private struct SnowContact {
    let bin: Int
    let time: CGFloat
}

private func snowContact(from start: CGPoint, to end: CGPoint, base: CGFloat,
                         left: CGFloat, right: CGFloat, heights: [CGFloat],
                         exposed: [Bool]? = nil, looseDrift: Bool = false) -> SnowContact? {
    guard end.y < start.y, start.y >= base - 1,
          looseDrift || end.y <= base + max(ledgeCapacity, groundCapacity),
          !heights.isEmpty else { return nil }
    let fromX = max(left, min(start.x, end.x))
    let toX = min(right, max(start.x, end.x))
    guard fromX <= toX else { return nil }
    let first = min(heights.count - 1, Int((fromX - left) / binWidth))
    let last = min(heights.count - 1, Int((toX - left) / binWidth))
    let dx = end.x - start.x
    let fall = start.y - end.y
    let exitAtBase = max(0, (start.y - base) / fall)
    var contact: SnowContact?
    for index in first...last where exposed?[index] ?? true {
        let minX = left + CGFloat(index) * binWidth
        let maxX = min(minX + binWidth, right)
        let top = base + heights[index]
        guard end.y <= top else { continue }
        let timeAtTop = max(0, (start.y - top) / fall)
        let enter: CGFloat
        if dx == 0 {
            guard start.x >= minX, start.x < maxX else { continue }
            enter = timeAtTop
        } else {
            let a = (minX - start.x) / dx
            let b = (maxX - start.x) / dx
            enter = max(timeAtTop, min(a, b))
            guard enter <= max(a, b) else { continue }
        }
        guard enter <= 1, enter <= exitAtBase, enter < (contact?.time ?? .infinity) else { continue }
        contact = SnowContact(bin: index, time: enter)
    }
    return contact
}

struct CursorShape {
    let rows: [CGRect]
    let bounds: CGRect

    init(rows: [CGRect]) {
        self.rows = rows
        bounds = rows.reduce(.null) { $0.union($1) }
    }

    init?(_ cursor: NSCursor) {
        let image = cursor.image
        guard let pixels = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              image.size.width > 0, image.size.height > 0 else { return nil }
        let bitmap = NSBitmapImageRep(cgImage: pixels)
        let columns = min(24, max(1, Int(ceil(image.size.width / 2.5))))
        let lines = min(24, max(1, Int(ceil(image.size.height / 2.5))))
        let cellWidth = image.size.width / CGFloat(columns)
        let cellHeight = image.size.height / CGFloat(lines)
        let hotSpot = cursor.hotSpot
        var rows: [CGRect] = []
        for row in 0..<lines {
            var run: Int?
            let y = (2 * row + 1) * bitmap.pixelsHigh / (2 * lines)
            for column in 0...columns {
                let x = (2 * column + 1) * bitmap.pixelsWide / (2 * columns)
                if column < columns, (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.45 {
                    if run == nil { run = column }
                } else if let first = run {
                    rows.append(CGRect(x: CGFloat(first) * cellWidth - hotSpot.x,
                                       y: hotSpot.y - CGFloat(row + 1) * cellHeight,
                                       width: CGFloat(column - first) * cellWidth, height: cellHeight))
                    run = nil
                }
            }
        }
        self.init(rows: rows)
    }

    static let arrow = CursorShape(NSCursor.arrow)
}

struct CursorImpact {
    let time: CGFloat
    let normal: CGVector
}

private func tipContact(from start: CGPoint, to end: CGPoint, radius: CGFloat) -> CGFloat? {
    let c = start.x * start.x + start.y * start.y - radius * radius
    if c <= 0 { return 0 }
    let dx = end.x - start.x
    let dy = end.y - start.y
    let a = dx * dx + dy * dy
    let b = start.x * dx + start.y * dy
    let discriminant = b * b - a * c
    guard a > 0, b < 0, discriminant >= 0 else { return nil }
    let time = (-b - sqrt(discriminant)) / a
    return (0...1).contains(time) ? time : nil
}

struct CursorSweep {
    let start: CGPoint
    let end: CGPoint
    let shape: CursorShape
    var duration: CGFloat = 1.0 / 60

    var dx: CGFloat { end.x - start.x }
    var dy: CGFloat { end.y - start.y }
    var speed: CGFloat { hypot(dx, dy) }
    var frameScale: CGFloat { max(0.001, duration * 60) }
    var normalizedSpeed: CGFloat { speed / frameScale }
    var transportSpeed: CGFloat { min(1600, max(170, speed / max(0.001, duration) * 1.12 + 100)) }
    var coastDistance: CGFloat { min(82, max(0, abs(dx) / max(0.001, duration) - 450) * 0.04) }

    func leadingX(direction: Int, margin: CGFloat) -> CGFloat {
        let front = direction > 0 ? max(shape.bounds.maxX, margin) : min(shape.bounds.minX, -margin)
        return end.x + front + CGFloat(direction) * margin
    }

    func impact(at point: CGPoint, movingTo target: CGPoint? = nil, radius: CGFloat,
                forgiveness: CGFloat = 0) -> CursorImpact? {
        let destination = target ?? point
        let from = CGPoint(x: point.x - start.x, y: point.y - start.y)
        let to = CGPoint(x: destination.x - end.x, y: destination.y - end.y)
        let tip = CGRect(x: -forgiveness, y: -forgiveness, width: forgiveness * 2, height: forgiveness * 2)
        let extent = forgiveness > 0 ? shape.bounds.union(tip) : shape.bounds
        let pathBounds = CGRect(x: min(from.x, to.x), y: min(from.y, to.y),
                                width: abs(to.x - from.x), height: abs(to.y - from.y))
        guard extent.insetBy(dx: -radius, dy: -radius).intersects(pathBounds.insetBy(dx: -0.01, dy: -0.01)) else {
            return nil
        }
        var first = forgiveness > 0
            ? tipContact(from: from, to: to, radius: forgiveness + radius) : nil
        var surface: CGRect?
        for row in shape.rows {
            guard let time = firstContact(in: row.insetBy(dx: -radius, dy: -radius), from: from, to: to),
                  time < (first ?? .infinity) else { continue }
            first = time
            surface = row
        }
        guard let first else { return nil }
        let contactX = from.x + (to.x - from.x) * first
        let contactY = from.y + (to.y - from.y) * first
        var x = contactX
        var y = contactY
        if let surface {
            x -= min(surface.maxX, max(surface.minX, contactX))
            y -= min(surface.maxY, max(surface.minY, contactY))
            if abs(x) + abs(y) < 0.01 {
                x = contactX - shape.bounds.midX
                y = contactY - shape.bounds.midY
            }
        }
        let length = hypot(x, y)
        let normal: CGVector
        if length > 0.01 {
            normal = CGVector(dx: x / length, dy: y / length)
        } else if speed > 0.01 {
            normal = CGVector(dx: -dy / speed, dy: dx / speed)
        } else {
            normal = CGVector(dx: 1, dy: 0)
        }
        return CursorImpact(time: first, normal: normal)
    }
}

struct WindowSweep {
    let previous: CGRect
    let current: CGRect

    init?(from previous: CGRect, to current: CGRect) {
        guard previous != current else { return nil }
        self.previous = previous
        self.current = current
    }

    func impact(at point: CGPoint, edgeOnly: Bool = false) -> CGVector? {
        guard !previous.contains(point) else { return nil }
        let margin: CGFloat = 2
        let left = current.minX - previous.minX
        let right = current.maxX - previous.maxX
        let bottom = current.minY - previous.minY
        let top = current.maxY - previous.maxY
        var enter: CGFloat = 0
        var exit: CGFloat = 1
        var motion: CGVector?
        // A point is covered only when all four moving edges contain it at the same time.
        for (distance, rate, edgeMotion) in [
            (point.x - previous.minX, -left, CGVector(dx: left, dy: 0)),
            (previous.maxX - point.x, right, CGVector(dx: right, dy: 0)),
            (point.y - previous.minY, -bottom, CGVector(dx: 0, dy: bottom)),
            (previous.maxY - point.y, top, CGVector(dx: 0, dy: top))
        ] {
            if rate > 0, distance < 0 {
                let time = max(0, (-distance - margin) / rate)
                if time >= enter {
                    enter = time
                    motion = edgeMotion
                }
            } else if rate < 0 {
                exit = min(exit, (-distance - margin) / rate)
            } else if distance < -margin {
                return nil
            }
            if enter > exit { return nil }
        }
        guard let motion else { return nil }
        return !edgeOnly && previous.size == current.size ? CGVector(dx: left, dy: bottom) : motion
    }
}

private struct WindowSnowBurst {
    var amount: CGFloat
    var origin: CGPoint
    var sideways: CGFloat
    let started: CGFloat

    mutating func add(amount additional: CGFloat, at point: CGPoint, sideways velocity: CGFloat) {
        let blend = additional / (amount + additional)
        origin.x += (point.x - origin.x) * blend
        origin.y += (point.y - origin.y) * blend
        sideways += (velocity - sideways) * blend
        amount += additional
    }
}

private struct WindowSnowBurstKey: Hashable {
    let window: UInt32
    let segment: Int
}

struct SurfaceSnowTransfer {
    let window: UInt32?
    var position: CGPoint
    var targetX: CGFloat
    var frame: CGRect
    var direction: Int
    var speed: CGFloat
    var amount: CGFloat
    var lift: CGFloat = 0
    var lastSpill: CGFloat = -.infinity
}

struct SillRunoff {
    let window: UInt32
    var position: CGPoint
    var frame: CGRect
    let direction: CGFloat
    var amount: CGFloat

    var radius: CGFloat { min(11, max(0.85, sqrt(amount * binWidth / .pi))) }
}

struct Ledge {
    var frame: CGRect
    var windowFrame: CGRect
    var snow: [CGFloat]
    var exposed: [Bool]
    var lip: CGFloat
    var windowVelocity: CGFloat = 0
    var verticalVelocity: CGFloat = 0
    var lastVerticalMotion: CGFloat = -.infinity
    var lastWindowMotion: CGFloat = -.infinity
    var slideVelocity: CGFloat = 0

    func height(at x:CGFloat) -> CGFloat {
        guard !snow.isEmpty else { return lip }
        let position = max(0,min(CGFloat(snow.count-1),(x-frame.minX)/binWidth-0.5))
        let left = Int(position), right = min(snow.count-1,left+1)
        let fraction = position-CGFloat(left)
        return lip+snow[left]*(1-fraction)+snow[right]*fraction
    }

    func capacity(at index: Int) -> CGFloat {
        let x = min(frame.maxX - 0.1, frame.minX + (CGFloat(index) + 0.5) * binWidth)
        let distance = min(x - frame.minX, frame.maxX - x)
        return min(ledgeCapacity, max(1.2, distance * 0.84))
    }

    func edge(direction: CGFloat) -> CGFloat {
        direction < 0 ? windowFrame.minX : windowFrame.maxX
    }
}

func uncoveredRectangles(in bounds: CGRect, excluding windows: [CGRect]) -> [CGRect] {
    var visible = [bounds]
    for window in windows {
        var remaining: [CGRect] = []
        for region in visible {
            let overlap = region.intersection(window)
            if overlap.isEmpty {
                remaining.append(region)
                continue
            }
            let pieces = [
                CGRect(x: region.minX, y: region.minY, width: overlap.minX - region.minX, height: region.height),
                CGRect(x: overlap.maxX, y: region.minY, width: region.maxX - overlap.maxX, height: region.height),
                CGRect(x: overlap.minX, y: region.minY, width: overlap.width, height: overlap.minY - region.minY),
                CGRect(x: overlap.minX, y: overlap.maxY, width: overlap.width, height: region.maxY - overlap.maxY)
            ]
            remaining.append(contentsOf: pieces.filter { !$0.isEmpty })
        }
        visible = remaining
        if visible.isEmpty { break }
    }
    return visible
}

enum Scarf: String, Codable, CaseIterable {
    case berry, spruce, ocean, gold

    var title: String {
        switch self {
        case .berry: "Beerenrot"
        case .spruce: "Tannengrün"
        case .ocean: "Eisblau"
        case .gold: "Goldgelb"
        }
    }

    var color: NSColor {
        switch self {
        case .berry: NSColor(srgbRed: 0.76, green: 0.10, blue: 0.24, alpha: 1)
        case .spruce: NSColor(srgbRed: 0.10, green: 0.42, blue: 0.34, alpha: 1)
        case .ocean: NSColor(srgbRed: 0.14, green: 0.40, blue: 0.72, alpha: 1)
        case .gold: NSColor(srgbRed: 0.88, green: 0.52, blue: 0.06, alpha: 1)
        }
    }
}

struct Snowman: Codable {
    var x: Double
    var balls: Int
    var scarf: Scarf? = nil
}

struct SnowmanFall {
    let man: Snowman
    let started: CGFloat
    let duration: CGFloat

    func progress(at time: CGFloat) -> CGFloat { min(1, max(0, (time - started) / duration)) }

    static func angle(progress: CGFloat) -> CGFloat {
        -(0.13 * progress + 0.87 * progress * progress) * (.pi * 0.46)
    }

    func visibleBalls(at time: CGFloat) -> Int {
        let progress = progress(at: time)
        if progress < 0.73 { return 3 }
        if progress < 0.89 { return 2 }
        return 1
    }

    func pivot(in width: CGFloat) -> CGPoint { CGPoint(x: man.x * width + 7, y: floorY) }

    func pieceCenter(height: CGFloat, at progress: CGFloat, width: CGFloat) -> CGPoint {
        let pivot = pivot(in: width)
        let angle = Self.angle(progress: progress)
        return CGPoint(x: pivot.x - 7 * cos(angle) - height * sin(angle),
                       y: pivot.y - 7 * sin(angle) + height * cos(angle))
    }
}

private struct SnowballPlacement {
    let x: Double
    let ball: Int
    let started: CGFloat

    static let fallTime: CGFloat = 0.18
    static let duration: CGFloat = 0.35

    func offset(at time: CGFloat) -> CGFloat {
        let elapsed = max(0, time - started)
        if elapsed < Self.fallTime {
            let progress = elapsed / Self.fallTime
            return (ball == 1 ? 19 : 14) * (1 - progress * progress)
        }
        let settle = min(1, (elapsed - Self.fallTime) / (Self.duration - Self.fallTime))
        return -2.2 * sin(settle * 2 * .pi) * (1 - settle)
    }
}

final class SnowView: FestiveCursorSurface {
    let workshop = SnowWorkshop()
    let fight = SnowballFight()
    let christmasScene = ChristmasScene()
    var christmasMomentActive: Bool { christmasScene.isAnimating }
    /// Off only in the checks that exercise the visitors themselves.
    static var visitorsNeedDoors = true
    func inviteChristmasMoment() { guard christmas else { return }; christmasScene.inviteNextMoment() }
    var fightEligibleCount:Int {
        fight.eligible(in:workshop,visible:{ [self] point in !windowFrames.contains { $0.contains(point) } }).count
    }
    @discardableResult func startSnowballFight() -> Bool {
        fight.start(in:workshop,visible:{ [self] point in !windowFrames.contains { $0.contains(point) } })
    }
    func stopSnowballFight() {
        fight.stop(emit:{ [self] in breakPackedSnowball($0) })
    }
    private var workshopPointerShape = CursorShape.arrow
    private var sheens: [NSColor: CGGradient] = [:]
    // The advent village lives behind the work windows.
    var villageEnabled = true
    var adventCalendar = AdventCalendar()
    /// Tests and previews pin the date; everything else follows the clock.
    var adventDate: Date?
    private(set) var advent = AdventSeason()
    private(set) var adventSky = AdventSky()
    private var adventLayout: AdventLayout?
    // The still parts of the valley are expensive to draw and change only when
    // a door is opened, so they are kept as one image.
    private var adventBackdrop: CGImage?
    /// The picture is out of date (a new minute, a door opened). In the app
    /// the new one is painted on a background thread while the old one stays
    /// up: painting it took about half a second, and on the main thread that
    /// froze the snow once a minute.
    private var backdropStale = false
    private var backdropBuilding = false
    private static let backdropQueue = DispatchQueue(label: "schneetag.backdrop", qos: .userInitiated)
    /// Hands the still valley to the wallpaper window that lies under the
    /// desktop widgets, so translucent widgets show the valley behind them
    /// and not the old desktop picture.
    var onBackdrop: ((CGImage?) -> Void)?
    private var publishedBackdrop: CGImage?
    var wallpaperPanel: Overlay?
    /// A click-through panel just above the Dock: the ground snow, snowmen
    /// and the plows are drawn there inside the Dock's strip, so they lie in
    /// front of the icon bar instead of disappearing behind it.
    var dockPanel: Overlay?
    weak var dockView: NSView?

    /// The strips the Dock can cover: what the visible frame leaves free at
    /// the bottom and at the sides.
    var dockBands: [CGRect] {
        guard let safe = safeArea else { return [] }
        var bands: [CGRect] = []
        if safe.minY > bounds.minY + 0.5 {
            bands.append(CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: safe.minY - bounds.minY))
        }
        if safe.minX > bounds.minX + 0.5 {
            bands.append(CGRect(x: bounds.minX, y: bounds.minY, width: safe.minX - bounds.minX, height: bounds.height))
        }
        if safe.maxX < bounds.maxX - 0.5 {
            bands.append(CGRect(x: safe.maxX, y: bounds.minY, width: bounds.maxX - safe.maxX, height: bounds.height))
        }
        return bands
    }
    private var adventCheckedAt: CGFloat = -1000
    private var flurryUntil: CGFloat = -1000
    private var lastCursor: CGPoint?
    /// What the door just opened brought, shown for a few seconds over the valley.
    private var doorNews: (day: Int, title: String, start: CGFloat)?
    var workshopEnabled = true
    var flakes: [Flake] = []
    private var flakeSprites: [Int: CGImage] = [:]
    private var flakeSpriteScale: CGFloat = 0

    /// A pre-rendered round flake: fill plus the faint outline the old path
    /// drawing gave it. Radii are bucketed to a quarter point.
    func flakeSprite(style: Int, radius: CGFloat) -> (CGImage, CGFloat) {
        let scale = window?.backingScaleFactor ?? 2
        if scale != flakeSpriteScale { flakeSprites.removeAll(); flakeSpriteScale = scale }
        let bucket = max(1, Int((radius * 4).rounded()))
        let r = CGFloat(bucket) / 4
        let extent = r + 1
        let key = style * 10_000 + bucket
        if let sprite = flakeSprites[key] { return (sprite, extent) }
        let pixels = Int((extent * 2 * scale).rounded(.up))
        let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: CGFloat(pixels) / (extent * 2), y: CGFloat(pixels) / (extent * 2))
        let circle = CGRect(x: 1, y: 1, width: r * 2, height: r * 2)
        let fills = [ice.withAlphaComponent(0.51), white.withAlphaComponent(0.72), white.withAlphaComponent(0.94), white]
        ctx.setFillColor(fills[style].cgColor)
        ctx.fillEllipse(in: circle)
        if style > 0 {
            ctx.setStrokeColor(NSColor(calibratedWhite: 0.17, alpha: 0.27).cgColor)
            ctx.setLineWidth(0.7)
            ctx.strokeEllipse(in: circle)
        }
        let sprite = ctx.makeImage()!
        flakeSprites[key] = sprite
        return (sprite, extent)
    }
    var ledges: [UInt32: Ledge] = [:]
    private var dormantLedges: [UInt32:Ledge] = [:]
    private(set) var runoff: [SillRunoff] = []
    private(set) var surfaceTransfers: [SurfaceSnowTransfer] = []
    private var windowSnowBursts: [WindowSnowBurstKey: WindowSnowBurst] = [:]
    private var windowFrames: [CGRect] = []
    private var previousWindows: [UInt32: CGRect] = [:]
    private var previousWindowOrder: [UInt32]?
    private var movingLedges: Set<UInt32> = []
    private var exposedDesktop: [CGRect]?
    private var previousBannerFrames: [CGRect] = []
    private var previousWidgetFrames: [CGRect] = []
    /// Where the valley may be painted: the desktop minus windows and minus
    /// desktop widgets. Snow still falls over the widgets, only not over
    /// windows, so this is kept apart from `exposedDesktop`.
    private var villageDesktop: [CGRect]?
    func isVillageVisible(_ point: CGPoint) -> Bool {
        (villageDesktop ?? [bounds]).contains { $0.contains(point) }
    }
    var christmas = false {
        didSet {
            festiveCursor = christmas && desktopPointer
            if christmas { refreshAdvent(force: true) } else { christmasScene.reset() }
        }
    }
    private var shelves: [UInt32] = []
    private var shelvesByHeight: [[UInt32]] = []
    private var masksByHeight: [[CGRect]] = []
    private var previousCursor: CGPoint?
    private var sampledCursor: CGPoint?
    private var simulationRemainder: CGFloat = 0
    var ground: [CGFloat] = []
    var snowmen: [Snowman] = []
    private(set) var fallingSnowmen: [SnowmanFall] = []
    private var placements: [SnowballPlacement] = []
    var building = false
    private var buildPointer: CGPoint?
    var finishBuild: (() -> Void)?
    var plowEnabled = true {
        didSet {
            if !plowEnabled {
                unloadPlow()
                plowImpact = 0
            }
        }
    }
    let heavyPlow = HeavyPlow()
    var plowX: CGFloat = -70
    private(set) var plowLoad: CGFloat = 0
    private(set) var plowRemoved: CGFloat = 0
    private(set) var plowSpeed: CGFloat = 76
    private var visiblePlowLoad: CGFloat = 0
    private var smallPlowOpacity: CGFloat = 1
    private var heavyWasActive = false
    private var plowImpact: CGFloat = 0
    var scarf: Scarf = .berry {
        didSet {
            if draft != nil { snowmen[snowmen.count - 1].scarf = scarf }
        }
    }
    var time: CGFloat = 0
    var spawnBudget: CGFloat = 0
    var seeded = false
    var density: CGFloat = 1
    var displayID: UInt32 = 0
    private var snowmanKey: String { "snowmen.\(displayID)" }

    func restoreSnowmen() {
        workshop.storageKey = "packedSnowballs.\(displayID)"
        workshop.restore()
        if let data = UserDefaults.standard.data(forKey: snowmanKey),
           let saved = try? JSONDecoder().decode([Snowman].self, from: data) {
            snowmen = saved.filter { $0.balls == 3 }
        }
    }

    func saveSnowmen() {
        let data = try? JSONEncoder().encode(snowmen.filter { $0.balls == 3 })
        UserDefaults.standard.set(data, forKey: snowmanKey)
    }

    var shouldAnimate: Bool {
        building || exposedDesktop?.isEmpty != true
            || (christmas && (!ledges.isEmpty || christmasScene.isAnimating))
    }

    func isVisible(_ point: CGPoint) -> Bool { !windowFrames.contains { $0.contains(point) } }

    /// The whole desktop is the valley now; the snow in front is unaffected.
    var villageBounds: CGRect { bounds }

    /// What the menu says about today's door.
    var adventStatus: String {
        let season = adventCalendar.season(at: adventDate ?? Date())
        guard let today = season.today else { return "Die Türchen öffnen ab 1. Dezember" }
        if season.isOpen(today) { return "Türchen \(today): \(AdventGift.forDay(today).title)" }
        return "Türchen \(today) wartet im Dorf"
    }

    func refreshAdvent(force: Bool = false) {
        guard force || time - adventCheckedAt > 5 else { return }
        adventCheckedAt = time
        let now = adventDate ?? Date()
        let sky = AdventSky.at(now)
        if sky.stamp != adventSky.stamp {
            adventSky = sky
            backdropStale = true
            needsDisplay = true
        }
        let season = adventCalendar.season(at: now)
        if season != advent {
            advent = season
            backdropStale = true
            needsDisplay = true
        }
        if adventLayout?.bounds != bounds {
            adventLayout = bounds.isEmpty ? nil : AdventLayout.make(in: bounds)
            adventBackdrop = nil
        }
    }

    /// The door a click would open — only today's, so the rest of the desktop
    /// keeps its clicks.
    func adventDoor(at point: CGPoint) -> Int? {
        guard christmas, villageEnabled, let layout = adventLayout, isVisible(point) else { return nil }
        return layout.doors.first { advent.canOpen($0.day) && $0.rect.insetBy(dx: -4, dy: -4).contains(point) }?.day
    }

    /// A banner above the opened door: the number and what it brought. It
    /// rises in, stays a moment and fades away, with a burst of gold around
    /// the door.
    private func drawDoorNews(in ctx: CGContext) {
        guard let news = doorNews, let layout = adventLayout,
              let door = layout.doors.first(where: { $0.day == news.day }) else { return }
        let age = time - news.start
        let duration: CGFloat = 8
        guard age < duration else { doorNews = nil; return }
        let fade = min(1, age * 3) * min(1, (duration - age) / 1.2)
        // Gold sparks flying out of the doorway.
        for spark in 0..<14 {
            let angle = CGFloat(spark) / 14 * .pi * 2
            let reach = door.rect.width * (1 + age * 2.2)
            let point = CGPoint(x: door.rect.midX + cos(angle) * reach,
                                y: door.rect.midY + sin(angle) * reach * 0.8 + age * 6)
            let alpha = max(0, 1 - age / 2.2)
            guard alpha > 0 else { break }
            AdventPaint.star(ctx, point.x, point.y, 2.6 + door.rect.width * 0.06, 0xffd27a, alpha: alpha)
        }
        // A trail of light from the door to where the gift appears, so the
        // eye is led straight to it, and a burst of stars when it arrives.
        let gift = AdventGift.forDay(news.day)
        let from = CGPoint(x: door.rect.midX, y: door.rect.midY)
        let to = AdventVillage.giftFocus(gift, layout: layout)
        let control = CGPoint(x: (from.x + to.x) / 2, y: max(from.y, to.y) + bounds.height * 0.18)
        func curve(_ t: CGFloat) -> CGPoint {
            let u = 1 - t
            return CGPoint(x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
                           y: u * u * from.y + 2 * u * t * control.y + t * t * to.y)
        }
        let flight: CGFloat = 1.5
        if age < flight + 0.4 {
            let head = min(1, age / flight)
            for k in 0..<16 {
                let t = head - CGFloat(k) * 0.025
                guard t > 0 else { break }
                let p = curve(t)
                let a = (1 - CGFloat(k) / 16) * (age < flight ? 1 : max(0, 1 - (age - flight) / 0.4))
                AdventPaint.glow(ctx, at: p, radius: 10 - CGFloat(k) * 0.4, 0xffd27a, 0.5 * a)
                if k == 0 { AdventPaint.star(ctx, p.x, p.y, 7, 0xfff2c4, alpha: a) }
            }
        }
        if age > flight - 0.1, age < flight + 2.2 {
            let b = (age - flight + 0.1) / 2.3
            AdventPaint.glow(ctx, at: to, radius: 30 + b * 50, 0xffe6a8, 0.6 * (1 - b))
            for k in 0..<16 {
                let angle = CGFloat(k) / 16 * .pi * 2
                let reach = 14 + b * 70
                AdventPaint.star(ctx, to.x + cos(angle) * reach, to.y + sin(angle) * reach * 0.75, 4 * (1 - b) + 1.5, 0xffd27a, alpha: 1 - b)
            }
        }
        // The banner: big, at the top of the screen, for all to read.
        let top = (safeArea ?? bounds).maxY
        let small = NSAttributedString(string: "Türchen \(news.day)", attributes: [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor(srgbRed: 0.62, green: 0.18, blue: 0.10, alpha: fade)
        ])
        let label = NSAttributedString(string: news.title, attributes: [
            .font: NSFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: NSColor(srgbRed: 0.30, green: 0.10, blue: 0.06, alpha: fade)
        ])
        let size = label.size(), smallSize = small.size()
        let rise = (1 - min(1, age * 2.5)) * 14
        let width = max(size.width, smallSize.width) + 64
        let height = size.height + smallSize.height + 26
        let box = CGRect(x: bounds.midX - width / 2, y: top - height - 36 + rise, width: width, height: height)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 18, color: NSColor.black.withAlphaComponent(0.4 * fade).cgColor)
        ctx.setFillColor(NSColor(srgbRed: 1, green: 0.96, blue: 0.86, alpha: 0.97 * fade).cgColor)
        ctx.addPath(CGPath(roundedRect: box, cornerWidth: 22, cornerHeight: 22, transform: nil))
        ctx.fillPath()
        ctx.restoreGState()
        ctx.setStrokeColor(NSColor(srgbRed: 0.85, green: 0.62, blue: 0.22, alpha: fade).cgColor)
        ctx.setLineWidth(2)
        ctx.addPath(CGPath(roundedRect: box.insetBy(dx: 4, dy: 4), cornerWidth: 18, cornerHeight: 18, transform: nil))
        ctx.strokePath()
        for side: CGFloat in [-1, 1] {
            let twinkle = 0.8 + 0.2 * sin(time * 4 + side)
            AdventPaint.star(ctx, box.midX + side * (box.width / 2 - 26), box.midY, 9 * twinkle, 0xe8b440, alpha: fade)
        }
        small.draw(at: CGPoint(x: box.midX - smallSize.width / 2, y: box.maxY - 12 - smallSize.height))
        label.draw(at: CGPoint(x: box.midX - size.width / 2, y: box.minY + 12))
        needsDisplay = true
    }

    func adventDoorCenter(_ day: Int) -> CGPoint? {
        adventLayout?.doors.first { $0.day == day }.map { CGPoint(x: $0.rect.midX, y: $0.rect.midY) }
    }

    @discardableResult func openAdventDoor(_ day: Int) -> AdventGift? {
        guard let gift = adventCalendar.open(day, at: adventDate ?? Date()) else { return nil }
        backdropStale = true
        refreshAdvent(force: true)
        if gift == .flurry { flurryUntil = time + 9 }
        if gift == .horseSleigh { AdventVillage.cueHorseSleigh(at: time) }
        if gift == .bells { AdventVillage.bellsCue = Date() }
        if gift == .balloon { AdventVillage.balloonCue = time }
        // Rudolph and Santa set off at once when their door opens.
        if gift == .rudolph || gift == .sleigh, christmas { christmasScene.inviteNextMoment() }
        doorNews = (day, gift.title, time)
        needsDisplay = true
        return gift
    }

    /// In Christmas mode the snow layer may take the pointer over free desktop
    /// so the candy cursor applies there. It costs the desktop's own clicks, so
    /// it stays switchable and never reaches the menu bar or the Dock.
    var desktopPointer = false {
        didSet { festiveCursor = christmas && desktopPointer }
    }
    var safeArea: CGRect?
    func ownsDesktopPointer(at point: CGPoint) -> Bool {
        guard christmas, desktopPointer, (safeArea ?? bounds).contains(point) else { return false }
        return isVisible(point)
    }

    private func groundHeight(at x: CGFloat) -> CGFloat {
        guard !ground.isEmpty else { return floorY }
        let position = max(0, min(CGFloat(ground.count - 1), x / binWidth - 0.5))
        let left = Int(position), right = min(ground.count - 1, left + 1)
        let fraction = position - CGFloat(left)
        return floorY + ground[left] * (1 - fraction) + ground[right] * fraction
    }

    /// The present a click would open, if any.
    func giftUnderPointer(at point: CGPoint) -> UUID? {
        guard christmas else { return nil }
        return christmasScene.gift(at: point, visible: isVisible)
    }

    func syncWindows(_ windows: [(UInt32, CGRect)], banners: [CGRect] = [], widgets: [CGRect] = [],
                     interval: CGFloat = 1.0 / 30, existingWindows: Set<UInt32>? = nil) {
        let order = windows.map { $0.0 }
        let active = Set(windows.compactMap { id, frame in
            frame.maxY >= 50 && frame.width >= 24 && frame.intersects(bounds) ? id : nil
        })
        let existing = existingWindows ?? Set(order)
        workshop.suspendSurfaces(existing.subtracting(active))
        for id in Array(ledges.keys) where !active.contains(id) {
            if var ledge = ledges.removeValue(forKey:id), existing.contains(id) {
                ledge.windowVelocity = 0; ledge.verticalVelocity = 0; ledge.slideVelocity = 0
                dormantLedges[id] = ledge
            }
        }
        for id in Array(dormantLedges.keys) where !existing.contains(id) {
            guard let ledge = dormantLedges.removeValue(forKey:id) else { continue }
            for i in ledge.snow.indices where ledge.snow[i] > 0 {
                dropSnow(at:CGPoint(x:ledge.frame.minX+(CGFloat(i)+0.5)*binWidth,y:ledge.lip+2),
                         amount:ledge.snow[i],sideways:0,vertical:-30,powder:true)
            }
        }
        let resumed = active.intersection(dormantLedges.keys)
        guard order != previousWindowOrder || banners != previousBannerFrames || widgets != previousWidgetFrames
                || windows.contains(where: { previousWindows[$0.0] != $0.1 }) else {
            for id in Array(movingLedges) {
                guard var ledge = ledges[id], time - ledge.lastWindowMotion >= 0.050 else { continue }
                ledge.slideVelocity = min(250, max(-250, ledge.slideVelocity + ledge.windowVelocity * 0.40))
                ledge.windowVelocity = 0
                ledges[id] = ledge
                movingLedges.remove(id)
            }
            return
        }
        movingLedges.removeAll(keepingCapacity: true)
        let sampleTime = max(1.0 / 120, interval)
        let wasVisible = shouldAnimate
        previousBannerFrames = banners
        previousWidgetFrames = widgets
        windowFrames = windows.map { $0.1 } + banners
        exposedDesktop = uncoveredRectangles(in: bounds, excluding: windowFrames)
        villageDesktop = widgets.isEmpty ? nil : uncoveredRectangles(in: bounds, excluding: windowFrames + widgets)
        let visible = shouldAnimate
        let simulateMotion = wasVisible && visible
        if wasVisible != visible {
            resetCursor()
            needsDisplay = true
        }
        var next: [UInt32: Ledge] = [:]
        var above = banners
        var movingAbove: [(id: UInt32, sweep: WindowSweep)] = []
        var resizedLedges: [UInt32] = []
        for (id, frame) in windows {
            defer {
                above.append(frame)
                if simulateMotion, !resumed.contains(id), let previous = previousWindows[id], let sweep = WindowSweep(from: previous, to: frame) {
                    movingAbove.append((id, sweep))
                }
            }
            guard frame.maxY >= 50, frame.width >= 24, frame.intersects(bounds) else { continue }
            let lip = min(frame.maxY, bounds.maxY)
            // Quartz reports the enclosing rectangle. Keep the sill between the rounded corners.
            let sill = frame.insetBy(dx: min(windowCornerRadius, frame.width / 4), dy: 0)
            let count = Int(ceil(sill.width / binWidth))
            let exposed = (0..<count).map { index in
                let x = min(sill.maxX - 0.1, sill.minX + (CGFloat(index) + 0.5) * binWidth)
                let point = CGPoint(x: x, y: min(lip + 0.5, bounds.maxY - 0.5))
                return point.x >= 0 && point.x <= bounds.width && !above.contains { $0.contains(point) }
            }
            var ledge = Ledge(frame: sill, windowFrame: frame, snow: Array(repeating: 0, count: count),
                              exposed: exposed, lip: lip)
            if let old = ledges[id] ?? dormantLedges.removeValue(forKey:id) {
                let resized = sill.width != old.frame.width
                let trackMotion = simulateMotion && !resumed.contains(id) && previousWindows[id] != nil
                let dx = trackMotion && !resized ? (sill.minX - old.frame.minX) / sampleTime : 0
                let dy = trackMotion ? (frame.maxY - old.frame.maxY) / sampleTime : 0
                ledge.lastWindowMotion = dx != 0 ? time : old.lastWindowMotion
                let velocity: CGFloat
                if !trackMotion || resized {
                    velocity = 0
                } else if dx != 0 {
                    let measured = min(850, max(-850, dx))
                    let response = 1 - exp(-25 * sampleTime)
                    velocity = old.windowVelocity + (measured - old.windowVelocity) * response
                } else {
                    velocity = time - old.lastWindowMotion < 0.050 ? old.windowVelocity : 0
                }
                let impulse = (old.windowVelocity - velocity) * 0.40
                ledge.windowVelocity = velocity
                ledge.slideVelocity = trackMotion ? min(250, max(-250, old.slideVelocity + impulse)) : 0
                if velocity != 0 { movingLedges.insert(id) }

                // A moving ledge supports its snow. Sudden changes in speed loosen it.
                ledge.lastVerticalMotion = dy != 0 ? time : old.lastVerticalMotion
                let previousVertical = time - old.lastVerticalMotion < 0.050 ? old.verticalVelocity : 0
                let vertical = min(1120, max(-1120, dy))
                let verticalResponse = 1 - exp(-32 * sampleTime)
                ledge.verticalVelocity = dy != 0 ? previousVertical + (vertical - previousVertical) * verticalResponse
                    : previousVertical
                let verticalShock = dy != 0 ? abs(ledge.verticalVelocity - previousVertical) : 0
                let verticalShake = min(0.22, max(0, verticalShock - 95) / 2700)
                for i in old.snow.indices where old.snow[i] > 0 {
                    let amount = old.snow[i]
                    let point = CGPoint(x: min(old.frame.maxX - 0.1, old.frame.minX + (CGFloat(i) + 0.5) * binWidth),
                                        y: old.lip + max(1, amount / 2))
                    let collision = old.exposed[i] ? movingAbove.lazy.compactMap { entry -> (UInt32, WindowSweep, CGVector)? in
                        guard let impact = entry.sweep.impact(at: point) else { return nil }
                        return (entry.id, entry.sweep, impact)
                    }.first : nil
                    let impact = collision?.2
                    let shedFraction: CGFloat
                    if let impact {
                        let speed = hypot(impact.dx, impact.dy) / sampleTime
                        shedFraction = impact.dx != 0 || impact.dy > 0 ? 1 : min(1, speed / 440)
                    } else {
                        shedFraction = old.exposed[i] ? verticalShake : 0
                    }
                    var released = amount * shedFraction
                    let remaining = amount - released
                    if resized {
                        released += redistributeSnow(remaining, from: old.frame, bin: i, onto: &ledge)
                    } else {
                        ledge.snow[i] = remaining
                    }
                    if let collision, collision.2.dy > 0, var receiver = next[collision.0] {
                        let receiverIndex = min(receiver.snow.count - 1, max(0, Int((point.x - receiver.frame.minX) / binWidth)))
                        if receiver.exposed[receiverIndex] {
                            receiver.snow[receiverIndex] += released
                            next[collision.0] = receiver
                            resizedLedges.append(collision.0)
                            released = 0
                        }
                    } else if let collision, collision.2.dx != 0 {
                        let direction: CGFloat = collision.2.dx < 0 ? -1 : 1
                        let front = direction < 0 ? collision.1.current.minX - 5 : collision.1.current.maxX + 5
                        if front > ledge.frame.minX, front < ledge.frame.maxX {
                            let dest = min(ledge.snow.count - 1, max(0, Int((front - ledge.frame.minX) / binWidth)))
                            if ledge.exposed[dest] {
                                let surface = CGRect(x: ledge.frame.minX, y: ledge.lip, width: ledge.frame.width, height: 1)
                                if queueSurfaceSnow(on: id, from: CGPoint(x: front, y: ledge.lip),
                                                    to: front + direction * 8, frame: surface, direction: direction < 0 ? -1 : 1,
                                                    amount: released, travelSpeed: 220) { released = 0 }
                            }
                        }
                    }
                    if released > 0 {
                        let sideways = impact.map { $0.dx / sampleTime * 0.36 } ?? -velocity * 0.16
                        collectWindowSnow(on: id, amount: released, at: point, sideways: sideways)
                    }
                }
                if resized, ledge.snow.contains(where: { $0 > ledgeCapacity }) { resizedLedges.append(id) }
            }
            next[id] = ledge
        }
        if simulateMotion, workshopEnabled {
            let movements = windows.compactMap { id, frame -> (UInt32, WindowSweep)? in
                guard !resumed.contains(id), let previous = previousWindows[id], let sweep = WindowSweep(from:previous,to:frame) else { return nil }
                return (id,sweep)
            }
            workshop.displace(by:movements,order:order,ledges:next,interval:sampleTime)
        }
        ledges = next
        for id in resizedLedges { settleOverflow(on: id) }
        shelves = next.keys.sorted { next[$0]!.lip > next[$1]!.lip }
        indexWindowHeights()
        previousWindowOrder = order
        previousWindows = Dictionary(uniqueKeysWithValues: windows)
    }

    private func indexWindowHeights() {
        let count = max(1, Int(ceil(bounds.height / heightBand)))
        shelvesByHeight = Array(repeating: [], count: count)
        masksByHeight = Array(repeating: [], count: count)
        for id in shelves {
            guard let ledge = ledges[id] else { continue }
            shelvesByHeight[band(at: ledge.lip, count: count)].append(id)
        }
        for frame in windowFrames where frame.maxY > 0 && frame.minY < bounds.height {
            let first = band(at: frame.minY, count: count)
            let last = band(at: frame.maxY, count: count)
            for index in first...last { masksByHeight[index].append(frame) }
        }
    }

    private func band(at y: CGFloat, count: Int) -> Int {
        min(count - 1, Int(max(0, y) / heightBand))
    }

    private func masks(at y: CGFloat) -> [CGRect] {
        guard !masksByHeight.isEmpty else { return [] }
        return masksByHeight[band(at: y, count: masksByHeight.count)]
    }

    private func redistributeSnow(_ amount: CGFloat, from oldFrame: CGRect, bin: Int, onto ledge: inout Ledge) -> CGFloat {
        guard amount > 0 else { return 0 }
        let oldStart = oldFrame.minX + CGFloat(bin) * binWidth
        let oldEnd = min(oldFrame.maxX, oldStart + binWidth)
        let overlapStart = max(oldStart, ledge.frame.minX)
        let overlapEnd = min(oldEnd, ledge.frame.maxX)
        guard overlapStart < overlapEnd else { return amount }
        let first = Int((overlapStart - ledge.frame.minX) / binWidth)
        let last = min(ledge.snow.count - 1, Int((overlapEnd - ledge.frame.minX) / binWidth))
        let density = amount / (oldEnd - oldStart)
        for index in first...last {
            let start = ledge.frame.minX + CGFloat(index) * binWidth
            let width = max(0, min(overlapEnd, start + binWidth) - max(overlapStart, start))
            ledge.snow[index] += width * density
        }
        return max(0, amount - (overlapEnd - overlapStart) * density)
    }

    private func collectWindowSnow(on id: UInt32, amount: CGFloat, at point: CGPoint, sideways: CGFloat) {
        let key = WindowSnowBurstKey(window: id, segment: Int(floor(point.x / 46)))
        if var burst = windowSnowBursts[key] {
            burst.add(amount: amount, at: point, sideways: sideways)
            windowSnowBursts[key] = burst
        } else {
            windowSnowBursts[key] = WindowSnowBurst(amount: amount, origin: point, sideways: sideways, started: time)
        }
    }

    private func releaseWindowSnow() {
        guard !windowSnowBursts.isEmpty else { return }
        let ready = windowSnowBursts.compactMap { key, burst in
            !workshop.suspendedSurfaces.contains(key.window)
                && time - burst.started >= (burst.amount > 2.8 ? 0.050 : 0.092) ? key : nil
        }
        for key in ready {
            guard let burst = windowSnowBursts.removeValue(forKey: key) else { continue }
            let sideways = min(58, max(-58, burst.sideways * 0.44))
            dropSnow(at: burst.origin, amount: burst.amount, sideways: sideways, vertical: -48, powder: true)
        }
    }

    private func dropSnow(at point: CGPoint, amount: CGFloat, sideways: CGFloat,
                          vertical: CGFloat = -200, powder: Bool = false) {
        guard flakes.count < 960 else {
            if !ground.isEmpty {
                let index = min(ground.count - 1, Int(max(0, point.x) / binWidth))
                ground[index] += amount
            }
            return
        }
        flakes.append(Flake(x: point.x, y: point.y, vx: min(185, max(-185, sideways)),
                            vy: vertical, radius: min(9, max(0.85, sqrt(amount * binWidth / .pi))),
                            looseSnow: amount, powderClump: powder))
    }

    func shedFrost(from frame: CGRect, strength: CGFloat) {
        let left = max(bounds.minX + 2, frame.minX + 10)
        let right = min(bounds.maxX - 2, frame.maxX - 10)
        guard strength > 0, left < right, frame.maxY > bounds.minY else { return }
        let y = min(bounds.maxY - 1, frame.maxY + 1)
        let count = min(17, max(4, Int(strength * 16)))
        for index in 0..<count where flakes.count < 960 {
            let x = left + (right - left) * (CGFloat(index) + 0.5) / CGFloat(count)
            let shard = index % 3 == 0
            flakes.append(Flake(x: x, y: y - CGFloat(index % 4) * 1.2,
                                vx: .random(in: -26...24), vy: .random(in: -120 ... -24),
                                radius: shard ? .random(in: 1.5...2.7) : .random(in: 0.9...1.8),
                                looseSnow: .random(in: 0.035...0.12) * strength, frostShard: shard))
        }
        needsDisplay = true
    }

    func resetCursor() {
        previousCursor = nil
        sampledCursor = nil
        simulationRemainder = 0
    }

    func resetMotionTracking() {
        resetCursor()
        previousWindowOrder = nil
        previousWindows.removeAll()
        movingLedges.removeAll()
    }

    func clearSnow() {
        flakes.removeAll()
        fallingSnowmen.removeAll()
        ledges.removeAll()
        dormantLedges.removeAll()
        workshop.suspendSurfaces([])
        runoff.removeAll()
        surfaceTransfers.removeAll()
        windowSnowBursts.removeAll()
        shelves.removeAll()
        shelvesByHeight.removeAll()
        ground.removeAll()
        workshop.clear()
        fight.stop(emit:{_ in})
        resetPlowLoad()
        plowRemoved = 0
        plowSpeed = 76
        heavyPlow.clear()
        smallPlowOpacity = 1
        heavyWasActive = false
        previousWindowOrder = nil
        previousWindows.removeAll()
        movingLedges.removeAll()
    }

    func step(_ dt: CGFloat, cursor: CGPoint? = nil, shape: CursorShape? = CursorShape.arrow) {
        guard dt.isFinite, dt >= 0 else { resetCursor(); return }
        workshopPointerShape = shape
        if dt == 0 {
            simulate(0, cursor: cursor, shape: shape)
            sampledCursor = cursor
            return
        }
        // Fixed physics steps keep pressure, contact and reversal independent of render timing.
        let interval: CGFloat = 1.0 / 120
        let origin = sampledCursor ?? cursor
        var nextSample = interval - simulationRemainder
        simulationRemainder += dt
        while simulationRemainder >= interval - 0.0000001 {
            let fraction = min(1, max(0, nextSample / dt))
            let position: CGPoint?
            if let origin, let cursor {
                position = CGPoint(x: origin.x + (cursor.x - origin.x) * fraction,
                                   y: origin.y + (cursor.y - origin.y) * fraction)
            } else {
                position = cursor
            }
            simulate(interval, cursor: position, shape: shape)
            simulationRemainder = max(0, simulationRemainder - interval)
            nextSample += interval
        }
        sampledCursor = cursor
        if wantsInteraction(at: cursor) { window?.invalidateCursorRects(for: self) }
    }

    private func simulate(_ dt: CGFloat, cursor: CGPoint?, shape: CursorShape?) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        let previousTime = time
        time += dt
        let bins = Int(ceil(bounds.width / binWidth))
        if ground.count != bins { ground = Array(repeating: 0, count: bins) }
        updatePlacements(from: previousTime)
        updateSnowmanFalls(from: previousTime)
        lastCursor = cursor
        if christmas {
            refreshAdvent()
            // Rudolph and Santa belong to their doors, 6 and 23: before
            // those are opened nobody flies, in November neither.
            christmasScene.allowRudolph = !SnowView.visitorsNeedDoors || advent.has(.rudolph)
            christmasScene.allowSleigh = !SnowView.visitorsNeedDoors || advent.has(.sleigh)
            christmasScene.step(dt, bounds: bounds, ledges: ledges, suspended: workshop.suspendedSurfaces,
                                groundHeight: { [self] x in groundHeight(at: x) })
        }
        releaseWindowSnow()
        if !seeded {
            seeded = true
            for _ in 0..<Int(180 * density) { flakes.append(makeFlake(y: .random(in: floorY...max(floorY, bounds.height)))) }
        }
        var cursorSweep: CursorSweep?
        if !building, workshop.held == nil, let cursor, let shape, !shape.rows.isEmpty {
            cursorSweep = CursorSweep(start: previousCursor ?? cursor, end: cursor, shape: shape, duration: max(1.0 / 240, dt))
        }
        previousCursor = building ? nil : cursor
        buildPointer = building ? cursor : nil
        advanceRunoff(dt, cursor: cursorSweep)
        advanceSurfaceTransfers(dt, cursor: cursorSweep)
        if let cursorSweep, cursorSweep.normalizedSpeed > 0.08 { brushPiles(with: cursorSweep) }
        slideSnow(dt)
        let fall = density * (time < flurryUntil ? 2.4 : 1)
        spawnBudget += dt * min(170, bounds.width * 0.115) * fall
        while spawnBudget >= 1 {
            spawnBudget -= 1
            if flakes.count < 800 {
                flakes.append(makeFlake(y: bounds.height + 9))
            }
        }
        var falling: [Flake] = []
        falling.reserveCapacity(flakes.count)
        var overflowing: Set<UInt32> = []
        let pushDamping = exp(-4.1 * dt)
        let pointerSpeed = (cursorSweep?.speed ?? 0) / max(0.001, dt)
        let pointerReach = min(12, 2 + pointerSpeed * 0.017)
        let pointerCarry = min(0.82, pointerSpeed / 730)
        let pointerForce = min(315, 16 + pointerSpeed * 0.53)
        let wind = SnowWind(time: time)
        for var flake in flakes {
            let previous = CGPoint(x: flake.x, y: flake.y)
            let drift: CGFloat
            if flake.looseSnow > 0 {
                flake.vy = max(-1050, flake.vy - 1600 * dt)
                drift = 0
            } else {
                let response = 1 - exp(-(3.25 - min(4, flake.radius) * 0.54) * dt)
                flake.windVelocity += (wind.speed(at: previous.y) - flake.windVelocity) * response
                let flutter = (3.8 + flake.radius * 0.74) * sin(time * 0.92 + flake.phase)
                drift = flake.windVelocity + flutter
            }
            let travelX = (flake.vx + drift + flake.push.dx) * dt
            let travelY = (flake.vy + flake.push.dy) * dt
            var segmentStart = previous
            var position = CGPoint(x: previous.x + travelX, y: previous.y + travelY)
            if flake.depth != .distant, let sweep = cursorSweep,
               let impact = sweep.impact(at: previous, movingTo: position,
                                         radius: flake.radius + 1, forgiveness: pointerReach) {
                let hit = CGPoint(x: previous.x + travelX * impact.time, y: previous.y + travelY * impact.time)
                if !masks(at: hit.y).contains(where: { $0.contains(hit) }) {
                    if impact.time > 0 {
                        switch land(flake, from: previous, to: hit, overflowing: &overflowing) {
                        case .missed: break
                        case .settled: continue
                        case .rebounded(let fragment):
                            falling.append(fragment)
                            continue
                        }
                    }
                    segmentStart = hit
                    let distance = max(0.01, sweep.speed)
                    let x = impact.normal.dx * (1 - pointerCarry) + sweep.dx / distance * pointerCarry
                    let y = impact.normal.dy * (1 - pointerCarry) + sweep.dy / distance * pointerCarry
                    let length = max(0.05, hypot(x, y))
                    let direction = CGVector(dx: x / length, dy: y / length)
                    let response = flake.looseSnow > 0
                        ? max(0.30, 0.72 / (1 + flake.looseSnow * 0.055))
                        : min(1.14, max(0.71, 2.4 / (flake.radius + 0.4)))
                    let force = pointerForce * response
                    let momentum = flake.push.dx * direction.dx + flake.push.dy * direction.dy
                    let impulse = max(0, force - momentum)
                    let pushX = direction.dx * impulse
                    let pushY = direction.dy * impulse
                    let remaining = (1 - impact.time) * dt
                    position.x += pushX * remaining
                    position.y += pushY * remaining
                    flake.push.dx += pushX
                    flake.push.dy += pushY
                }
            }
            flake.push.dx *= pushDamping
            flake.push.dy *= pushDamping
            if flake.looseSnow > 0 {
                position.x = min(bounds.width.nextDown, max(0, position.x))
            }
            switch land(flake, from: segmentStart, to: position, overflowing: &overflowing) {
            case .missed: break
            case .settled: continue
            case .rebounded(let fragment):
                falling.append(fragment)
                continue
            }
            if flake.looseSnow == 0,
               position.x < -snowfallSideMargin || position.x >= bounds.width + snowfallSideMargin {
                // Feed the upwind side at this height; a top-only source leaves the edges bare in gusts.
                // This happens after collisions so there is no cross-screen path through the windows.
                let span = bounds.width + 2 * snowfallSideMargin
                let wrapped = (position.x + snowfallSideMargin).truncatingRemainder(dividingBy: span)
                position.x = (wrapped < 0 ? wrapped + span : wrapped) - snowfallSideMargin
                flake.push = .zero
            }
            flake.x = position.x
            flake.y = position.y
            if flake.y >= floorY { falling.append(flake) }
        }
        flakes = falling
        for id in overflowing { settleOverflow(on: id) }
        if plowEnabled && !fight.isRunning {
            heavyPlow.step(dt, ground: &ground, cell: binWidth, width: bounds.width, smallLoad: plowLoad)
            advancePlow(dt)
        }
        settleGround(dt)
        if workshopEnabled {
            workshop.step(dt, time: time, sweep: cursorSweep, ledges: ledges, bounds: bounds,
                          groundHeight: { [self] x in groundHeight(at: x) },
                          visible: { [self] p in isVisible(p) },
                          collect: { [self] surface, x, radius, pressure in
                collectForBall(on: surface, x: x, radius: radius, pressure: pressure)
            })
            for impact in workshop.takeImpacts() { breakPackedSnowball(impact) }
            fight.step(dt,workshop:workshop,visible:{ [self] point in !windowFrames.contains { $0.contains(point) } },
                       emit:{ [self] in breakPackedSnowball($0) })
        }
        needsDisplay = true
        if let dockView { for band in dockBands { dockView.setNeedsDisplay(band) } }
    }

    private func breakPackedSnowball(_ impact:PackedSnowImpact) {
        let count = min(12,max(5,Int(impact.radius*0.34)+3))
        let energy = min(85,max(28,-impact.velocity.dy*0.09))
        var remaining = impact.mass
        for index in 0..<count {
            let fraction = (CGFloat(index)+0.5)/CGFloat(count)
            let spread = (fraction-0.5)*2
            let amount = index == count-1 ? remaining : impact.mass/CGFloat(count)
            remaining -= amount
            dropSnow(at:CGPoint(x:impact.point.x+spread*impact.radius*0.62,
                                y:impact.point.y+max(2,impact.radius*(0.22+0.42*sin(fraction*CGFloat.pi)))),
                     amount:amount,sideways:impact.velocity.dx*0.22+spread*energy,
                     vertical:34+energy*(0.55+0.30*cos(fraction*CGFloat.pi*2)),powder:true)
        }
    }

    private func settleGround(_ dt: CGFloat) {
        guard ground.count > 1, dt > 0 else { return }
        let fraction = min(0.24, 1 - exp(-8.4 * dt))
        var next = ground
        var changed = false
        for left in 0..<(ground.count - 1) {
            let right = left + 1
            let difference = ground[left] - ground[right]
            guard abs(difference) > 1.65 else { continue }
            let high = difference > 0 ? left : right
            let low = difference > 0 ? right : left
            let amount = min((abs(difference) - 1.65) * fraction, next[high])
            next[high] -= amount
            next[low] += amount
            changed = true
        }
        if changed { ground = next }
    }

    private func land(_ flake: Flake, from start: CGPoint, to end: CGPoint,
                      overflowing: inout Set<UInt32>) -> FlakeLanding {
        guard end.y < start.y else { return .missed }
        var landing: (id: UInt32, contact: SnowContact)?
        if flake.looseSnow == 0, flake.depth != .distant, !shelves.isEmpty {
            let count = shelvesByHeight.count
            let first = band(at: end.y - max(ledgeCapacity, groundCapacity), count: count)
            let last = band(at: start.y + 1, count: count)
            for band in Swift.stride(from: last, through: first, by: -1) {
                for id in shelvesByHeight[band] {
                    guard let ledge = ledges[id],
                          let contact = snowContact(from: start, to: end, base: ledge.lip,
                                                    left: ledge.frame.minX, right: ledge.frame.maxX,
                                                    heights: ledge.snow, exposed: ledge.exposed),
                          contact.time < (landing?.contact.time ?? .infinity) else { continue }
                    landing = (id, contact)
                }
            }
        }
        if let landing, let ledge = ledges[landing.id] {
            let index = landing.contact.bin
            for neighbor in max(0, index - 1)...min(ledge.snow.count - 1, index + 1) where ledge.exposed[neighbor] {
                let weight: CGFloat = neighbor == index ? 0.70 : 0.23
                let amount = ledge.snow[neighbor] + flake.radius * weight * ledgeDeposit
                ledges[landing.id]?.snow[neighbor] = amount
                if amount > ledge.capacity(at: neighbor) { overflowing.insert(landing.id) }
            }
            return .settled
        }

        guard let contact = snowContact(from: start, to: end, base: floorY,
                                        left: 0, right: bounds.width, heights: ground, looseDrift: true) else { return .missed }
        let speed = -(flake.vy + flake.push.dy)
        let rebounds = !flake.hasBounced && flake.looseSnow >= 0.36 && speed >= 370
        let bounceMass = rebounds ? flake.looseSnow * min(0.31, 0.16 + (speed - 370) / 2900) : 0
        let index = contact.bin
        let neighbors = max(0, index - 1)...min(ground.count - 1, index + 1)
        let totalWeight = 0.68 + CGFloat(neighbors.count - 1) * 0.25
        var overflow: CGFloat = 0
        let blade = plowX + bladeTip
        let contactX = start.x + (end.x - start.x) * contact.time
        let atBlade = plowEnabled && !heavyPlow.active && flake.looseSnow > 0 && abs(contactX - blade) <= binWidth * 1.5
        for neighbor in neighbors {
            let weight: CGFloat = neighbor == index ? 0.68 : 0.25
            var amount = flake.looseSnow > 0
                ? (flake.looseSnow - bounceMass) * weight / totalWeight
                : flake.radius * weight * groundDeposit * (flake.depth == .distant ? 0.78 : 1)
            let cellCenter = (CGFloat(neighbor) + 0.5) * binWidth
            if atBlade, cellCenter <= blade, cellCenter >= blade - binWidth * 1.5 {
                let caught = min(amount,max(0,plowLoadLimit-plowLoad))
                plowLoad += caught
                amount -= caught
            }
            let deposit = min(amount, max(0, groundCapacity - ground[neighbor]))
            ground[neighbor] += deposit
            overflow += amount - deposit
        }
        if flake.looseSnow > 0, overflow > 0 {
            // Loose snow temporarily raises this drift, then avalanches into adjacent cells.
            // Never teleport excess to a remote empty part of the desktop.
            ground[index] += overflow
        }
        guard rebounds else { return .settled }

        var fragment = flake
        fragment.x = min(bounds.width.nextDown, max(0, start.x + (end.x - start.x) * contact.time))
        fragment.y = floorY + ground[index] + 0.45
        fragment.vx = (flake.vx + flake.push.dx) * 0.48
        fragment.vy = min(116, speed * 0.16)
        fragment.radius = max(0.8, flake.radius * 0.62)
        fragment.looseSnow = bounceMass
        fragment.push = .zero
        fragment.hasBounced = true
        return .rebounded(fragment)
    }

    private func slideSnow(_ dt: CGFloat) {
        for id in shelves {
            guard var ledge = ledges[id], abs(ledge.slideVelocity) > 3 else { continue }
            let direction = ledge.slideVelocity < 0 ? -1 : 1
            let fraction = 1 - exp(-abs(ledge.slideVelocity) * dt / binWidth)
            var sliding = ledge.snow
            var overflowing = false
            for index in ledge.snow.indices where ledge.exposed[index] && ledge.snow[index] > 0.005 {
                let neighbor = index + direction
                let amount = ledge.snow[index] * fraction
                if ledge.snow.indices.contains(neighbor) {
                    guard ledge.exposed[neighbor] else { continue }
                    sliding[index] -= amount
                    sliding[neighbor] += amount
                    overflowing = overflowing || sliding[neighbor] > ledgeCapacity
                } else {
                    let outer = ledge.edge(direction: CGFloat(direction))
                    guard outer >= bounds.minX - 1, outer <= bounds.maxX + 1 else { continue }
                    sliding[index] -= amount
                    let edge = direction < 0 ? ledge.frame.minX : ledge.frame.maxX
                    queueRunoff(at: CGPoint(x: edge, y: ledge.lip + ledge.snow[index]),
                                on: id, ledge: ledge, direction: CGFloat(direction), amount: amount)
                }
            }
            ledge.snow = sliding
            ledge.slideVelocity *= exp(-5.2 * dt)
            ledges[id] = ledge
            if overflowing { settleOverflow(on: id) }
        }
    }

    private func settleOverflow(on id: UInt32) {
        guard var ledge = ledges[id] else { return }
        for index in ledge.snow.indices where ledge.snow[index] > ledge.capacity(at: index) {
            var excess = ledge.snow[index] - ledge.capacity(at: index)
            ledge.snow[index] = ledge.capacity(at: index)
            if index == 0 || index == ledge.snow.count - 1 {
                let direction: CGFloat = index == 0 ? -1 : 1
                let x = min(ledge.frame.maxX - 0.1, ledge.frame.minX + (CGFloat(index) + 0.5) * binWidth)
                queueRunoff(at: CGPoint(x: x, y: ledge.lip + ledge.snow[index]), on: id,
                            ledge: ledge, direction: direction, amount: excess)
                continue
            }
            var left = index
            var right = index
            while left > 0, ledge.exposed[left - 1] { left -= 1 }
            while right + 1 < ledge.snow.count, ledge.exposed[right + 1] { right += 1 }

            // New powder rolls down the nearest available part of the same sill.
            let reach = max(index - left, right - index)
            if reach > 0 {
                for distance in 1...reach {
                    for neighbor in [index - distance, index + distance] where neighbor >= left && neighbor <= right {
                        let transfer = min(excess, max(0, ledge.capacity(at: neighbor) - ledge.snow[neighbor]))
                        ledge.snow[neighbor] += transfer
                        excess -= transfer
                    }
                    if excess <= 0 { break }
                }
            }
            guard excess > 0 else { continue }
            let leftOpen = left == 0 && ledge.windowFrame.minX > bounds.minX + 1
            let rightOpen = right == ledge.snow.count - 1 && ledge.windowFrame.maxX < bounds.maxX - 1
            let toLeft = leftOpen && (!rightOpen || index <= ledge.snow.count - 1 - index)
            let x = min(ledge.frame.maxX - 0.1, ledge.frame.minX + (CGFloat(index) + 0.5) * binWidth)
            let point = CGPoint(x: x, y: ledge.lip + ledge.snow[index])
            if leftOpen || rightOpen {
                queueRunoff(at: point, on: id, ledge: ledge, direction: toLeft ? -1 : 1, amount: excess)
            } else {
                dropSnow(at: point, amount: excess, sideways: 0, vertical: -68)
            }
        }
        ledges[id] = ledge
    }

    private func queueRunoff(at point: CGPoint, on id: UInt32, ledge: Ledge, direction: CGFloat, amount: CGFloat) {
        if let index = runoff.lastIndex(where: {
            $0.window == id && $0.direction == direction && abs($0.position.x - point.x) < 21
        }) {
            runoff[index].amount += amount
        } else if runoff.count < 96 {
            runoff.append(SillRunoff(window: id, position: point, frame: ledge.windowFrame, direction: direction, amount: amount))
        } else {
            let exit = CGPoint(x: ledge.edge(direction: direction) + direction * 1.5, y: ledge.lip + 1)
            dropSnow(at: exit, amount: amount, sideways: direction * 48, vertical: -68)
        }
    }

    private func advanceRunoff(_ dt: CGFloat, cursor: CursorSweep?) {
        guard !runoff.isEmpty else { return }
        var sliding: [SillRunoff] = []
        sliding.reserveCapacity(runoff.count)
        for var grain in runoff {
            if workshop.suspendedSurfaces.contains(grain.window) { sliding.append(grain); continue }
            var speed = min(238, 152 + sqrt(grain.amount) * 24)
            guard let ledge = ledges[grain.window] else {
                dropSnow(at: grain.position, amount: grain.amount, sideways: grain.direction * 64, vertical: -45)
                continue
            }
            if ledge.windowFrame.width == grain.frame.width {
                grain.position.x += ledge.windowFrame.minX - grain.frame.minX
            }
            grain.frame = ledge.windowFrame
            guard grain.position.x >= ledge.windowFrame.minX, grain.position.x <= ledge.windowFrame.maxX else {
                dropSnow(at: grain.position, amount: grain.amount, sideways: grain.direction * 64, vertical: -45)
                continue
            }
            if let cursor, cursor.speed > 0.6,
               let impact = cursor.impact(at: grain.position, radius: grain.radius, forgiveness: 4) {
                if cursor.dx * grain.direction > max(0.6, abs(cursor.dy) * 0.65) {
                    speed += min(62, abs(cursor.dx) * 3)
                } else {
                    dropSnow(at: grain.position, amount: grain.amount,
                             sideways: cursor.dx * 21 + impact.normal.dx * 36, vertical: -62)
                    continue
                }
            }

            let target = grain.position.x + grain.direction * speed * dt
            let edge = ledge.edge(direction: grain.direction)
            let crossedEdge = grain.direction < 0 ? target <= edge : target >= edge
            let end = min(ledge.windowFrame.maxX, max(ledge.windowFrame.minX, target))
            let firstBin = runoffBin(at: grain.position.x, on: ledge)
            let lastBin = runoffBin(at: end, on: ledge)
            let stride = Swift.stride(from: firstBin, through: lastBin, by: grain.direction < 0 ? -1 : 1)
            if let blocked = stride.first(where: { !ledge.exposed[$0] }) {
                let wall = ledge.frame.minX + CGFloat(blocked + (grain.direction < 0 ? 1 : 0)) * binWidth
                let x = min(max(wall, ledge.frame.minX), ledge.frame.maxX)
                dropSnow(at: CGPoint(x: x, y: ledge.lip + ledge.snow[blocked]),
                         amount: grain.amount, sideways: grain.direction * 38, vertical: -54)
            } else if crossedEdge {
                dropSnow(at: CGPoint(x: edge + grain.direction * 1.5, y: ledge.lip + 1),
                         amount: grain.amount, sideways: grain.direction * speed * 0.34, vertical: -28, powder: true)
            } else if end < ledge.frame.minX || end > ledge.frame.maxX {
                let rim = grain.direction < 0 ? ledge.frame.minX : ledge.frame.maxX
                let distance = abs(end - rim) / max(1, abs(edge - rim))
                let height = (1 - min(1, distance * distance)) * ledge.snow[lastBin]
                let point = CGPoint(x: end, y: ledge.lip + max(0.5, height))
                if windowFrames.contains(where: { $0.contains(point) }) {
                    dropSnow(at: point, amount: grain.amount, sideways: grain.direction * 38, vertical: -54)
                } else {
                    grain.position = point
                    sliding.append(grain)
                }
            } else {
                let centered = (end - ledge.frame.minX) / binWidth - 0.5
                let lower = min(ledge.snow.count - 1, max(0, Int(floor(centered))))
                let upper = min(lower + 1, ledge.snow.count - 1)
                let blend = min(1, max(0, centered - CGFloat(lower)))
                let surface = ledge.snow[lower] * (1 - blend) + ledge.snow[upper] * blend
                grain.position = CGPoint(x: end, y: ledge.lip + surface)
                sliding.append(grain)
            }
        }
        runoff = sliding
    }

    private func runoffBin(at x: CGFloat, on ledge: Ledge) -> Int {
        min(ledge.snow.count - 1, max(0, Int((x - ledge.frame.minX) / binWidth)))
    }

    func startPlow() {
        guard !heavyPlow.active else { return }
        unloadPlow()
        plowX = -70
        plowImpact = 0
        plowSpeed = 76
    }

    private func resetPlowLoad() {
        plowLoad = 0
        visiblePlowLoad = 0
    }

    private func unloadPlow() {
        let blade = plowX + bladeTip
        let held = plowLoad
        if held > 0, blade >= 0, blade < bounds.width {
            for offset: CGFloat in [3, 11, 19] {
                dropSnow(at: CGPoint(x: blade + offset, y: floorY + 6),
                         amount: held / 3, sideways: offset * 1.6, vertical: -20, powder: true)
            }
        } else { plowRemoved += held }
        resetPlowLoad()
    }

    private func advancePlow(_ dt: CGFloat) {
        if heavyPlow.active {
            if !heavyWasActive {
                heavyPlow.absorb(plowLoad)
                resetPlowLoad()
                heavyWasActive = true
            }
            smallPlowOpacity = max(0,smallPlowOpacity-dt*4)
            let legacyHits = snowmen.filter { $0.balls == 3 && heavyPlow.mouth >= $0.x * bounds.width - snowmanBaseRadius
                && heavyPlow.mouth - 1 <= $0.x * bounds.width + snowmanBaseRadius }
            if !legacyHits.isEmpty {
                for man in legacyHits { snowmen.removeAll { $0.x == man.x }; heavyPlow.absorb(80) }
                saveSnowmen()
            }
            workshop.crush(from: heavyPlow.mouth - 1, to: heavyPlow.mouth, emit: { [self] point, mass in
                heavyPlow.absorb(mass)
            })
            return
        }
        if heavyWasActive { plowX = -130; plowSpeed = 76; heavyWasActive = false }
        smallPlowOpacity = min(1,smallPlowOpacity+dt*2.5)
        plowImpact = max(0, plowImpact - dt * 2.5)
        let start = plowX + bladeTip
        let frontCell = Int(max(0,start)/binWidth)
        let ahead = (frontCell...frontCell+2).compactMap { ground.indices.contains($0) ? ground[$0] : nil }
        let resistance = ahead.isEmpty ? 0 : ahead.reduce(0,+)/CGFloat(ahead.count)
        let targetSpeed = max(32,76-plowLoad/plowLoadLimit*18-min(24,resistance*1.1)-plowImpact*12)
        plowSpeed += (targetSpeed-plowSpeed)*(1-exp(-4*dt))
        let speed = plowSpeed
        plowX += dt * speed
        let end = plowX + bladeTip
        workshop.crush(from: start, to: end, emit: { [self] point, mass in
            for index in 0..<4 {
                dropSnow(at: CGPoint(x: point.x + CGFloat(index-2)*3, y: point.y), amount: mass/4,
                         sideways: 44 + CGFloat(index)*14, vertical: 100, powder: true)
            }
        })

        if end >= 0, start < bounds.width {
            let first = Int(max(0, start) / binWidth)
            let last = Int(min(bounds.width.nextDown, end) / binWidth)
            for index in first...last {
                let binStart = CGFloat(index) * binWidth
                let binEnd = min(binStart + binWidth, bounds.width)
                let remainingStart = max(binStart, start)
                let travel = max(0,min(binEnd,end)-remainingStart)
                guard travel > 0 else { continue }
                // A small blade takes a shallow shaving, then carries its modest load off screen.
                // Excess stays in place: throwing it ahead creates a self-feeding wall of snow.
                let fraction = travel/binWidth
                let swept = min(max(0,plowLoadLimit-plowLoad),1.6*fraction,
                                ground[index]*(1-exp(-0.22*fraction)))
                ground[index] -= swept
                plowLoad += swept
            }
        }
        visiblePlowLoad += (plowLoad - visiblePlowLoad) * (1 - exp(-6 * dt))

        let count = snowmen.count
        snowmen.removeAll { man in
            let x = man.x * bounds.width
            guard man.balls == 3, end >= x - snowmanBaseRadius, start <= x + snowmanBaseRadius,
                  !placements.contains(where: {
                      $0.x == man.x && $0.ball == 3 && time < $0.started + SnowballPlacement.fallTime
                  }) else { return false }
            let duration = min(0.45, max(0.27, 0.57 - speed / 310))
            fallingSnowmen.append(SnowmanFall(man: man, started: time, duration: duration))
            for index in 0..<4 {
                let offset = CGFloat(index) * 2.5
                dropSnow(at: CGPoint(x: x - 19 + offset, y: floorY + 8 + offset * 0.7),
                         amount: 0.035, sideways: 42 + offset * 3, vertical: 55 + offset * 7)
            }
            return true
        }
        if snowmen.count != count {
            plowImpact = 1
            placements.removeAll { placement in !snowmen.contains(where: { $0.x == placement.x }) }
            saveSnowmen()
        }
        if plowX > bounds.width + 120 {
            plowRemoved += plowLoad
            resetPlowLoad()
            plowX = -130
            plowSpeed = 76
        }
    }

    private func updateSnowmanFalls(from previousTime: CGFloat) {
        guard !fallingSnowmen.isEmpty else { return }
        let stages: [(progress: CGFloat, height: CGFloat)] = [(0.73, 78), (0.89, 54), (1, 23)]
        for fall in fallingSnowmen {
            for stage in stages {
                let breakTime = fall.started + fall.duration * stage.progress
                guard previousTime < breakTime, time >= breakTime else { continue }
                let center = fall.pieceCenter(height: stage.height, at: stage.progress, width: bounds.width)
                scatterSnowball(at: center)
            }
        }
        fallingSnowmen.removeAll { time >= $0.started + $0.duration }
    }

    private func scatterSnowball(at center: CGPoint) {
        for _ in 0..<8 {
            let point = CGPoint(x: center.x + .random(in: -9...9), y: max(floorY + 3, center.y + .random(in: -5...5)))
            let amount = CGFloat.random(in: 1.8...4.8)
            if flakes.count >= 960 {
                dropSnow(at: point, amount: amount, sideways: 0)
            } else {
                flakes.append(Flake(x: point.x, y: point.y, vx: .random(in: -32...178),
                                    vy: .random(in: 15...165), radius: .random(in: 2.1...5.9),
                                    looseSnow: amount))
            }
        }
    }

    private func brushPiles(with sweep: CursorSweep) {
        for id in shelves {
            guard var ledge = ledges[id] else { continue }
            let exposed = ledge.exposed
            let spill = brushSurface(&ledge.snow, on: id, with: sweep, left: ledge.frame.minX,
                                     right: ledge.frame.maxX, base: ledge.lip, capacity: ledgeCapacity) { index, _ in
                exposed[index]
            }
            ledges[id] = ledge
            settleOverflow(on: id)
            for (position, amount, sideways) in spill {
                let direction: CGFloat = sideways < 0 ? -1 : 1
                let rim = direction < 0 ? ledge.frame.minX : ledge.frame.maxX
                let exit = ledge.edge(direction: direction)
                if abs(sweep.dx) > max(0.25, abs(sweep.dy) * 0.65), abs(position.x - rim) < 3,
                   exit >= bounds.minX, exit <= bounds.maxX {
                    queueRunoff(at: CGPoint(x: rim, y: position.y), on: id, ledge: ledge,
                                direction: direction, amount: amount)
                } else {
                    dropSnow(at: position, amount: amount, sideways: sideways, vertical: -85)
                }
            }
        }

        let groundReach = max(groundCapacity, ground.max() ?? 0)
        guard min(sweep.start.y, sweep.end.y) + sweep.shape.bounds.minY < floorY + groundReach + 9 else { return }
        var surface = ground
        let spill = brushSurface(&surface, on: nil, with: sweep, left: 0, right: bounds.width,
                                 base: floorY, capacity: groundReach) { _, point in
            !windowFrames.contains { $0.contains(point) }
        }
        ground = surface
        for (position, amount, sideways) in spill {
            dropSnow(at: position, amount: amount, sideways: sideways, vertical: 80)
        }
    }

    private func brushSurface(_ heights: inout [CGFloat], on window: UInt32?, with sweep: CursorSweep,
                              left: CGFloat, right: CGFloat, base: CGFloat, capacity: CGFloat,
                              exposed: (Int, CGPoint) -> Bool) -> [(CGPoint, CGFloat, CGFloat)] {
        guard !heights.isEmpty,
              min(sweep.start.y, sweep.end.y) + sweep.shape.bounds.minY <= base + capacity + 8,
              max(sweep.start.y, sweep.end.y) + sweep.shape.bounds.maxY >= base - 8 else { return [] }
        let direction = sweep.dx < 0 ? -1 : 1
        let horizontal = abs(sweep.dx) > max(0.001, abs(sweep.dy) * 0.65)
        let front = sweep.leadingX(direction: direction, margin: 4)
        let targetCenter = front + CGFloat(direction) * (binWidth * 0.85 + sweep.coastDistance)
        let centerIndex = (targetCenter - left) / binWidth - 0.5
        let leadingBin = direction > 0 ? Int(floor(centerIndex)) : Int(ceil(centerIndex))
        let leadingShare = 1 - abs(centerIndex - CGFloat(leadingBin))
        let strength = (0.42 + sweep.normalizedSpeed * 0.44) * sweep.frameScale
        let reach = min(9, 5 + sweep.normalizedSpeed * 0.13)
        let sideways = min(150, max(-150, sweep.dx / sweep.frameScale * 18))
        func point(at index: Int, height: CGFloat) -> CGPoint {
            let start = left + CGFloat(index) * binWidth
            return CGPoint(x: (start + min(start + binWidth, right)) / 2, y: base + height)
        }

        var collected: [(Int, CGPoint, CGFloat, CGFloat)] = []
        for index in heights.indices where heights[index] > 0 {
            let position = point(at: index, height: heights[index])
            let shoulder = CGPoint(x: position.x, y: base + heights[index] * 0.52)
            guard exposed(index, position),
                  let hit = sweep.impact(at: position, radius: binWidth * 0.60, forgiveness: reach)
                    ?? sweep.impact(at: shoulder, radius: binWidth * 0.55, forgiveness: reach) else { continue }
            let depthResponse = 1 + min(0.30, heights[index] / 34)
            let amount = min(heights[index], strength * depthResponse)
            heights[index] -= amount
            collected.append((index, position, amount, hit.normal.dx))
        }

        let packing = workshopEnabled && !collected.isEmpty
            && workshop.brush(on: window, distance: sweep.speed, duration: sweep.duration, at: time)
        var spill: [(CGPoint, CGFloat, CGFloat)] = []
        var reserved: [Int: CGFloat] = [:]
        let frame = CGRect(x: left, y: base, width: right - left, height: 1)
        for (source, position, amount, normal) in collected {
            guard horizontal else {
                spill.append((position, amount, sideways + normal * 30))
                continue
            }
            var remaining = amount
            var index = source + direction
            var lastPosition = position
            while heights.indices.contains(index), remaining > 0 {
                let destination = point(at: index, height: heights[index])
                guard exposed(index, destination) else { break }
                lastPosition = destination
                if (index - leadingBin) * direction >= 0 {
                    let available = index == leadingBin ? min(remaining, amount * leadingShare) : remaining
                    let deposit = min(available, max(0, capacity - heights[index] - reserved[index, default: 0]))
                    if deposit > 0 {
                        if queueSurfaceSnow(on: window, from: position, to: destination.x, frame: frame,
                                            direction: direction, amount: deposit, travelSpeed: sweep.transportSpeed) {
                            reserved[index, default: 0] += deposit
                        } else {
                            heights[index] += deposit
                        }
                        remaining -= deposit
                    }
                }
                index += direction
            }
            if remaining > 0 {
                let dropX = min(right, max(left, lastPosition.x + CGFloat(direction) * binWidth / 2))
                if !queueSurfaceSnow(on: window, from: position, to: dropX + CGFloat(direction) * 0.5,
                                     frame: frame, direction: direction, amount: remaining,
                                     travelSpeed: sweep.transportSpeed) {
                    // Keep material at its source when the motion budget is occupied.
                    heights[source] += remaining
                }
            }
        }
        if packing {
            let candidates = surfaceTransfers.indices.filter { index in
                let t = surfaceTransfers[index]
                return t.window == window && abs(t.position.x - sweep.end.x) < 34
            }
            let mass = candidates.reduce(CGFloat(0)) { $0 + surfaceTransfers[$1].amount }
            if mass >= 9 {
                let x = candidates.reduce(CGFloat(0)) { $0 + surfaceTransfers[$1].position.x * surfaceTransfers[$1].amount } / mass
                let position = CGPoint(x: x, y: base + sqrt(mass * binWidth / .pi))
                if workshop.canForm(at: position) {
                    workshop.form(at: position, mass: mass, surface: window, frame: frame)
                    for index in candidates.reversed() { surfaceTransfers.remove(at: index) }
                }
            }
        }
        return spill
    }

    private func collectForBall(on surface: UInt32?, x: CGFloat, radius: CGFloat, pressure: CGFloat) -> CGFloat {
        var heights = surface.flatMap { ledges[$0]?.snow } ?? ground
        guard !heights.isEmpty else { return 0 }
        let left = surface.flatMap { ledges[$0]?.frame.minX } ?? 0
        let first = min(heights.count-1,max(0,Int((x-radius-left)/binWidth)))
        let last = min(heights.count-1,max(0,Int((x+radius-left)/binWidth)))
        var mass: CGFloat = 0
        for index in first...last {
            if let surface, ledges[surface]?.exposed[index] != true { continue }
            let take = min(heights[index], pressure * 0.45)
            heights[index] -= take
            mass += take
        }
        for index in surfaceTransfers.indices where surfaceTransfers[index].window == surface
            && abs(surfaceTransfers[index].position.x-x) < radius+5 {
            let take = min(surfaceTransfers[index].amount,pressure*0.85)
            surfaceTransfers[index].amount -= take
            mass += take
        }
        surfaceTransfers.removeAll { $0.amount <= 0 }
        if let surface { ledges[surface]?.snow = heights } else { ground = heights }
        return mass
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        if workshop.held != nil {
            addCursorRect(visibleRect, cursor: FestiveCursorArt.closed(christmas))
        } else {
            if christmas, villageEnabled, let layout = adventLayout {
                for door in layout.doors where advent.canOpen(door.day) {
                    addCursorRect(door.rect.insetBy(dx: -4, dy: -4).intersection(visibleRect),
                                  cursor: FestiveCursorArt.open(true))
                }
            }
            if christmas {
                for gift in christmasScene.gifts where isVisible(CGPoint(x: gift.x, y: gift.y)) {
                    let rect = CGRect(x: gift.x - gift.reach, y: gift.y - gift.reach,
                                      width: gift.reach * 2, height: gift.reach * 2)
                    addCursorRect(rect.intersection(visibleRect), cursor: FestiveCursorArt.open(true))
                }
            }
            for ball in workshop.balls where !workshop.isSuspended(ball)
                && !windowFrames.contains(where: { $0.contains(CGPoint(x:ball.x,y:ball.y)) }) {
                let pointer = workshopPointerShape?.bounds ?? .zero
                let margin = workshop.grabMargin
                let rect = CGRect(x:ball.x-ball.radius-margin-pointer.maxX,y:ball.y-ball.radius-margin-pointer.maxY,
                                  width:(ball.radius+margin)*2+pointer.width,height:(ball.radius+margin)*2+pointer.height)
                addCursorRect(rect.intersection(visibleRect), cursor: FestiveCursorArt.open(christmas))
            }
        }
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    /// Frames of the icons lying on the desktop, in view coordinates. A
    /// click or drag there always belongs to the icon, never to Schneetag.
    var desktopIcons: [CGRect] = []

    func wantsInteraction(at point: CGPoint?) -> Bool {
        if workshop.held != nil { return true }
        guard let point else { return false }
        if desktopIcons.contains(where: { $0.contains(point) }) { return false }
        if giftUnderPointer(at: point) != nil { return true }
        if adventDoor(at: point) != nil { return true }
        if ownsDesktopPointer(at: point) { return true }
        return workshop.hit(at: point, shape:workshopPointerShape, visible: { [self] p in isVisible(p) }) != nil
    }
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // A present is the only thing that takes a click before the snow does.
        if workshop.held == nil, let gift = giftUnderPointer(at: point) {
            christmasScene.open(gift)
            needsDisplay = true
            window?.invalidateCursorRects(for: self)
            return
        }
        if workshop.held == nil, let day = adventDoor(at: point) {
            openAdventDoor(day)
            window?.invalidateCursorRects(for: self)
            return
        }
        workshop.down(at: point, shape:workshopPointerShape, time:CACurrentMediaTime(),
                      visible: { [self] p in isVisible(p) })
        window?.invalidateCursorRects(for: self)
    }
    override func mouseDragged(with event: NSEvent) { workshop.drag(at: convert(event.locationInWindow, from: nil),time:CACurrentMediaTime()) }
    override func mouseUp(with event: NSEvent) { workshop.up(at: convert(event.locationInWindow, from: nil),time:CACurrentMediaTime()) }
    override func rightMouseDown(with event: NSEvent) { workshop.release(at: convert(event.locationInWindow, from: nil),time:CACurrentMediaTime()) }

    private func queueSurfaceSnow(on window: UInt32?, from position: CGPoint, to target: CGFloat,
                                  frame: CGRect, direction: Int, amount: CGFloat, travelSpeed: CGFloat) -> Bool {
        if let index = surfaceTransfers.lastIndex(where: {
            $0.window == window && $0.direction == direction && $0.targetX == target
                && abs($0.position.x - position.x) < 18
        }) {
            let blend = amount / (surfaceTransfers[index].amount + amount)
            surfaceTransfers[index].position.x += (position.x - surfaceTransfers[index].position.x) * blend
            surfaceTransfers[index].amount += amount
            return true
        }
        guard surfaceTransfers.count < 128 else { return false }
        let speed = travelSpeed
        surfaceTransfers.append(SurfaceSnowTransfer(window: window, position: position, targetX: target,
                                                    frame: frame, direction: direction, speed: speed, amount: amount))
        return true
    }

    private func advanceSurfaceTransfers(_ dt: CGFloat, cursor: CursorSweep?) {
        guard dt > 0, !surfaceTransfers.isEmpty else { return }
        let touchedWindows = Set(surfaceTransfers.compactMap(\.window))
        var moving: [SurfaceSnowTransfer] = []
        moving.reserveCapacity(surfaceTransfers.count)
        var spills: [(CGPoint, CGFloat, CGFloat, CGFloat)] = []
        var exits: [(id: UInt32, point: CGPoint, direction: CGFloat, amount: CGFloat)] = []
        for var transfer in surfaceTransfers {
            if let id = transfer.window {
                if workshop.suspendedSurfaces.contains(id) { moving.append(transfer); continue }
                guard var ledge = ledges[id] else {
                    dropSnow(at: transfer.position, amount: transfer.amount, sideways: 0, vertical: -55)
                    continue
                }
                let exposed = ledge.exposed
                let frame = CGRect(x: ledge.frame.minX, y: ledge.lip, width: ledge.frame.width, height: 1)
                let remaining = moveSurfaceSnow(&transfer, heights: &ledge.snow, frame: frame,
                                                capacity: ledgeCapacity, dt: dt, cursor: cursor, spills: &spills, exits: &exits) { index, _ in exposed[index] }
                ledges[id] = ledge
                if let remaining { moving.append(remaining) }
            } else {
                var surface = ground
                let frame = CGRect(x: 0, y: floorY, width: bounds.width, height: 1)
                let remaining = moveSurfaceSnow(&transfer, heights: &surface, frame: frame,
                                                capacity: groundCapacity, dt: dt, cursor: cursor, spills: &spills, exits: &exits) { _, point in
                    !windowFrames.contains { $0.contains(point) }
                }
                ground = surface
                if let remaining { moving.append(remaining) }
            }
        }
        surfaceTransfers = moving
        for id in touchedWindows { settleOverflow(on: id) }
        for (point, amount, sideways, vertical) in spills {
            dropSnow(at: point, amount: amount, sideways: sideways, vertical: vertical, powder: true)
        }
        for exit in exits {
            guard let ledge = ledges[exit.id] else { continue }
            queueRunoff(at: exit.point, on: exit.id, ledge: ledge, direction: exit.direction, amount: exit.amount)
        }
    }

    private func moveSurfaceSnow(_ transfer: inout SurfaceSnowTransfer, heights: inout [CGFloat],
                                 frame: CGRect, capacity: CGFloat, dt: CGFloat, cursor: CursorSweep?,
                                 spills: inout [(CGPoint, CGFloat, CGFloat, CGFloat)],
                                 exits: inout [(id: UInt32, point: CGPoint, direction: CGFloat, amount: CGFloat)],
                                 exposed: (Int, CGPoint) -> Bool) -> SurfaceSnowTransfer? {
        if frame.width == transfer.frame.width {
            let shift = frame.minX - transfer.frame.minX
            transfer.position.x += shift
            transfer.targetX += shift
        }
        transfer.position.y += frame.minY - transfer.frame.minY
        transfer.frame = frame
        guard !heights.isEmpty, transfer.position.x >= frame.minX, transfer.position.x <= frame.maxX else {
            spills.append((transfer.position, transfer.amount, 0, -55))
            return nil
        }

        func bin(at x: CGFloat) -> Int {
            min(heights.count - 1, max(0, Int((x - frame.minX) / binWidth)))
        }
        func point(at index: Int) -> CGPoint {
            let left = frame.minX + CGFloat(index) * binWidth
            return CGPoint(x: (left + min(left + binWidth, frame.maxX)) / 2, y: frame.minY + heights[index])
        }
        var lift: CGFloat = 0
        if let cursor, abs(cursor.dx) > max(0.001, abs(cursor.dy) * 0.65),
           cursor.impact(at: transfer.position, radius: min(9, 4 + sqrt(transfer.amount)),
                         forgiveness: transfer.direction == (cursor.dx < 0 ? -1 : 1) ? 8 : 6) != nil {
            let direction = cursor.dx < 0 ? -1 : 1
            let target = cursor.leadingX(direction: direction, margin: 4) + CGFloat(direction) * (binWidth * 0.85 + cursor.coastDistance)
            if (target - transfer.position.x) * CGFloat(direction) > 1 {
                transfer.speed = cursor.transportSpeed
                if transfer.direction != direction { transfer.speed *= 0.82 }
                transfer.direction = direction
                transfer.targetX = target
                lift = min(8, 1.4 + transfer.amount * 0.82)
                if transfer.amount > 3.3, time - transfer.lastSpill >= 0.12 {
                    let amount = min(1.55, (transfer.amount - 3.3) * 0.48)
                    let rear = direction > 0 ? min(cursor.shape.bounds.minX, -3) : max(cursor.shape.bounds.maxX, 3)
                    let x = min(bounds.width.nextDown, max(0, cursor.end.x + rear - CGFloat(direction) * 6))
                    let height = max(frame.minY + 4, transfer.position.y + max(3.5, transfer.lift * 0.8))
                    spills.append((CGPoint(x: x, y: height), amount, -CGFloat(direction) * 28, 50))
                    transfer.amount -= amount
                    transfer.lastSpill = time
                }
            }
        }
        transfer.lift += (lift - transfer.lift) * (1 - exp(-20 * dt))
        let direction = transfer.direction
        let target = min(frame.maxX.nextDown, max(frame.minX, transfer.targetX))
        let limit = transfer.position.x + CGFloat(direction) * transfer.speed * dt
        let end = direction > 0 ? min(target, limit) : max(target, limit)
        let first = bin(at: transfer.position.x)
        let last = bin(at: end)
        let indices = Swift.stride(from: first, through: last, by: direction)
        if indices.contains(where: { !exposed($0, point(at: $0)) }) {
            let deposit = exposed(first, point(at: first))
                ? min(transfer.amount, max(0, capacity - heights[first])) : 0
            heights[first] += deposit
            if transfer.amount > deposit {
                spills.append((transfer.position, transfer.amount - deposit, 0, -55))
            }
            return nil
        }

        transfer.position.x = end
        let y = point(at: last).y
        transfer.position.y += (y - transfer.position.y) * min(1, dt * 24)
        if end != target { return transfer }
        if let id = transfer.window,
           transfer.targetX < frame.minX || transfer.targetX >= frame.maxX {
            let rim = direction < 0 ? frame.minX : frame.maxX
            exits.append((id, CGPoint(x: rim, y: frame.minY), CGFloat(direction), transfer.amount))
            return nil
        }

        var remaining = transfer.amount
        for offset in 0...2 {
            let index = last + offset * direction
            guard heights.indices.contains(index), exposed(index, point(at: index)) else { break }
            let deposit = min(remaining, max(0, capacity - heights[index]))
            heights[index] += deposit
            remaining -= deposit
            if remaining <= 0 { break }
        }
        if remaining > 0 {
            spills.append((transfer.position, remaining, CGFloat(direction) * 54, -45))
        }
        return nil
    }

    private func makeFlake(y: CGFloat) -> Flake {
        let radius = CGFloat.random(in: 1.3...3.8)
        let depth = SnowDepth.random()
        let descent = (33 + radius * 25 + CGFloat.random(in: -12...12)) * (0.44 + depth.scale * 0.56)
        return Flake(x: .random(in: -snowfallSideMargin..<(bounds.width + snowfallSideMargin)), y: y, vx: .random(in: -7...7),
                     vy: -descent, radius: radius, crystal: depth != .distant && Int.random(in: 0..<4) == 0,
                     depth: depth)
    }

    private var draft: Snowman? {
        guard let last = snowmen.last, last.balls < 3 else { return nil }
        return last
    }

    private func buildSite(at point: CGPoint) -> (x: CGFloat, available: Bool) {
        let margin = min(40, bounds.width / 2)
        let x = min(max(point.x, margin), bounds.width - margin)
        let available = !buildSiteIsCovered(x: x)
            && !snowmen.contains(where: { abs($0.x * bounds.width - x) < 61 })
        return (x, available)
    }

    private func buildSiteIsCovered(x: CGFloat) -> Bool {
        let footprint = CGRect(x: x - 30, y: floorY + 2, width: 60, height: 102)
        return windowFrames.contains(where: { $0.intersects(footprint) })
    }

    private func nextBallY(for draft: Snowman) -> CGFloat {
        floorY + (draft.balls == 1 ? 54 : 78)
    }

    func placeBall(at point: CGPoint) {
        guard building, bounds.width > 0, point.y >= 0, point.y < buildStripHeight else { return }
        if let draft {
            let x = draft.x * bounds.width
            guard abs(x - point.x) <= 38, abs(nextBallY(for: draft) - point.y) <= 32,
                  !buildSiteIsCovered(x: x) else { return }
            let ball = draft.balls + 1
            snowmen[snowmen.count - 1].balls = ball
            placements.append(SnowballPlacement(x: draft.x, ball: ball, started: time))
            if ball == 3 {
                saveSnowmen()
                finishBuild?()
            }
        } else {
            let site = buildSite(at: point)
            guard site.available else { return }
            let position = site.x / bounds.width
            snowmen.append(Snowman(x: position, balls: 1, scarf: scarf))
            placements.append(SnowballPlacement(x: position, ball: 1, started: time))
        }
    }

    func cancelBuild() {
        buildPointer = nil
        if let draft {
            snowmen.removeLast()
            placements.removeAll { $0.x == draft.x }
        }
    }

    func clearSnowmen() {
        stopSnowballFight()
        workshop.clear()
        snowmen.removeAll()
        fallingSnowmen.removeAll()
        placements.removeAll()
        saveSnowmen()
    }

    private func updatePlacements(from previousTime: CGFloat) {
        for placement in placements {
            let landing = placement.started + SnowballPlacement.fallTime
            guard previousTime < landing, time >= landing else { continue }
            let x = placement.x * bounds.width
            let y: CGFloat
            let width: CGFloat
            switch placement.ball {
            case 1: (y, width) = (floorY + 3, 15)
            case 2: (y, width) = (floorY + 38, 12)
            default: (y, width) = (floorY + 64, 9)
            }
            for side: CGFloat in [-1, 1] {
                for index in 0..<3 {
                    let gap = CGFloat(index) * 2.1
                    dropSnow(at: CGPoint(x: x + side * (width + gap), y: y + gap * 0.45),
                             amount: 0.018, sideways: side * (28 + gap * 11), vertical: 50 + gap * 12)
                }
            }
        }
        placements.removeAll { time >= $0.started + SnowballPlacement.duration }
    }

    private func pile(_ values: [CGFloat], start: CGFloat, base: CGFloat, limit: CGFloat,
                      grounded: Bool = false, in ctx: CGContext) {
        let body = CGMutablePath()
        let ridge = CGMutablePath()
        var index = 0
        var peak: CGFloat = 0
        while index < values.count {
            guard values[index] > 0.22 else { index += 1; continue }
            let first = index
            while index < values.count && values[index] > 0.22 { index += 1 }
            let left = start + CGFloat(first) * binWidth
            let right = min(limit, start + CGFloat(index) * binWidth)
            let bottom = grounded ? 0 : base
            let leftRim = CGPoint(x: left, y: base)
            var previous = leftRim
            body.move(to: CGPoint(x: left, y: bottom))
            if grounded { body.addLine(to: leftRim) }
            ridge.move(to: leftRim)
            for i in first..<index {
                let cellStart = start + CGFloat(i) * binWidth
                let cellEnd = min(right, cellStart + binWidth)
                let next = CGPoint(x: (cellStart + cellEnd) / 2, y: base + values[i])
                let midX = (previous.x + next.x) / 2
                let firstControl = CGPoint(x: midX, y: previous.y)
                let secondControl = CGPoint(x: midX, y: next.y)
                body.addCurve(to: next, control1: firstControl, control2: secondControl)
                ridge.addCurve(to: next, control1: firstControl, control2: secondControl)
                peak = max(peak, values[i])
                previous = next
            }
            let rim = CGPoint(x: right, y: base)
            let control = CGPoint(x: right, y: previous.y)
            body.addQuadCurve(to: rim, control: control)
            ridge.addQuadCurve(to: rim, control: control)
            if grounded { body.addLine(to: CGPoint(x: right, y: bottom)) }
            body.closeSubpath()
        }
        guard peak > 0 else { return }
        ctx.saveGState()
        if !grounded {
            ctx.clip(to: CGRect(x: start, y: base, width: limit - start, height: peak + 2))
        }
        SnowPaint.fillDrift(body, base: grounded ? 0 : base, crest: base + max(1, peak * 0.8), in: ctx)
        if peak > 1.2 {
            ctx.setStrokeColor(SnowPaint.glint)
            ctx.setLineWidth(0.55)
            ctx.addPath(ridge)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// Clears the given rectangles back to transparent in a single step.
    private func clearCovered(_ rects: [CGRect], in ctx: CGContext) {
        let inside = rects.map { $0.intersection(bounds) }.filter { !$0.isEmpty }
        guard !inside.isEmpty else { return }
        ctx.saveGState()
        ctx.setBlendMode(.clear)
        ctx.fill(inside)
        ctx.restoreGState()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)
        let visible = exposedDesktop ?? [bounds]
        if !visible.isEmpty {
            // Everything is drawn without clipping, then the windows are
            // cleared out in one go. A clip made of many rectangles was
            // re-applied by Core Animation to each of thousands of drawing
            // operations, every frame, and anew whenever a window moved:
            // that made dragging and shaking windows stutter.
            drawWinter(in: ctx)
            clearCovered(windowFrames, in: ctx)
        }
        let backdrop = christmas && villageEnabled ? adventBackdrop : nil
        if backdrop !== publishedBackdrop {
            publishedBackdrop = backdrop
            onBackdrop?(backdrop)
        }
        drawCornerSnow(in:ctx)
        if building { drawBuildGuide(in: ctx) }
    }

    private func drawCornerSnow(in ctx:CGContext) {
        let rolling = workshop.balls.filter { $0.edgeSurface != nil && !workshop.isSuspended($0) }
        for (id,balls) in Dictionary(grouping:rolling,by:{$0.edgeSurface!}) {
            guard let ledge = ledges[id] else { continue }
            for right in [false,true] {
                let radius = right ? ledge.windowFrame.maxX-ledge.frame.maxX : ledge.frame.minX-ledge.windowFrame.minX
                guard radius > 0 else { continue }
                let corner = CGRect(x:right ? ledge.windowFrame.maxX-radius : ledge.windowFrame.minX,
                                    y:ledge.lip-radius,width:radius,height:radius)
                guard balls.contains(where: { corner.intersects(CGRect(x:$0.x-$0.radius,y:$0.y-$0.radius,width:$0.radius*2,height:$0.radius*2)) }) else { continue }
                let visibleCorner = corner.intersection(bounds)
                guard !visibleCorner.isEmpty else { continue }
                let regions = uncoveredRectangles(in:visibleCorner,excluding:windowFrames.filter { $0 != ledge.windowFrame })
                guard !regions.isEmpty else { continue }
                ctx.saveGState()
                ctx.clip(to:regions)
                let outside = CGMutablePath()
                outside.addRect(corner)
                outside.addRoundedRect(in:ledge.windowFrame,cornerWidth:radius,cornerHeight:radius)
                ctx.addPath(outside); ctx.clip(using:.evenOdd)
                for ball in balls { snowball(in:ctx,x:ball.x,y:ball.y,radius:ball.radius,rotation:ball.rotation) }
                ctx.restoreGState()
            }
        }
    }

    private func drawWinter(in ctx: CGContext) {
        if christmas, villageEnabled, let layout = adventLayout {
            // The valley stays out of desktop widgets (the wallpaper window
            // shows it behind them); the snow below falls over them.
            ctx.saveGState()
            defer { ctx.restoreGState() }
            let scale = window?.backingScaleFactor ?? 2
            let running = NSApp?.isRunning == true
            if adventBackdrop == nil || (backdropStale && !running) {
                backdropStale = false
                adventBackdrop = AdventVillage.backdrop(layout, season: advent, sky: adventSky, scale: scale)
            } else if backdropStale && !backdropBuilding {
                backdropStale = false
                backdropBuilding = true
                let season = advent, sky = adventSky
                SnowView.backdropQueue.async { [weak self] in
                    let image = AdventVillage.backdrop(layout, season: season, sky: sky, scale: scale)
                    _ = AdventVillage.frontLayers(layout, season: season, sky: sky, scale: scale, allowStale: false)
                    DispatchQueue.main.async {
                        guard let self else { return }
                        self.backdropBuilding = false
                        if self.adventLayout?.bounds == layout.bounds { self.adventBackdrop = image }
                        self.needsDisplay = true
                    }
                }
            }
            // The wallpaper window under every window already shows this
            // very picture; painting it again here every frame doubled the
            // cost and hid the desktop icons under the valley. Only without
            // a wallpaper window (previews, tests) is it drawn here.
            if wallpaperPanel == nil, let backdrop = adventBackdrop {
                ctx.saveGState()
                ctx.interpolationQuality = .high
                ctx.draw(backdrop, in: layout.bounds)
                ctx.restoreGState()
            }
            AdventPaint.live {
                AdventVillage.drawLive(layout, season: advent, sky: adventSky, time: time,
                                       pointer: lastCursor, in: ctx)
            }
            // Widgets show the valley of the wallpaper window behind them;
            // only the snow drawn after this falls over them.
            clearCovered(previousWidgetFrames, in: ctx)
            AdventPaint.live { drawDoorNews(in: ctx) }
        }
        outsideDock(ctx) {
            drawFlakes(in: ctx, region: nil) {
                for ledge in ledges.values {
                    pile(zip(ledge.snow, ledge.exposed).map { $1 ? $0 : 0 }, start: ledge.frame.minX,
                         base: ledge.lip, limit: ledge.frame.maxX, in: ctx)
                }
                pile(ground, start: 0, base: floorY, limit: bounds.width, grounded: true, in: ctx)
                drawSurfaceTransfers(in: ctx)
                drawRunoff(in: ctx)
            }
        }
        outsideDock(ctx) { AdventPaint.live { drawFigures(in: ctx, visitors: true) } }
    }

    /// The falling snow in its layers: distant flakes first, then `middle`
    /// (the snow lying on sills and on the ground), then the nearer flakes,
    /// powder, frost shards and crystals in front of it. With a `region`
    /// only the flakes inside it are drawn.
    private func drawFlakes(in ctx: CGContext, region: [CGRect]?, middle: () -> Void) {
        var stamps: [[CGPoint]] = [[], [], [], []]
        var stampRadii: [[CGFloat]] = [[], [], [], []]
        func stampFlakes(_ style: Int, in ctx: CGContext) {
            for (index, point) in stamps[style].enumerated() {
                let (sprite, extent) = flakeSprite(style: style, radius: stampRadii[style][index])
                ctx.draw(sprite, in: CGRect(x: point.x - extent, y: point.y - extent, width: extent * 2, height: extent * 2))
            }
        }
        let powder = CGMutablePath()
        let powderEdge = CGMutablePath()
        let frostShards = CGMutablePath()
        let crystals = CGMutablePath()
        for flake in flakes where region.map({ area in area.contains { $0.minY - 6 <= flake.y && flake.y <= $0.maxY + 6 && $0.minX - 6 <= flake.x && flake.x <= $0.maxX + 6 } }) ?? true {
            let r = flake.radius * flake.depth.scale
            let extent = (flake.crystal ? r * 1.7 : (flake.powderClump ? r * 1.5 : r)) + 1
            let footprint = CGRect(x: flake.x - extent, y: flake.y - extent,
                                   width: 2 * extent, height: 2 * extent)
            // Skip particles completely inside a window before building their paths.
            guard footprint.intersects(bounds),
                  !masks(at: flake.y).contains(where: { $0.contains(footprint) }) else { continue }
            if flake.frostShard {
                let roll = 0.68 + 0.32 * sin(time * 9 + flake.phase)
                frostShards.move(to: CGPoint(x: flake.x, y: flake.y + r))
                frostShards.addLine(to: CGPoint(x: flake.x + r * roll, y: flake.y + r * 0.10))
                frostShards.addLine(to: CGPoint(x: flake.x, y: flake.y - r))
                frostShards.addLine(to: CGPoint(x: flake.x - r * roll, y: flake.y - r * 0.10))
                frostShards.closeSubpath()
            } else if flake.powderClump {
                let tumble = sin(flake.phase + time * 11)
                let width = r * (1.33 + tumble * 0.16)
                let height = r * (0.65 + tumble * 0.19)
                powderEdge.addEllipse(in: CGRect(x: flake.x - width - 0.6, y: flake.y - height - 0.9,
                                                  width: 2 * width + 1.2, height: 2 * height + 1.4))
                powder.addEllipse(in: CGRect(x: flake.x - width, y: flake.y - height,
                                              width: 2 * width, height: 2 * height))
                powder.addEllipse(in: CGRect(x: flake.x - width * 0.72, y: flake.y,
                                              width: width * 0.92, height: height * 1.24))
            } else if flake.crystal {
                let rotation = flake.phase + time * (flake.phase < .pi ? -1 : 1) * (0.22 + r * 0.13)
                for arm in 0..<3 {
                    let angle = CGFloat(arm) * .pi / 3 + rotation
                    let dx = cos(angle) * r * 1.7
                    let dy = sin(angle) * r * 1.7
                    crystals.move(to: CGPoint(x: flake.x - dx, y: flake.y - dy))
                    crystals.addLine(to: CGPoint(x: flake.x + dx, y: flake.y + dy))
                    if r >= 2.35 {
                        for side: CGFloat in [-1, 1] {
                            let x = flake.x + dx * 0.61 * side
                            let y = flake.y + dy * 0.61 * side
                            crystals.move(to: CGPoint(x: x + (dx * 0.14 - dy * 0.25) * side,
                                                      y: y + (dy * 0.14 + dx * 0.25) * side))
                            crystals.addLine(to: CGPoint(x: x, y: y))
                            crystals.addLine(to: CGPoint(x: x + (dx * 0.14 + dy * 0.25) * side,
                                                         y: y + (dy * 0.14 - dx * 0.25) * side))
                        }
                    }
                }
            } else {
                // Round flakes are stamped from small pre-rendered sprites: one
                // giant path of a thousand overlapping circles cost most of the
                // frame in anti-aliasing.
                let style: Int
                if flake.looseSnow > 0 {
                    style = 3
                } else if flake.depth == .distant {
                    style = 0
                } else {
                    style = flake.depth == .near ? 2 : 1
                }
                stamps[style].append(CGPoint(x: flake.x, y: flake.y))
                stampRadii[style].append(r)
            }
        }
        stampFlakes(0, in: ctx)
        middle()
        if !powder.isEmpty {
            ctx.setFillColor(ice.withAlphaComponent(0.57).cgColor)
            ctx.addPath(powderEdge)
            ctx.fillPath()
            ctx.setFillColor(white.withAlphaComponent(0.96).cgColor)
            ctx.addPath(powder)
            ctx.fillPath()
        }

        let outline = NSColor(calibratedWhite: 0.17, alpha: 0.27).cgColor
        ctx.setStrokeColor(outline)
        ctx.setLineWidth(0.7)
        for style in 1...3 { stampFlakes(style, in: ctx) }
        if !frostShards.isEmpty {
            ctx.setFillColor(ice.cgColor)
            ctx.addPath(frostShards)
            ctx.drawPath(using: .fillStroke)
        }
        if !crystals.isEmpty {
            // One plain stroke: the dark outline under it and the round caps
            // doubled the cost of every crystal for a barely visible edge.
            ctx.setLineCap(.butt)
            ctx.setLineJoin(.miter)
            ctx.setStrokeColor(white.withAlphaComponent(0.92).cgColor)
            ctx.setLineWidth(0.78)
            ctx.addPath(crystals)
            ctx.strokePath()
        }
    }

    /// Runs `body` everywhere except in the Dock strips while the panel in
    /// front of the Dock draws them; without that panel, everywhere.
    private func outsideDock(_ ctx: CGContext, _ body: () -> Void) {
        let bands = dockView == nil ? [] : dockBands
        guard !bands.isEmpty else { body(); return }
        ctx.saveGState()
        ctx.clip(to: uncoveredRectangles(in: bounds, excluding: bands))
        body()
        ctx.restoreGState()
    }

    /// The part of the scene that stands in front of the Dock: the ground
    /// snow, snowballs, snowmen and the plows, inside the Dock's strips.
    func drawDockFront(in ctx: CGContext) {
        let bands = dockBands
        guard !bands.isEmpty else { return }
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.clip(to: bands)
        if let visible = exposedDesktop { ctx.clip(to: visible) }
        drawFlakes(in: ctx, region: bands) {
            pile(ground, start: 0, base: floorY, limit: bounds.width, grounded: true, in: ctx)
        }
        AdventPaint.live { drawFigures(in: ctx, visitors: false) }
    }

    private func drawFigures(in ctx: CGContext, visitors: Bool) {
        let offsets=Dictionary(uniqueKeysWithValues:workshop.snowmen.flatMap { stack in
            let offset=fight.pose(for:stack[0].id).offset
            return stack.map { ($0.id,offset) }
        })
        for ball in workshop.balls where !workshop.isSuspended(ball) {
            let offset=offsets[ball.id] ?? .zero
            snowball(in: ctx, x: ball.x+offset.x, y: ball.y+offset.y, radius: ball.radius, rotation: ball.rotation)
        }
        for stack in workshop.snowmen where !workshop.isSuspended(stack[0]) { drawPackedSnowman(stack, in: ctx) }
        fight.drawShots(in:ctx)
        if christmas && visitors {
            // Visitors never cover a working window: the windows are cleared
            // out after everything is drawn, while a reindeer can still sit
            // on a sill above its window.
            christmasScene.draw(in:ctx,bounds:bounds,ledges:ledges)
        }
        for man in snowmen { drawSnowman(man, in: ctx) }
        for fall in fallingSnowmen { drawFallingSnowman(fall, in: ctx) }
        if plowEnabled {
            if smallPlowOpacity > 0.001 {
                ctx.saveGState(); ctx.setAlpha(smallPlowOpacity)
                drawPlow(in: ctx)
                ctx.restoreGState()
            }
            heavyPlow.draw(in: ctx, festive: christmas)
        }
    }

    private func drawSurfaceTransfers(in ctx: CGContext) {
        struct Crest {
            let x: CGFloat
            let width: CGFloat
            let height: CGFloat
        }
        let active = surfaceTransfers.filter { $0.amount > 0.045 && $0.window.map(workshop.suspendedSurfaces.contains) != true }
        for transfers in Dictionary(grouping: active, by: \.window).values {
            guard let first = transfers.first else { continue }
            let base = first.frame.minY
            let crests = transfers.map { transfer -> Crest in
                let spread = sqrt(transfer.amount)
                let contact = min(6, max(0, transfer.position.y - base) * 0.60)
                return Crest(x: transfer.position.x, width: 3 + spread * 3.1,
                             height: min(15, contact + 0.95 + spread * 1.65 + transfer.lift))
            }.sorted { $0.x - $0.width < $1.x - $1.width }

            var group: [Crest] = []
            var left: CGFloat = 0
            var right: CGFloat = 0
            func drawGroup() {
                let start = max(first.frame.minX, left)
                let end = min(first.frame.maxX, right)
                guard end > start else { return }
                let path = CGMutablePath()
                path.move(to: CGPoint(x: start, y: base))
                let samples = max(4, Int(ceil((end - start) / 1.75)))
                let peak = group.map(\.height).max() ?? 1
                for i in 0...samples {
                    let x = start + (end - start) * CGFloat(i) / CGFloat(samples)
                    var height: CGFloat = 0
                    for crest in group {
                        let d = (x - crest.x) / crest.width
                        guard abs(d) < 1 else { continue }
                        let slope = 1 - d * d
                        height = max(height, crest.height * slope * slope)
                    }
                    path.addLine(to: CGPoint(x: x, y: base + height))
                }
                path.addLine(to: CGPoint(x: end, y: base))
                path.closeSubpath()
                SnowPaint.fillDrift(path, base: base, crest: base + peak, in: ctx)
            }

            for crest in crests {
                let start = crest.x - crest.width
                if group.isEmpty || start > right {
                    if !group.isEmpty { drawGroup(); group.removeAll(keepingCapacity: true) }
                    left = start
                    right = crest.x + crest.width
                } else {
                    right = max(right, crest.x + crest.width)
                }
                group.append(crest)
            }
            if !group.isEmpty { drawGroup() }
        }
    }

    private func drawRunoff(in ctx: CGContext) {
        for grain in runoff where grain.amount > 0.055 && !workshop.suspendedSurfaces.contains(grain.window) {
            let r = grain.radius
            let x = grain.position.x
            let y = grain.position.y + r * 0.60
            let patch = CGRect(x: x - r * 1.22, y: y - r * 0.63, width: r * 2.44, height: r * 1.50)
            ctx.setFillColor(ice.withAlphaComponent(0.87).cgColor)
            ctx.fillEllipse(in: patch)
            ctx.setFillColor(white.cgColor)
            ctx.fillEllipse(in: patch.insetBy(dx: r * 0.12, dy: r * 0.17).offsetBy(dx: 0, dy: r * 0.15))
        }
    }

    private func circle(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: x-r, y: y-r, width: r*2, height: r*2))
    }

    private func box(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                     _ color: NSColor, radius: CGFloat = 0) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h),
                           cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.fillPath()
    }

    private func polygon(_ ctx: CGContext, _ points: [CGPoint], _ color: NSColor) {
        ctx.beginPath()
        ctx.addLines(between: points)
        ctx.closePath()
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
    }

    private func snowball(in ctx: CGContext, x: CGFloat, y: CGFloat, radius: CGFloat, rotation: CGFloat = 0) {
        let shape = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
        ctx.saveGState()
        ctx.interpolationQuality = .high
        ctx.draw(SnowPaint.sphereImage,in:shape.insetBy(dx:-radius/36,dy:-radius/36))
        ctx.addEllipse(in: shape)
        ctx.clip()
        ctx.setFillColor(SnowPaint.grain)
        for (dx, dy, size): (CGFloat, CGFloat, CGFloat) in [(-0.54, 0.19, 0.62), (0.43, -0.50, 0.73),
                                                          (0.56, -0.31, 0.40), (-0.21, -0.57, 0.47)] {
            let rotatedX = dx*cos(rotation)-dy*sin(rotation)
            let rotatedY = dx*sin(rotation)+dy*cos(rotation)
            ctx.fillEllipse(in: CGRect(x: x + rotatedX * radius, y: y + rotatedY * radius, width: size * 2, height: size * 2))
        }
        ctx.restoreGState()
        ctx.setStrokeColor(SnowPaint.edge)
        ctx.setLineWidth(0.55)
        ctx.strokeEllipse(in: shape)
    }

    private func drawPackedSnowman(_ stack:[PackedSnowball],in ctx:CGContext) {
        let pose=fight.pose(for:stack[0].id)
        ctx.saveGState();ctx.translateBy(x:pose.offset.x,y:pose.offset.y)
        SnowmanArt.draw(stack,in:ctx,scarf:scarf.color,festive:christmas,pose:pose)
        ctx.restoreGState()
    }

    private func drawFallingSnowman(_ fall: SnowmanFall, in ctx: CGContext) {
        let pivot = fall.pivot(in: bounds.width)
        let angle = SnowmanFall.angle(progress: fall.progress(at: time))
        var man = fall.man
        man.balls = fall.visibleBalls(at: time)
        ctx.saveGState()
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: angle)
        ctx.translateBy(x: -pivot.x, y: -pivot.y)
        drawSnowman(man, grounded: false, in: ctx)
        ctx.restoreGState()
    }

    private func drawSnowman(_ man: Snowman, grounded: Bool = true, in ctx: CGContext) {
        let x = man.x * bounds.width
        let baseOffset = grounded ? placements.first { $0.x == man.x && $0.ball == 1 }?.offset(at: time) ?? 0 : 0
        let middleOffset = grounded ? placements.first { $0.x == man.x && $0.ball == 2 }?.offset(at: time) ?? 0 : 0
        let headOffset = grounded ? placements.first { $0.x == man.x && $0.ball == 3 }?.offset(at: time) ?? 0 : 0
        let y = floorY
        let base = y + baseOffset
        let middle = base + middleOffset
        let head = middle + headOffset
        let coal = NSColor(calibratedWhite: 0.14, alpha: 1)
        let scarf = (man.scarf ?? .berry).color
        if grounded {
            ctx.setFillColor(NSColor(srgbRed: 0.14, green: 0.22, blue: 0.34, alpha: 0.25).cgColor)
            ctx.fillEllipse(in: CGRect(x: x - 26, y: y - 1, width: 54, height: 7))
        }
        snowball(in: ctx, x: x, y: base + 23, radius: snowmanBaseRadius)
        if man.balls >= 2 { snowball(in: ctx, x: x, y: middle + 54, radius: 18) }
        if man.balls == 3 { snowball(in: ctx, x: x, y: head + 78, radius: 14) }
        if man.balls >= 2 {
            ctx.setStrokeColor(NSColor.brown.cgColor)
            ctx.setLineWidth(2)
            for direction: CGFloat in [-1, 1] {
                ctx.move(to: CGPoint(x: x + direction * 14, y: middle + 53))
                ctx.addLine(to: CGPoint(x: x + direction * 32, y: middle + 64))
                ctx.addLine(to: CGPoint(x: x + direction * 35, y: middle + 72))
                ctx.move(to: CGPoint(x: x + direction * 32, y: middle + 64))
                ctx.addLine(to: CGPoint(x: x + direction * 38, y: middle + 65))
            }
            ctx.strokePath()
            circle(ctx, x, base + 27, 2, coal)
            for offset: CGFloat in [42, 55] { circle(ctx, x, middle + offset, 2, coal) }
            box(ctx, x-16, middle+62, 32, 6, scarf, radius: 3)
            box(ctx, x+6, middle+49, 6, 17, scarf, radius: 2)
            box(ctx, x+7, middle+51, 4, 2, white.withAlphaComponent(0.65))
            box(ctx, x-10, middle+63, 2, 4, white.withAlphaComponent(0.55))
            if christmas {
                let thread = NSColor(srgbRed: 1, green: 0.87, blue: 0.61, alpha: 0.64)
                for offset: CGFloat in [-14, -6, -2, 2] {
                    box(ctx, x + offset, middle + 63, 1.1, 4, thread)
                }
            }
        }
        if man.balls == 3 {
            circle(ctx, x-5, head+81, 1.7, coal)
            circle(ctx, x+5, head+81, 1.7, coal)
            polygon(ctx, [CGPoint(x: x-2, y: head+76), CGPoint(x: x+12, y: head+74),
                          CGPoint(x: x-2, y: head+72)], .systemOrange)
            if christmas {
                let velvet = NSColor(srgbRed: 0.66, green: 0.16, blue: 0.22, alpha: 1)
                let wool = NSColor(srgbRed: 1, green: 0.96, blue: 0.87, alpha: 1)
                let hat = CGMutablePath()
                hat.move(to: CGPoint(x: x-15, y: head+88))
                hat.addCurve(to: CGPoint(x: x+19, y: head+102),
                             control1: CGPoint(x: x-13, y: head+110), control2: CGPoint(x: x+4, y: head+116))
                hat.addCurve(to: CGPoint(x: x+14, y: head+88),
                             control1: CGPoint(x: x+7, y: head+103), control2: CGPoint(x: x+16, y: head+97))
                hat.closeSubpath()
                ctx.setFillColor(velvet.cgColor)
                ctx.addPath(hat)
                ctx.fillPath()
                box(ctx, x-17, head+86, 34, 6, wool, radius: 3)
                circle(ctx, x+20, head+102, 4, wool)
            } else {
                box(ctx, x-12, head+87, 24, 15, coal, radius: 2)
                box(ctx, x-17, head+87, 34, 4, coal, radius: 1)
                box(ctx, x-12, head+91, 24, 3, scarf)
            }
        }
    }

    private func sheen(_ color: NSColor) -> CGGradient {
        if let cached = sheens[color] { return cached }
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [color.blended(withFraction: 0.32, of: .black)!.cgColor,
                     color.cgColor,
                     color.blended(withFraction: 0.30, of: .white)!.cgColor] as CFArray,
            locations: [0, 0.54, 1])!
        sheens[color] = gradient
        return gradient
    }

    /// A rounded panel with a vertical sheen and a soft contour: the building
    /// block that gives the vehicles volume instead of flat silhouettes.
    private func shaded(_ ctx: CGContext, _ rect: CGRect, _ color: NSColor,
                        radius: CGFloat = 2, outline: CGFloat = 0.55) {
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.drawLinearGradient(sheen(color), start: CGPoint(x: 0, y: rect.minY),
                               end: CGPoint(x: 0, y: rect.maxY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
        guard outline > 0 else { return }
        ctx.setStrokeColor(NSColor(srgbRed: 0.08, green: 0.12, blue: 0.18, alpha: 0.42).cgColor)
        ctx.setLineWidth(outline)
        ctx.addPath(path)
        ctx.strokePath()
    }

    /// Diagonal warning hatching, clipped to the panel it belongs to.
    private func hazard(_ ctx: CGContext, _ rect: CGRect, _ light: NSColor, _ dark: NSColor, step: CGFloat = 7) {
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setFillColor(dark.cgColor)
        ctx.fill(rect)
        ctx.setFillColor(light.cgColor)
        var offset = rect.minX - rect.height
        while offset < rect.maxX {
            ctx.beginPath()
            ctx.addLines(between: [CGPoint(x: offset, y: rect.minY),
                                   CGPoint(x: offset + step * 0.52, y: rect.minY),
                                   CGPoint(x: offset + step * 0.52 + rect.height, y: rect.maxY),
                                   CGPoint(x: offset + rect.height, y: rect.maxY)])
            ctx.closePath()
            ctx.fillPath()
            offset += step
        }
        ctx.restoreGState()
    }

    /// A small wind-blown snow cap for roofs, bonnets and blade tops.
    private func snowCap(_ ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        path.addCurve(to: CGPoint(x: x + width, y: y),
                      control1: CGPoint(x: x + width * 0.22, y: y + height * 2.1),
                      control2: CGPoint(x: x + width * 0.74, y: y + height * 1.5))
        path.addLine(to: CGPoint(x: x + width, y: y - height * 0.55))
        path.addLine(to: CGPoint(x: x, y: y - height * 0.55))
        path.closeSubpath()
        ctx.setFillColor(NSColor(srgbRed: 0.96, green: 0.99, blue: 1, alpha: 1).cgColor)
        ctx.addPath(path)
        ctx.fillPath()
        ctx.setStrokeColor(SnowPaint.edge)
        ctx.setLineWidth(0.45)
        ctx.addPath(path)
        ctx.strokePath()
    }

    private func drawPlow(in ctx: CGContext) {
        guard plowX < bounds.width, plowX + 104 > 0 else { return }
        let x = plowX
        let y = floorY + 1
        let cabY = y + 2.5 * plowImpact * sin((1 - plowImpact) * 16)
        let dark = NSColor(srgbRed: 0.12, green: 0.17, blue: 0.24, alpha: 1)
        let rubber = NSColor(srgbRed: 0.10, green: 0.13, blue: 0.18, alpha: 1)
        let body = christmas ? NSColor(srgbRed: 0.69, green: 0.11, blue: 0.21, alpha: 1)
                             : NSColor(srgbRed: 0.95, green: 0.50, blue: 0.11, alpha: 1)
        let trim = christmas ? NSColor(srgbRed: 0.17, green: 0.43, blue: 0.32, alpha: 1)
                             : NSColor(srgbRed: 0.30, green: 0.41, blue: 0.50, alpha: 1)
        let cream = NSColor(srgbRed: 1, green: 0.95, blue: 0.85, alpha: 1)
        let glass = NSColor(srgbRed: 0.55, green: 0.79, blue: 0.89, alpha: 1)
        let headlight = NSColor(srgbRed: 1, green: 0.93, blue: 0.66, alpha: 1)

        // A pool of warm light on the snow ahead. A hard-edged cone would read
        // as a grey wedge cut out of the desktop instead of as light.
        let beam = christmas ? NSColor(srgbRed: 1, green: 0.84, blue: 0.52, alpha: 1) : headlight
        ctx.saveGState()
        ctx.translateBy(x: x + 88, y: y + 4)
        ctx.scaleBy(x: 1, y: 0.32)
        AdventPaint.stamp(ctx, CGRect(x: -34, y: -34, width: 68, height: 68), key: "plow-pool-\(christmas)") { canvas, size in
            let pool = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                colors: [beam.withAlphaComponent(0.30).cgColor, beam.withAlphaComponent(0.09).cgColor,
                         beam.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 0.46, 1])!
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            canvas.drawRadialGradient(pool, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: 34, options: [])
        }
        ctx.restoreGState()
        ctx.setFillColor(NSColor(srgbRed: 0.10, green: 0.17, blue: 0.27, alpha: 0.26).cgColor)
        ctx.fillEllipse(in: CGRect(x: x+2, y: y-2, width: 70, height: 4.6))

        // Exhaust puffs drift away before the truck is drawn over them.
        for index in 0..<3 {
            let life = (time * 0.62 + CGFloat(index) * 0.34).truncatingRemainder(dividingBy: 1)
            let radius = 1.5 + life * 3.6
            circle(ctx, x + 27.5 - life * 11, cabY + 42 + life * 12, radius,
                   NSColor(srgbRed: 0.84, green: 0.88, blue: 0.93, alpha: (1 - life) * 0.26))
        }

        shaded(ctx, CGRect(x: x+4, y: y+4, width: 54, height: 5), dark, radius: 1.5)
        for offset: CGFloat in [11, 39] {
            let wheelX = x + offset
            circle(ctx, wheelX, y+6, 7, rubber)
            ctx.setStrokeColor(NSColor(srgbRed: 0.27, green: 0.31, blue: 0.37, alpha: 0.9).cgColor)
            ctx.setLineWidth(1.5)
            for notch in 0..<9 {
                let angle = CGFloat(notch) * 2 * .pi / 9 - plowX / 7
                ctx.move(to: CGPoint(x: wheelX + cos(angle) * 5.5, y: y+6 + sin(angle) * 5.5))
                ctx.addLine(to: CGPoint(x: wheelX + cos(angle) * 7.1, y: y+6 + sin(angle) * 7.1))
            }
            ctx.strokePath()
            shaded(ctx, CGRect(x: wheelX-4.6, y: y+1.4, width: 9.2, height: 9.2), trim, radius: 4.6, outline: 0)
            ctx.setStrokeColor(cream.withAlphaComponent(0.75).cgColor)
            ctx.setLineWidth(1.1)
            for spoke in 0..<4 {
                let angle = CGFloat(spoke) * .pi / 2 - plowX / 7
                ctx.move(to: CGPoint(x: wheelX + cos(angle) * 1.6, y: y+6 + sin(angle) * 1.6))
                ctx.addLine(to: CGPoint(x: wheelX + cos(angle) * 3.9, y: y+6 + sin(angle) * 3.9))
            }
            ctx.strokePath()
            circle(ctx, wheelX, y+6, 1.5, cream)
            shaded(ctx, CGRect(x: wheelX-8.5, y: y+11, width: 17, height: 3.2), trim, radius: 1.5)
        }

        // Hopper at the back, cab at the front: the silhouette of a gritter.
        shaded(ctx, CGRect(x: x+2, y: y+9, width: 29, height: 17), body, radius: 2.5)
        hazard(ctx, CGRect(x: x+3.5, y: y+10, width: 26, height: 4.6), cream,
               christmas ? NSColor(srgbRed: 0.17, green: 0.43, blue: 0.32, alpha: 1) : dark)
        ctx.setStrokeColor(dark.withAlphaComponent(0.28).cgColor)
        ctx.setLineWidth(0.6)
        for rib: CGFloat in [9, 16, 23] {
            ctx.move(to: CGPoint(x: x+rib, y: y+16)); ctx.addLine(to: CGPoint(x: x+rib, y: y+25.4))
        }
        ctx.strokePath()
        shaded(ctx, CGRect(x: x+1, y: y+25, width: 31, height: 3), trim, radius: 1.4)
        snowCap(ctx, x: x+3, y: y+28, width: 27, height: 2.6)
        shaded(ctx, CGRect(x: x+26, y: cabY+26, width: 3.4, height: 15), dark, radius: 1.4)
        if christmas { for stripe in 0..<3 { box(ctx, x+26, cabY+29 + CGFloat(stripe)*4.4, 3.4, 1.8, cream, radius: 0.6) } }

        // Cab: rounded shell, deep window with a sky reflection, mirror and roof.
        shaded(ctx, CGRect(x: x+29, y: cabY+9, width: 23, height: 27), trim, radius: 4)
        let window = CGRect(x: x+32, y: cabY+20, width: 17, height: 12)
        shaded(ctx, window, glass, radius: 2, outline: 0.5)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: window, cornerWidth: 2, cornerHeight: 2, transform: nil))
        ctx.clip()
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.40).cgColor)
        ctx.setLineWidth(2.4)
        ctx.move(to: CGPoint(x: x+33, y: cabY+20)); ctx.addLine(to: CGPoint(x: x+40, y: cabY+33))
        ctx.move(to: CGPoint(x: x+42, y: cabY+20)); ctx.addLine(to: CGPoint(x: x+49, y: cabY+33))
        ctx.strokePath()
        ctx.restoreGState()
        box(ctx, x+31, cabY+13, 19, 4.6, trim.blended(withFraction: 0.26, of: .black)!, radius: 1.4)
        circle(ctx, x+34, cabY+15.4, 0.9, cream.withAlphaComponent(0.8))
        shaded(ctx, CGRect(x: x+28, y: cabY+35, width: 25, height: 3.2), trim, radius: 1.4)
        snowCap(ctx, x: x+29, y: cabY+38.2, width: 23, height: 2.4)
        shaded(ctx, CGRect(x: x+51.5, y: cabY+26, width: 4.5, height: 2.4), dark, radius: 1, outline: 0)

        // Blade: curved mouldboard, bright cutting edge, push arm.
        ctx.setStrokeColor(dark.withAlphaComponent(0.8).cgColor)
        ctx.setLineWidth(2.2)
        ctx.move(to: CGPoint(x: x+46, y: y+9)); ctx.addLine(to: CGPoint(x: x+57, y: y+15)); ctx.strokePath()
        let blade = CGMutablePath()
        blade.move(to: CGPoint(x: x+50, y: y))
        blade.addLine(to: CGPoint(x: x+53, y: y+24))
        blade.addQuadCurve(to: CGPoint(x: x+bladeTip, y: y+13), control: CGPoint(x: x+64, y: y+25))
        blade.addLine(to: CGPoint(x: x+bladeTip, y: y))
        blade.closeSubpath()
        ctx.saveGState()
        ctx.addPath(blade)
        ctx.clip()
        ctx.drawLinearGradient(sheen(body), start: CGPoint(x: x+50, y: y),
                               end: CGPoint(x: x+bladeTip, y: y+24),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        hazard(ctx, CGRect(x: x+50, y: y+4, width: bladeTip-50, height: 5.4), cream, dark, step: 5.5)
        ctx.setStrokeColor(dark.withAlphaComponent(0.30).cgColor)
        ctx.setLineWidth(0.7)
        for rib: CGFloat in [55, 59, 63] {
            ctx.move(to: CGPoint(x: x+rib, y: y+11)); ctx.addLine(to: CGPoint(x: x+rib, y: y+24))
        }
        ctx.strokePath()
        ctx.restoreGState()
        ctx.setStrokeColor(dark.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(0.55)
        ctx.addPath(blade)
        ctx.strokePath()
        shaded(ctx, CGRect(x: x+50, y: y-0.6, width: bladeTip-50, height: 2.8),
               NSColor(srgbRed: 0.74, green: 0.80, blue: 0.86, alpha: 1), radius: 0.8)
        snowCap(ctx, x: x+53, y: y+24, width: 11, height: 2)

        if christmas {
            // Garland along the hopper, a wreath on the door, warm string lights.
            ctx.setStrokeColor(NSColor(srgbRed: 0.15, green: 0.38, blue: 0.26, alpha: 1).cgColor)
            ctx.setLineWidth(2.4)
            ctx.move(to: CGPoint(x: x+3, y: y+23))
            ctx.addQuadCurve(to: CGPoint(x: x+30, y: y+23), control: CGPoint(x: x+16.5, y: y+19))
            ctx.strokePath()
            for index in 0..<6 {
                let fraction = (CGFloat(index) + 0.5) / 6
                let lx = x + 3 + fraction * 27
                let ly = y + 23 - sin(fraction * .pi) * 3.1
                circle(ctx, lx, ly, 1.25, index % 2 == 0 ? headlight : Scarf.berry.color)
            }
            ctx.setStrokeColor(Scarf.spruce.color.cgColor)
            ctx.setLineWidth(2.1)
            ctx.strokeEllipse(in: CGRect(x: x+33, y: cabY+9.5, width: 7.5, height: 7.5))
            circle(ctx, x+36.8, cabY+9.9, 1.2, Scarf.berry.color)
        }
        circle(ctx, x+51.5, cabY+16, 2.5, headlight)
        circle(ctx, x+51.5, cabY+16, 4.2, headlight.withAlphaComponent(0.26))
        circle(ctx, x+2.5, y+20, 1.5, .systemRed)
        // The beacon's glow in 16 steps of brightness, each a ready stamp.
        let beacon = (8 + 8 * sin(time * 10)).rounded() / 16
        // A soft amber glow fading out, not a flat disc: a flat disc turned
        // into a muddy brown patch over a dark desktop.
        let beaconCentre = CGPoint(x: x+40, y: cabY+40.2)
        let reach = 7 + 3 * beacon
        AdventPaint.stamp(ctx, CGRect(x: beaconCentre.x - reach, y: beaconCentre.y - reach, width: reach * 2, height: reach * 2),
                          key: "beacon-\(Int(beacon * 16))") { canvas, size in
            let beaconGlow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                        colors: [NSColor(srgbRed: 1, green: 0.72, blue: 0.22, alpha: 0.55 * beacon).cgColor,
                                                 NSColor(srgbRed: 1, green: 0.62, blue: 0.15, alpha: 0).cgColor] as CFArray,
                                        locations: [0, 1])!
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            canvas.drawRadialGradient(beaconGlow, startCenter: centre, startRadius: 1.5,
                                      endCenter: centre, endRadius: reach, options: [])
        }
        shaded(ctx, CGRect(x: x+37.6, y: cabY+38.4, width: 4.8, height: 3.6),
               beacon > 0.4 ? headlight : Scarf.gold.color, radius: 1.6, outline: 0.4)
        drawPlowLoad(in: ctx)
    }

    private func drawPlowLoad(in ctx: CGContext) {
        guard visiblePlowLoad > 0.08 else { return }
        let x = plowX + bladeTip - 2
        let y = floorY
        let depth = sqrt(min(plowLoadLimit,visiblePlowLoad))
        let height = depth * 1.9
        let width = depth * 5.8
        let crest = height * 0.98
        let mound = CGMutablePath()
        mound.move(to: CGPoint(x: x - 3, y: y))
        mound.addQuadCurve(to: CGPoint(x: x + width * 0.32, y: y + crest),
                           control: CGPoint(x: x - 0.5, y: y + height))
        mound.addCurve(to: CGPoint(x: x + width, y: y),
                       control1: CGPoint(x: x + width * 0.59, y: y + crest * 1.10),
                       control2: CGPoint(x: x + width * 0.70, y: y + height * 0.12))
        mound.closeSubpath()
        ctx.saveGState()
        ctx.setAlpha(min(1, depth * 0.7))
        SnowPaint.fillDrift(mound, base: y, crest: y + crest, in: ctx)
        ctx.restoreGState()
    }

    private func drawBuildGuide(in ctx: CGContext) {
        let text: String
        if let draft {
            let x = draft.x * bounds.width
            let isBelly = draft.balls == 1
            let radius: CGFloat = isBelly ? 18 : 14
            let covered = buildSiteIsCovered(x: x)
            drawBallGuide(x: x, y: nextBallY(for: draft), radius: radius,
                          color: covered ? .systemRed : ice, in: ctx)
            if covered {
                text = "Ein Fenster verdeckt den Bauplatz"
            } else {
                text = isBelly ? "2 / 3   ·   Klicke auf die Vorschau für den Bauch" : "3 / 3   ·   Klicke auf die Vorschau für den Kopf"
            }
        } else if let pointer = buildPointer, pointer.y < buildStripHeight {
            let site = buildSite(at: pointer)
            drawBallGuide(x: site.x, y: floorY + 23, radius: snowmanBaseRadius,
                          color: site.available ? ice : .systemRed, in: ctx)
            text = site.available ? "1 / 3   ·   Klicken, um die erste Kugel zu setzen" : "1 / 3   ·   Such dir unten einen freien Platz"
        } else {
            text = "1 / 3   ·   Bewege den Cursor an den unteren Bildschirmrand"
        }
        let label = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white
        ])
        let size = label.size()
        let x = (bounds.width - size.width) / 2
        box(ctx, x-16, 140, size.width+32, 34, NSColor(calibratedWhite: 0.10, alpha: 0.88), radius: 13)
        label.draw(at: CGPoint(x: x, y: 148))
    }

    private func drawBallGuide(x: CGFloat, y: CGFloat, radius: CGFloat, color: NSColor, in ctx: CGContext) {
        circle(ctx, x, y, radius, color.withAlphaComponent(0.34))
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(2)
        ctx.setLineDash(phase: 0, lengths: [4, 3])
        ctx.strokeEllipse(in: CGRect(x: x - radius, y: y - radius, width: 2 * radius, height: 2 * radius))
        ctx.restoreGState()
    }
}

final class Overlay: NSPanel {
    override var canBecomeMain: Bool { false }
    override var canBecomeKey: Bool { false }
}

/// The still valley on the desktop itself, above the desktop picture and
/// below the desktop icons and widgets.
/// Draws what lies in front of the Dock; it only ever shows the Dock's strip.
final class DockFrontView: NSView {
    weak var snow: SnowView?
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)
        snow?.drawDockFront(in: ctx)
    }
}

final class WallpaperView: NSView {
    var image: CGImage? { didSet { needsDisplay = true } }
    override var isOpaque: Bool { false }
    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)
        guard let image else { return }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: bounds)
    }
}

final class BuildStrip: FestiveCursorSurface {
    weak var snow: SnowView?
    var cancel: (() -> Void)?

    override func rightMouseDown(with event: NSEvent) { cancel?() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedRed: 0.4, green: 0.65, blue: 0.8, alpha: 0.085).setFill()
        bounds.fill()
    }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let snow, let window, let snowWindow = snow.window else { return }
        let point = snowWindow.convertPoint(fromScreen: window.convertPoint(toScreen: event.locationInWindow))
        snow.placeBall(at: snow.convert(point, from: nil))
    }
}

final class Winter: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate, NSMenuItemValidation {
    var overlays: [(panel: Overlay, snow: SnowView)] = []
    private var pressPassesThrough: Bool?
    private var lastIconScan: CFTimeInterval = 0
    private var iconScanBusy = false
    private let iconQueue = DispatchQueue(label: "schneetag.desktop-icons", qos: .utility)

    /// Reads where Finder's desktop icons lie (needs the Accessibility
    /// permission; without it nothing changes) and hands each overlay the
    /// frames in its own coordinates.
    func refreshDesktopIcons() {
        guard !iconScanBusy, AXIsProcessTrusted() else { return }
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
              let primary = NSScreen.screens.first?.frame else { return }
        iconScanBusy = true
        let pid = finder.processIdentifier
        iconQueue.async { [weak self] in
            let frames = DesktopIcons.frames(finder: pid, primaryHeight: primary.maxY)
            DispatchQueue.main.async {
                guard let self else { return }
                self.iconScanBusy = false
                for layer in self.overlays {
                    let origin = layer.panel.frame.origin
                    layer.snow.desktopIcons = frames.map { $0.offsetBy(dx: -origin.x, dy: -origin.y).insetBy(dx: -4, dy: -4) }
                }
            }
        }
    }

    @objc func allowDesktopIcons() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
    var buildPanel: Overlay?
    var status: NSStatusItem?
    private var fightMenuItem:NSMenuItem?
    private var fightHint:NSMenuItem?
    var controls: NSWindow?
    var pauseButton: NSButton?
    var buildButton: NSButton?
    var plowButton: NSButton?
    var densityPicker: NSPopUpButton?
    var scarfPicker: NSPopUpButton?
    var scarf: Scarf = .berry
    private var christmas = false
    private var pointerStyle: FestivePointerStyle = .candyCane
    private lazy var pointerKeeper = FestivePointerKeeper()
    private var village = true
    private var frostEnabled = true
    private let bannerFrost = BannerFrost()
    private var christmasButton: NSButton?
    private var frostButton: NSButton?
    private var frostPreview: NSWindow?
    let densities: [Double] = [0.5, 1.0, 1.65]
    var timer: Timer?
    private var displaysAsleep = false
    /// The login window or lock screen covers everything: nothing of the
    /// snow can be seen, so it rests just as when the displays sleep.
    private var screenLocked = false
    private var away: Bool { displaysAsleep || screenLocked }
    private var lastAwayCheck: CFTimeInterval = 0

    /// Asks the system directly whether anyone can see the screen. The sleep
    /// and lock notifications only report changes: launched while the
    /// display already slept (an update installed while nobody was there),
    /// Schneetag never heard about it and drew at full speed into the dark.
    private func checkAway() {
        // Only the running app asks the system; checks that drive the
        // controller by hand (no event loop) must not depend on whether the
        // Mac they run on happens to be locked.
        guard NSApp?.isRunning == true else { return }
        let asleep = NSScreen.screens.allSatisfy { screen in
            let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
            return CGDisplayIsAsleep(id) != 0
        }
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let locked = (session?["CGSSessionScreenIsLocked"] as? NSNumber)?.boolValue ?? false
        guard asleep != displaysAsleep || locked != screenLocked else { return }
        let wasAway = away
        displaysAsleep = asleep
        screenLocked = locked
        if away != wasAway {
            if away { endBuild() }
            updateOverlayActivity()
        }
    }
    var lastTime: TimeInterval = 0
    var lastScan: TimeInterval = 0
    private var lastCursorSample: TimeInterval = 0
    private var cursorShape = CursorShape.arrow
    var paused = false
    var plow = true
    var density: CGFloat = 1

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["plow": true, "density": 1.0, "frost": true,
                                     "village": true])
        christmas = defaults.bool(forKey: "christmas")
        pointerStyle = defaults.string(forKey: "pointerStyle").flatMap(FestivePointerStyle.init(rawValue:)) ?? .candyCane
        FestiveCursorArt.style = pointerStyle
        village = defaults.bool(forKey: "village")
        frostEnabled = defaults.bool(forKey: "frost")
        plow = defaults.bool(forKey: "plow")
        density = CGFloat(defaults.double(forKey: "density"))
        scarf = defaults.string(forKey: "scarf").flatMap(Scarf.init(rawValue:)) ?? .berry
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = status?.button {
            button.image = SnowmanArt.menuIcon
            button.setAccessibilityLabel("Schneetag – Schneemänner und Schneeballschlacht")
            button.toolTip = "Schneetag · Schneemänner & Schneeballschlacht"
        }
        refreshMenu()
        rebuild()
        applyPointer()
        #if SCHNEETAG_DEV
        // For measuring: SCHNEETAG_TEST_DAY=24 SCHNEETAG_TEST_HOUR=22 starts
        // straight in door test mode on that day, with every earlier door open.
        let environment = ProcessInfo.processInfo.environment
        // SCHNEETAG_TEST_ALL=1 starts with every door clickable at once, for
        // trying the calendar without the menu (which a full menu bar beside
        // the notch can hide).
        if environment["SCHNEETAG_TEST_ALL"] == "1" {
            toggleAllDoorsTest()
        }
        if let day = environment["SCHNEETAG_TEST_DAY"].flatMap(Int.init), (1...24).contains(day) {
            adventTestDefaults.set(Array(1..<day), forKey: "advent.opened.\(adventTestYear)")
            adventTestDay = day
            adventTestHour = environment["SCHNEETAG_TEST_HOUR"].flatMap(Int.init)
            for layer in overlays { applyAdventTest(to: layer.snow) }
            refreshMenu()
        }
        #endif
        if defaults.integer(forKey: "controlsVersion") < 2 {
            defaults.set(2, forKey: "controlsVersion")
            showControls()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(rebuild),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let workspaceNotifications = NSWorkspace.shared.notificationCenter
        workspaceNotifications.addObserver(self, selector: #selector(screensDidSleep),
                                           name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspaceNotifications.addObserver(self, selector: #selector(screensDidWake),
                                           name: NSWorkspace.screensDidWakeNotification, object: nil)
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(self, selector: #selector(screenLockChanged),
                                name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        distributed.addObserver(self, selector: #selector(screenLockChanged),
                                name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
        checkAway()
    }

    @objc func screenLockChanged() { checkAway() }

    func makePanel(_ frame: CGRect, interactive: Bool, belowDock: Bool = false) -> Overlay {
        let panel = Overlay(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = !interactive
        // The snow and the valley sit just under the Dock, above every
        // ordinary window: the Dock (also when it slides in) and its icons
        // stay in front. Frost on notification banners and the build strip
        // must stay above everything, as before.
        let dock = Int(CGWindowLevelForKey(.dockWindow))
        panel.level = belowDock ? NSWindow.Level(rawValue: dock - 1)
            : NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - (interactive ? 1 : 2))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.animationBehavior = .none
        panel.setFrame(frame, display: false)
        return panel
    }

    @objc func rebuild() {
        endBuild()
        bannerFrost.clear()
        for layer in overlays {
            layer.snow.workshop.save(); layer.panel.close(); layer.snow.wallpaperPanel?.close(); layer.snow.dockPanel?.close()
        }
        overlays = NSScreen.screens.map { screen in
            let panel = makePanel(screen.frame, interactive: false, belowDock: true)
            let snow = SnowView(frame: CGRect(origin: .zero, size: screen.frame.size))
            snow.displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
            let physicalWidth = CGDisplayScreenSize(snow.displayID).width
            snow.workshop.grabMargin = physicalWidth > 100 ? min(32,max(10,screen.frame.width/physicalWidth*5)) : 15
            snow.restoreSnowmen()
            snow.density = density
            snow.plowEnabled = plow
            snow.scarf = scarf
            snow.christmas = christmas
            snow.villageEnabled = village
            #if SCHNEETAG_DEV
            applyAdventTest(to: snow)
            #endif
            snow.safeArea = screen.visibleFrame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
            snow.finishBuild = { [weak self] in self?.endBuild() }
            panel.contentView = snow
            let paper = makePanel(screen.frame, interactive: false)
            paper.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)
            let paperView = WallpaperView(frame: CGRect(origin: .zero, size: screen.frame.size))
            paper.contentView = paperView
            snow.onBackdrop = { [weak paperView] image in paperView?.image = image }
            snow.wallpaperPanel = paper
            let front = makePanel(screen.frame, interactive: false)
            front.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
            let frontView = DockFrontView(frame: CGRect(origin: .zero, size: screen.frame.size))
            frontView.snow = snow
            front.contentView = frontView
            snow.dockPanel = front
            snow.dockView = frontView
            if !paused && !away {
                paper.orderFrontRegardless(); panel.orderFrontRegardless(); front.orderFrontRegardless()
            }
            return (panel, snow)
        }
        lastScan = 0
        updateTimer()
    }

    /// While nobody can see the screen, a slow check keeps asking whether
    /// that is still so. The wake and unlock notifications can arrive while
    /// the system still reports the old state; without this Schneetag would
    /// stay hidden until it is restarted.
    private var awayWatch: Timer?

    func updateTimer() {
        if away, !paused, !overlays.isEmpty {
            if awayWatch == nil {
                let watch = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.checkAway() }
                watch.tolerance = 0.5
                RunLoop.main.add(watch, forMode: .common)
                awayWatch = watch
            }
        } else {
            awayWatch?.invalidate()
            awayWatch = nil
        }
        if paused || away || overlays.isEmpty {
            timer?.invalidate()
            timer = nil
            return
        }
        let interval = overlays.contains { $0.snow.shouldAnimate } ? 1.0 / 60 : 1.0 / 10
        if timer?.timeInterval == interval { return }
        timer?.invalidate()
        let timer = Timer(timeInterval: interval, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = interval < 0.02 ? 0.001 : 0.015
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        lastTime = 0
    }

    @objc func screensDidSleep() {
        displaysAsleep = true
        endBuild()
        updateOverlayActivity()
    }

    @objc func screensDidWake() {
        displaysAsleep = false
        checkAway()
        updateOverlayActivity()
    }

    private func updateOverlayActivity() {
        let active = !paused && !away
        bannerFrost.clear()
        for layer in overlays { layer.snow.resetMotionTracking() }
        lastTime = 0
        lastScan = 0
        lastCursorSample = 0
        if active {
            lastScan = CACurrentMediaTime()
            scanWindows(interval: 1.0 / 30)
        }
        for layer in overlays {
            if active {
                layer.snow.wallpaperPanel?.orderFrontRegardless()
                layer.panel.orderFrontRegardless()
                layer.snow.dockPanel?.orderFrontRegardless()
            } else {
                layer.snow.wallpaperPanel?.orderOut(nil)
                layer.panel.orderOut(nil)
                layer.snow.dockPanel?.orderOut(nil)
            }
        }
        updateTimer()
    }

    @objc func tick() {
        guard !paused, !away else { return }
        let now = CACurrentMediaTime()
        if now - lastAwayCheck >= 2 {
            lastAwayCheck = now
            checkAway()
            if away { return }
        }
        let scanInterval = NSEvent.pressedMouseButtons == 0 ? 1.0 / 30 : 1.0 / 60
        if now - lastScan >= scanInterval - 0.001 {
            let interval = min(0.15, now - lastScan)
            lastScan = now
            scanWindows(interval: interval)
            updateTimer()
        }
        // A press that began outside Schneetag (dragging a desktop icon, a
        // file, a rubber band) passes straight through until it is let go,
        // so it can be dropped on a door or a snow pile like anywhere else.
        let mouse = NSEvent.mouseLocation
        // Only the running app looks at the real mouse: checks that drive the
        // controller by hand must not fail because someone clicked meanwhile.
        let buttons = NSApp?.isRunning == true ? NSEvent.pressedMouseButtons : 0
        if buttons == 0 {
            pressPassesThrough = nil
        } else if pressPassesThrough == nil {
            pressPassesThrough = !overlays.contains { !$0.panel.ignoresMouseEvents && $0.panel.frame.contains(mouse) }
        }
        let passThrough = pressPassesThrough == true
        if now - lastIconScan >= 1.5 {
            lastIconScan = now
            refreshDesktopIcons()
        }
        guard overlays.contains(where: { $0.snow.shouldAnimate }) else {
            for layer in overlays { layer.panel.ignoresMouseEvents = passThrough || layer.snow.workshop.held == nil }
            return
        }
        let dt = lastTime > 0 ? min(0.05, now - lastTime) : 1.0 / 60
        lastTime = now
        if now - lastCursorSample >= 0.10 {
            lastCursorSample = now
            sampleCursor(at:mouse,system:NSCursor.currentSystem)
        }
        for layer in overlays {
            guard layer.snow.shouldAnimate else {
                layer.panel.ignoresMouseEvents = passThrough || layer.snow.workshop.held == nil
                layer.snow.resetCursor()
                continue
            }
            let frame = layer.panel.frame
            let cursor = frame.contains(mouse) ? CGPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY) : nil
            layer.snow.workshop.moveHeld(to: cursor ?? CGPoint(x: mouse.x-frame.minX, y: mouse.y-frame.minY),time:now)
            layer.panel.ignoresMouseEvents = passThrough || !layer.snow.wantsInteraction(at: cursor)
            layer.snow.step(dt, cursor: cursor, shape: cursorShape)
        }
    }

    func sampleCursor(at mouse:CGPoint, system:NSCursor?) {
        let showingGrabHand = overlays.contains { layer in
            let frame = layer.panel.frame
            guard frame.contains(mouse) else { return false }
            return layer.snow.wantsInteraction(at:CGPoint(x:mouse.x-frame.minX,y:mouse.y-frame.minY))
        }
        // The larger click target and its hand icon must not enlarge the snow-pressure contour.
        if !showingGrabHand { cursorShape = system.flatMap(CursorShape.init) ?? CursorShape.arrow }
    }

    /// Ordinary windows that exist but were not on screen at the last full
    /// scan (minimised, hidden, on another Space), and when that scan was.
    private var hiddenWindows = Set<UInt32>()
    private var lastFullWindowScan: CFTimeInterval = 0
    private var lastOnscreenWindows = Set<UInt32>()

    func scanWindows(interval: CGFloat) {
        let screens = NSScreen.screens.map(\.frame)
        guard let primary = screens.first else {
            bannerFrost.clear()
            return
        }
        // Thirty times a second only the windows on screen are listed: the
        // full list of every window of every app, hidden ones included, runs
        // to hundreds and cost a seventh of all Schneetag did. It is only
        // needed to tell a closed window (its snow falls) from a hidden one
        // (its snow waits), so it is fetched when a window vanishes from the
        // screen, and every two seconds besides.
        let now = CACurrentMediaTime()
        var full = now - lastFullWindowScan >= 2
        guard var rows = CGWindowListCopyWindowInfo(full ? [.optionAll] : [.optionOnScreenOnly], kCGNullWindowID)
                as? [[String: Any]] else {
            bannerFrost.clear()
            return
        }
        if frostEnabled { bannerFrost.updateOwners(at: lastScan) }
        var windows: [(UInt32, CGRect)] = []
        var existingWindows = Set<UInt32>()
        var onscreenWindows = Set<UInt32>()
        var banners: [FrostBanner] = []
        // Desktop widgets live just above the desktop icons. They are cut
        // out of the valley like windows, so they always stay visible.
        var widgets: [CGRect] = []
        let iconLevel = Int(CGWindowLevelForKey(.desktopIconWindow))
        func parse() {
            windows.removeAll(); existingWindows.removeAll(); onscreenWindows.removeAll()
            banners.removeAll(); widgets.removeAll()
            for row in rows {
                guard let level = (row[kCGWindowLayer as String] as? NSNumber)?.intValue else { continue }
                let onscreen = (row[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue == true
                if level > iconLevel, level < iconLevel + 20, onscreen,
                   let dictionary = row[kCGWindowBounds as String] as? [String: Any],
                   let frame = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                   !frame.isEmpty, frame.width < primary.width * 0.8, frame.height < primary.height * 0.8 {
                    widgets.append(CGRect(x: frame.minX + primary.minX, y: primary.maxY - frame.maxY,
                                          width: frame.width, height: frame.height))
                    continue
                }
                let ordinary = (0...NSWindow.Level.modalPanel.rawValue).contains(level)
                let pid = (row[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
                let notification = frostEnabled && bannerFrost.systemPIDs.contains(pid)
                    && level >= 0 && level < NSWindow.Level.screenSaver.rawValue
                guard ordinary || notification,
                      let id = (row[kCGWindowNumber as String] as? NSNumber)?.uint32Value else { continue }
                if ordinary {
                    existingWindows.insert(id)
                    if onscreen { onscreenWindows.insert(id) }
                }
                guard onscreen,
                      let opacity = (row[kCGWindowAlpha as String] as? NSNumber)?.doubleValue, opacity > 0.1,
                      let dictionary = row[kCGWindowBounds as String] as? [String: Any],
                      let frame = CGRect(dictionaryRepresentation: dictionary as CFDictionary),
                      !frame.isEmpty else { continue }
                let screenFrame = CGRect(x: frame.minX + primary.minX, y: primary.maxY - frame.maxY,
                                         width: frame.width, height: frame.height)
                if notification, screens.contains(where: { FrostBanner.fits(screenFrame, on: $0) }) {
                    banners.append(FrostBanner(id: id, frame: screenFrame, level: level, opacity: min(1, opacity)))
                } else if ordinary {
                    windows.append((id, screenFrame))
                }
            }
        }
        parse()
        if !full, !lastOnscreenWindows.subtracting(onscreenWindows).isEmpty,
           let all = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] {
            // A window has left the screen: closed or only hidden? Ask now.
            full = true
            rows = all
            parse()
        }
        if full {
            lastFullWindowScan = now
            hiddenWindows = existingWindows.subtracting(onscreenWindows)
        } else {
            existingWindows = onscreenWindows.union(hiddenWindows)
        }
        lastOnscreenWindows = onscreenWindows
        bannerFrost.update(banners, at: lastScan, makePanel: { makePanel($0, interactive: false) },
                           onDismiss: { frame, growth in shedBannerFrost(frame, strength: growth) })
        for layer in overlays {
            let frame = layer.panel.frame
            // Keeps the Dock and menu bar clickable even when they move or resize.
            if let screen = layer.panel.screen ?? NSScreen.screens.first(where: { $0.frame == frame }) {
                layer.snow.safeArea = screen.visibleFrame.offsetBy(dx: -frame.minX, dy: -frame.minY)
            }
            let localWindows = windows.compactMap { id, window -> (UInt32, CGRect)? in
                guard window.intersects(frame) else { return nil }
                return (id, window.offsetBy(dx: -frame.minX, dy: -frame.minY))
            }
            let localBanners = banners.compactMap { banner -> CGRect? in
                guard banner.frame.intersects(frame) else { return nil }
                return banner.frame.offsetBy(dx: -frame.minX, dy: -frame.minY)
            }
            let localWidgets = widgets.compactMap { widget -> CGRect? in
                guard widget.intersects(frame) else { return nil }
                return widget.offsetBy(dx: -frame.minX, dy: -frame.minY)
            }
            layer.snow.syncWindows(localWindows, banners: localBanners, widgets: localWidgets,
                                   interval: interval, existingWindows:existingWindows)
        }
    }

    private func shedBannerFrost(_ frame: CGRect, strength: CGFloat) {
        guard !paused, !away else { return }
        for layer in overlays {
            let display = layer.panel.frame
            guard frame.intersects(display) else { continue }
            layer.snow.shedFrost(from: frame.offsetBy(dx: -display.minX, dy: -display.minY), strength: strength)
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let preview = frostPreview, notification.object as? NSWindow === preview else { return }
        let cap = preview.contentRect(forFrameRect: preview.frame)
            .insetBy(dx: FrostView.padding, dy: FrostView.padding)
        shedBannerFrost(cap, strength: 1)
    }

    func refreshMenu() {
        let menu = NSMenu()
        menu.delegate=self
        let heading = NSMenuItem(title: "Schneetag", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        add(menu, "Steuerung öffnen …", #selector(showControls))
        menu.addItem(.separator())
        add(menu, paused ? "Schnee fortsetzen" : "Schnee pausieren", #selector(togglePause))
        let intensity = NSMenuItem(title: "Schneefall", action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for (label, value) in [("Leicht", 0.5), ("Normal", 1.0), ("Dicht", 1.65)] {
            let item = add(choices, label, #selector(changeDensity(_:)))
            item.representedObject = value
            item.state = density == value ? .on : .off
        }
        intensity.submenu = choices
        menu.addItem(intensity)
        add(menu, "Schneepflug", #selector(togglePlow)).state = plow ? .on : .off
        add(menu, "Frost auf Mitteilungen", #selector(toggleFrost)).state = frostEnabled ? .on : .off
        menu.addItem(.separator())
        add(menu, "Weihnachtsmodus", #selector(toggleChristmas)).state = christmas ? .on : .off
        if christmas {
            add(menu, "Winterdorf mit Adventskalender", #selector(toggleVillage)).state = village ? .on : .off
            if village, let snow = overlays.first?.snow {
                menu.addItem(NSMenuItem(title: snow.adventStatus, action: nil, keyEquivalent: ""))
            }
            let pointerItem = NSMenuItem(title: "Weihnachtszeiger", action: nil, keyEquivalent: "")
            pointerItem.submenu = pointerMenu()
            menu.addItem(pointerItem)
        }
        menu.addItem(.separator())
        fightMenuItem=add(menu,"Schneeballschlacht starten",#selector(toggleSnowballFight))
        let hint=NSMenuItem(title:"Dafür zwei Schneemänner aus je 3 Kugeln stapeln",action:nil,keyEquivalent:"")
        menu.addItem(hint);fightHint=hint
        add(menu, "Schneemänner entfernen", #selector(clearSnowmen))
        add(menu, "Schnee wegfegen", #selector(clearSnow))
        menu.addItem(.separator())
        add(menu, "Schneetag beenden", #selector(quit), key: "q")
        status?.menu = menu
        updateFightMenu()
        pauseButton?.title = paused ? "Schnee fortsetzen" : "Schnee pausieren"
        buildButton?.title = buildPanel == nil ? "Schneemann bauen" : "Bauen abbrechen"
        plowButton?.state = plow ? .on : .off
        christmasButton?.state = christmas ? .on : .off
        frostButton?.state = frostEnabled ? .on : .off
        if let index = densities.firstIndex(of: density) { densityPicker?.selectItem(at: index) }
        scarfPicker?.selectItem(withTitle: scarf.title)
    }

    func menuWillOpen(_ menu:NSMenu) { updateFightMenu() }
    private func updateFightMenu() {
        let running=overlays.contains { $0.snow.fight.isRunning }
        let count=overlays.map { $0.snow.fightEligibleCount }.max() ?? 0
        fightMenuItem?.title=running ? "Schneeballschlacht beenden" : "Schneeballschlacht starten"
        fightMenuItem?.isEnabled=running || count>=2
        fightHint?.isHidden=running || count>=2
    }
    func validateMenuItem(_ menuItem:NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleSnowballFight) {
            return overlays.contains { $0.snow.fight.isRunning || $0.snow.fightEligibleCount>=2 }
        }
        return true
    }
    @objc func toggleSnowballFight() {
        if overlays.contains(where:{$0.snow.fight.isRunning}) {
            for layer in overlays { layer.snow.stopSnowballFight() }
        } else {
            if paused { togglePause() }
            for layer in overlays { layer.snow.startSnowballFight() }
        }
        refreshMenu()
    }

    @objc func showControls() {
        if controls == nil {
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 410, height: 388),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Schneetag"
            window.isReleasedWhenClosed = false
            window.center()
            let icon = NSImageView(image: NSImage(systemSymbolName: "snowflake", accessibilityDescription: nil)!)
            icon.symbolConfiguration = .init(pointSize: 28, weight: .medium)
            icon.contentTintColor = .systemBlue
            let intro = NSTextField(wrappingLabelWithString: "Schnee auf deinen Fenstern und ein kleiner Pflug am unteren Bildschirmrand.")
            intro.alignment = .center

            let picker = NSPopUpButton()
            picker.addItems(withTitles: ["Leicht", "Normal", "Dicht"])
            picker.target = self
            picker.action = #selector(pickDensity(_:))
            picker.setAccessibilityLabel("Schneefall")
            densityPicker = picker
            let snowRow = NSStackView(views: [NSTextField(labelWithString: "Schneefall"), picker])
            snowRow.spacing = 10

            let plowButton = NSButton(checkboxWithTitle: "Schneepflug", target: self, action: #selector(togglePlow))
            self.plowButton = plowButton
            let plowRow = NSStackView(views: [plowButton])
            plowRow.spacing = 10

            let scarfPicker = NSPopUpButton()
            scarfPicker.addItems(withTitles: Scarf.allCases.map(\.title))
            scarfPicker.target = self
            scarfPicker.action = #selector(pickScarf(_:))
            scarfPicker.setAccessibilityLabel("Schneemannschal")
            self.scarfPicker = scarfPicker
            let scarfRow = NSStackView(views: [NSTextField(labelWithString: "Schneemannschal"), scarfPicker])
            scarfRow.spacing = 10
            let pause = NSButton(title: "Schnee pausieren", target: self, action: #selector(togglePause))
            pause.bezelStyle = .rounded
            pauseButton = pause
            let actions = NSStackView(views: [pause])
            actions.spacing = 10
            let hint = NSTextField(labelWithString: "Schnee schieben, Kugeln anklicken und stapeln.")
            hint.textColor = .secondaryLabelColor
            hint.font = .systemFont(ofSize: 11)

            let christmasButton = NSButton(checkboxWithTitle: "Weihnachtsmodus", target: self,
                                           action: #selector(toggleChristmas))
            self.christmasButton = christmasButton
            let christmasRow = NSStackView(views: [christmasButton])
            christmasRow.spacing = 10
            let frostButton = NSButton(checkboxWithTitle: "Frost auf Mitteilungen", target: self,
                                       action: #selector(toggleFrost))
            self.frostButton = frostButton
            let preview = NSButton(title: "Frostvorschau", target: self, action: #selector(showFrostPreview))
            preview.bezelStyle = .rounded
            let frostRow = NSStackView(views: [frostButton, preview])
            frostRow.spacing = 10
            var rows: [NSView] = [icon, intro, snowRow, plowRow, scarfRow, christmasRow, frostRow, actions, hint]
            if !AXIsProcessTrusted() {
                // Lets Schneetag see where desktop icons lie, so a snowball
                // or a door never sits in the way of clicking one.
                let icons = NSButton(title: "Desktop-Symbole schützen …", target: self, action: #selector(allowDesktopIcons))
                icons.bezelStyle = .rounded
                icons.controlSize = .small
                rows.append(icons)
            }
            let stack = NSStackView(views: rows)
            stack.orientation = .vertical
            stack.alignment = .centerX
            stack.spacing = 13
            stack.translatesAutoresizingMaskIntoConstraints = false
            let content = FestiveCursorSurface()
            content.festiveCursor = christmas
            content.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
                intro.widthAnchor.constraint(equalToConstant: 280)
            ])
            window.contentView = content
            controls = window
        }
        refreshMenu()
        controls?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func pickDensity(_ picker: NSPopUpButton) {
        guard densities.indices.contains(picker.indexOfSelectedItem) else { return }
        setDensity(densities[picker.indexOfSelectedItem])
    }

    @discardableResult
    func add(_ menu: NSMenu, _ label: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: label, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc func togglePause() {
        paused.toggle()
        endBuild()
        updateOverlayActivity()
    }

    @objc func toggleChristmas() {
        christmas.toggle()
        UserDefaults.standard.set(christmas, forKey: "christmas")
        for layer in overlays { layer.snow.christmas = christmas }
        (controls?.contentView as? FestiveCursorSurface)?.festiveCursor = christmas
        (buildPanel?.contentView as? FestiveCursorSurface)?.festiveCursor = christmas
        applyPointer()
        refreshMenu()
    }

    // MARK: Door test mode

    /// Test mode pretends it is a given day in December, in a calendar of its
    /// own, so every door can be tried without touching the real one.
    // Door test mode: only in builds made with SCHNEETAG_DEV=1 ./build.sh,
    // never in the app people download.
    #if SCHNEETAG_DEV
    var adventTestDay: Int?
    var adventTestHour: Int?
    /// Test mode with every door clickable at once, not one per day.
    var adventTestAll = false
    private let adventTestDefaults = UserDefaults(suiteName: "local.schneetag.mac.adventtest")!

    private var adventTestYear: Int {
        let parts = Calendar(identifier: .gregorian).dateComponents([.year], from: Date())
        return parts.year ?? 2026
    }

    private func adventTestDate() -> Date? {
        guard let day = adventTestDay else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let now = calendar.dateComponents([.hour, .minute], from: Date())
        var parts = DateComponents()
        parts.year = adventTestYear; parts.month = 12; parts.day = day
        parts.hour = adventTestHour ?? now.hour ?? 12
        parts.minute = adventTestHour == nil ? (now.minute ?? 0) : 0
        return calendar.date(from: parts)
    }

    func applyAdventTest(to snow: SnowView) {
        if adventTestDay != nil {
            snow.adventCalendar = AdventCalendar(defaults: adventTestDefaults, anyDay: adventTestAll)
            snow.adventDate = adventTestDate()
        } else {
            snow.adventCalendar = AdventCalendar()
            snow.adventDate = nil
        }
        snow.refreshAdvent(force: true)
        snow.needsDisplay = true
    }

    /// Jump to a day: everything before it is already open, its own door waits.
    /// All doors at once: a fresh test calendar with every door shut and
    /// every one of them clickable straight in the village.
    @objc func toggleAllDoorsTest() {
        if adventTestAll { endAdventTest(); return }
        adventTestDefaults.removeObject(forKey: "advent.opened.\(adventTestYear)")
        adventTestAll = true
        adventTestDay = 24
        for layer in overlays { applyAdventTest(to: layer.snow) }
        refreshMenu()
    }

    @objc func closeAllTestDoors() {
        adventTestDefaults.removeObject(forKey: "advent.opened.\(adventTestYear)")
        for layer in overlays { applyAdventTest(to: layer.snow) }
        refreshMenu()
    }

    @objc func chooseTestDay(_ sender: NSMenuItem) {
        adventTestAll = false
        let day = sender.tag
        adventTestDefaults.set(Array(1..<day), forKey: "advent.opened.\(adventTestYear)")
        adventTestDay = day
        for layer in overlays { applyAdventTest(to: layer.snow) }
        refreshMenu()
    }

    @objc func nextTestDay() {
        guard let day = adventTestDay, day < 24 else { return }
        // Keep whatever was opened; just move the calendar on by a day.
        adventTestDay = day + 1
        for layer in overlays { applyAdventTest(to: layer.snow) }
        refreshMenu()
    }

    @objc func openTestDoor() {
        guard let day = adventTestDay else { return }
        for layer in overlays { layer.snow.openAdventDoor(day) }
        refreshMenu()
    }

    @objc func chooseTestHour(_ sender: NSMenuItem) {
        adventTestHour = sender.tag < 0 ? nil : sender.tag
        for layer in overlays { applyAdventTest(to: layer.snow) }
        refreshMenu()
    }

    @objc func endAdventTest() {
        adventTestAll = false
        adventTestDay = nil
        adventTestHour = nil
        for layer in overlays { applyAdventTest(to: layer.snow) }
        refreshMenu()
    }

    private func adventTestMenu() -> NSMenu {
        let menu = NSMenu()
        let info = NSMenuItem(title: adventTestAll ? "Test: alle Türchen anklickbar – dein echter Kalender bleibt unberührt"
                                : adventTestDay.map { "Test: \($0). Dezember – dein echter Kalender bleibt unberührt" }
                                ?? "Einen Tag wählen, sein Türchen im Dorf anklicken",
                              action: nil, keyEquivalent: "")
        menu.addItem(info)
        menu.addItem(.separator())
        let days = NSMenu()
        for day in 1...24 {
            let title = "\(day). Dezember – \(AdventGift.forDay(day).title)"
            let item = add(days, title, #selector(chooseTestDay(_:)))
            item.tag = day
            item.state = adventTestDay == day ? .on : .off
        }
        let dayItem = NSMenuItem(title: "Tag wählen", action: nil, keyEquivalent: "")
        dayItem.submenu = days
        menu.addItem(dayItem)
        let open = add(menu, "Heutiges Türchen öffnen", #selector(openTestDoor))
        open.isEnabled = adventTestDay != nil
        let next = add(menu, "Nächster Tag", #selector(nextTestDay))
        next.isEnabled = (adventTestDay ?? 24) < 24
        menu.addItem(.separator())
        for (title, hour) in [("Echte Uhrzeit", -1), ("Morgen, 8 Uhr", 8), ("Mittag, 13 Uhr", 13),
                              ("Abend, 18 Uhr", 18), ("Nacht, 22 Uhr", 22)] {
            let item = add(menu, title, #selector(chooseTestHour(_:)))
            item.tag = hour
            item.state = (adventTestHour ?? -1) == hour ? .on : .off
            item.isEnabled = adventTestDay != nil
        }
        menu.addItem(.separator())
        let end = add(menu, "Testmodus beenden", #selector(endAdventTest))
        end.isEnabled = adventTestDay != nil
        return menu
    }
    #endif

    @objc func toggleVillage() {
        village.toggle()
        UserDefaults.standard.set(village, forKey: "village")
        for layer in overlays { layer.snow.villageEnabled = village }
        refreshMenu()
    }

    private func pointerMenu() -> NSMenu {
        let menu = NSMenu()
        for style in FestivePointerStyle.allCases {
            let item = add(menu, style.title, #selector(changePointer(_:)))
            item.representedObject = style.rawValue
            item.state = pointerStyle == style ? .on : .off
            let cursor = style == .plain ? NSCursor.arrow : style == .peppermint ? FestiveCursorArt.candy[0] : FestiveCursorArt.arrow
            if let image = cursor.image.copy() as? NSImage {
                let scale = 16 / max(image.size.width, image.size.height)
                image.size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                item.image = image
            }
        }
        return menu
    }

    @objc func changePointer(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = FestivePointerStyle(rawValue: raw) else { return }
        pointerStyle = style
        FestiveCursorArt.style = style
        UserDefaults.standard.set(style.rawValue, forKey: "pointerStyle")
        for layer in overlays { layer.panel.invalidateCursorRects(for: layer.snow) }
        for window in NSApp.windows { window.contentView.map { window.invalidateCursorRects(for: $0) } }
        applyPointer()
        refreshMenu()
    }

    /// The Christmas pointer is on in Christmas mode unless the normal one
    /// was chosen.
    private func applyPointer() {
        if christmas, pointerStyle != .plain {
            if pointerKeeper.active { pointerKeeper.restyle() } else { pointerKeeper.start() }
        } else if pointerKeeper.active {
            pointerKeeper.stop()
        }
    }


    @objc func toggleFrost() {
        frostEnabled.toggle()
        UserDefaults.standard.set(frostEnabled, forKey: "frost")
        if !frostEnabled { bannerFrost.clear() }
        lastScan = 0
        refreshMenu()
    }


    @objc func showFrostPreview() {
        if frostPreview == nil {
            let size = CGSize(width: 362, height: 132)
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Frostvorschau"
            window.delegate = self
            window.isReleasedWhenClosed = false
            let frost = FrostView(frame: CGRect(origin: .zero, size: size))
            frost.wantsLayer = true
            let card = NSVisualEffectView(frame: frost.bounds.insetBy(dx: FrostView.padding, dy: FrostView.padding))
            card.material = .popover
            card.blendingMode = .withinWindow
            card.state = .active
            card.wantsLayer = true
            card.layer?.cornerRadius = 16
            card.layer?.masksToBounds = true
            let title = NSTextField(labelWithString: "Ein Wintergruß")
            title.font = .systemFont(ofSize: 15, weight: .semibold)
            let subtitle = NSTextField(labelWithString: "Beim Schließen fällt der Frost herunter.")
            subtitle.textColor = .secondaryLabelColor
            title.frame = CGRect(x: 20, y: 55, width: 280, height: 22)
            subtitle.frame = CGRect(x: 20, y: 34, width: 280, height: 18)
            card.addSubview(title)
            card.addSubview(subtitle)
            let content = NSView(frame: frost.bounds)
            content.addSubview(card)
            content.addSubview(frost)
            window.contentView = content
            frostPreview = window
        }
        if let preview = frostPreview, let screen = NSScreen.main {
            let workArea = screen.visibleFrame
            preview.setFrameTopLeftPoint(CGPoint(x: workArea.maxX - preview.frame.width - 14, y: workArea.maxY - 12))
        }
        frostPreview?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func togglePlow() { setPlow(!plow) }


    private func setPlow(_ enabled: Bool) {
        plow = enabled
        UserDefaults.standard.set(enabled, forKey: "plow")
        for layer in overlays { layer.snow.plowEnabled = enabled }
        refreshMenu()
    }

    @objc func pickScarf(_ picker: NSPopUpButton) {
        guard Scarf.allCases.indices.contains(picker.indexOfSelectedItem) else { return }
        setScarf(Scarf.allCases[picker.indexOfSelectedItem])
    }

    @objc func changeScarf(_ item: NSMenuItem) {
        guard let rawValue = item.representedObject as? String, let style = Scarf(rawValue: rawValue) else { return }
        setScarf(style)
    }

    private func setScarf(_ style: Scarf) {
        scarf = style
        UserDefaults.standard.set(style.rawValue, forKey: "scarf")
        for layer in overlays { layer.snow.scarf = style }
        refreshMenu()
    }

    @objc func changeDensity(_ item: NSMenuItem) {
        guard let value = item.representedObject as? Double else { return }
        setDensity(value)
    }

    func setDensity(_ value: Double) {
        density = CGFloat(value)
        UserDefaults.standard.set(value, forKey: "density")
        for layer in overlays { layer.snow.density = density }
        refreshMenu()
    }

    @objc func toggleBuild() {
        if buildPanel != nil { endBuild(); return }
        if paused { togglePause() }
        let mouse = NSEvent.mouseLocation
        guard let layer = overlays.first(where: { $0.panel.frame.contains(mouse) }) ?? overlays.first else { return }
        layer.snow.building = true
        var frame = layer.panel.frame
        frame.size.height = min(buildStripHeight, frame.height)
        let panel = makePanel(frame, interactive: true)
        let strip = BuildStrip(frame: CGRect(origin: .zero, size: frame.size))
        strip.snow = layer.snow
        strip.festiveCursor = christmas
        strip.cancel = { [weak self] in self?.endBuild() }
        let cancel = NSButton(title: "Abbrechen", target: self, action: #selector(cancelBuild))
        cancel.bezelStyle = .rounded
        cancel.translatesAutoresizingMaskIntoConstraints = false
        strip.addSubview(cancel)
        NSLayoutConstraint.activate([
            cancel.trailingAnchor.constraint(equalTo: strip.trailingAnchor, constant: -16),
            cancel.topAnchor.constraint(equalTo: strip.topAnchor, constant: 10)
        ])
        panel.contentView = strip
        buildPanel = panel
        panel.orderFrontRegardless()
        refreshMenu()
    }

    @objc func cancelBuild() { endBuild() }

    func endBuild() {
        buildPanel?.close()
        buildPanel = nil
        for layer in overlays {
            layer.snow.building = false
            layer.snow.cancelBuild()
        }
        refreshMenu()
    }

    @objc func clearSnowmen() {
        endBuild()
        for layer in overlays {
            layer.snow.clearSnowmen()
        }
    }

    @objc func clearSnow() {
        if buildPanel != nil { endBuild() }
        for layer in overlays {
            layer.snow.clearSnow()
        }
        lastScan = 0
    }

    @objc func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControls()
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        if pointerKeeper.active { pointerKeeper.stop() }
        for layer in overlays { layer.snow.workshop.save() }
    }

    @objc func quit() { NSApp.terminate(nil) }
}


/// Finder's desktop icons through the Accessibility interface: the desktop
/// is a scroll area of Finder whose children are the icons.
enum DesktopIcons {
    static func frames(finder pid: pid_t, primaryHeight: CGFloat) -> [CGRect] {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        func value(_ element: AXUIElement, _ name: String) -> AnyObject? {
            var result: AnyObject?
            return AXUIElementCopyAttributeValue(element, name as CFString, &result) == .success ? result : nil
        }
        func frame(_ element: AXUIElement) -> CGRect? {
            guard let p = value(element, kAXPositionAttribute), let s = value(element, kAXSizeAttribute),
                  CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
            var point = CGPoint.zero, size = CGSize.zero
            AXValueGetValue(p as! AXValue, .cgPoint, &point)
            AXValueGetValue(s as! AXValue, .cgSize, &size)
            guard size.width > 4, size.height > 4, size.width < 600, size.height < 600 else { return nil }
            // Accessibility counts from the top of the main screen, AppKit from the bottom.
            return CGRect(x: point.x, y: primaryHeight - point.y - size.height, width: size.width, height: size.height)
        }
        var found: [CGRect] = []
        func collect(_ element: AXUIElement, depth: Int) {
            guard depth < 4, let children = value(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
            for child in children {
                let role = value(child, kAXRoleAttribute) as? String ?? ""
                if role == kAXImageRole as String || role == "AXFinderItem", let f = frame(child) {
                    found.append(f)
                } else if role == kAXGroupRole as String || role == kAXScrollAreaRole as String || role == kAXListRole as String {
                    collect(child, depth: depth + 1)
                }
            }
        }
        // Only the desktop scroll area, never Finder's own windows.
        for child in value(app, kAXChildrenAttribute) as? [AXUIElement] ?? []
        where (value(child, kAXRoleAttribute) as? String) == kAXScrollAreaRole as String {
            collect(child, depth: 0)
        }
        return found
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let winter = Winter()
app.delegate = winter
app.run()

