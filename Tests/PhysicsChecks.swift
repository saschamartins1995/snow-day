import AppKit
// The visitor mechanics are checked on their own; whether doors unlock
// them is checked in testAdventUnlocksVisitors.
SnowView.visitorsNeedDoors = false

let app = NSApplication.shared
let testOutput = ProcessInfo.processInfo.environment["SNOW_TEST_OUTPUT"]!

func checkWind() {
    let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 800, height: 580))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
    snow.density = 0
    snow.plowEnabled = false
    snow.step(0)
    snow.flakes = [
        Flake(x: 819.9, y: 330, vx: 78, vy: -80, radius: 2.1),
        Flake(x: -19.9, y: 200, vx: -78, vy: -80, radius: 2.1)
    ]
    snow.step(1 / 60)
    precondition(snow.flakes.count == 2 && snow.flakes[0].x < -17 && snow.flakes[1].x > 817)
    precondition(snow.flakes[0].y > 328 && snow.flakes[1].y > 198)
    snow.clearSnow()
    snow.density = 0.66
    var columns = Array(repeating: 0, count: 8)
    var evaluated = 0
    for frame in 0..<6600 {
        snow.step(1 / 60)
        if frame > 600, frame % 15 == 0 {
            evaluated += 1
            for flake in snow.flakes where flake.y > 75 && flake.y < 500 && flake.x >= 0 && flake.x < 800 {
                columns[Int(flake.x / 100)] += 1
            }
        }
    }
    let average = CGFloat(columns.reduce(0, +)) / CGFloat(columns.count)
    precondition(columns.allSatisfy { CGFloat($0) >= average * 0.87 }, "Snowfall distribution: \(columns)")
    print("Crosswind: \(columns), \(evaluated) samples, both directions")
}

func checkPlowFlow() {
    let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 800, height: 450))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
    snow.density = 0
    snow.plowX = 15
    snow.step(0)
    for i in 11...40 { snow.ground[i] = 11 }
    for _ in 0..<118 {
        snow.step(1 / 60)
        precondition(snow.plowLoad <= plowLoadLimit)
        precondition(snow.flakes.isEmpty,"Small snowplow must not create feedback from snow thrown out in front of the blade")
        precondition(snow.ground.max()! <= 11)
    }
    precondition(snow.plowLoad > 5 && snow.ground.reduce(0,+) >= 318)
    let mass = snow.ground.reduce(0, +) + snow.plowLoad + snow.plowRemoved + snow.flakes.reduce(0, { $0 + $1.looseSnow })
    precondition(abs(mass - 330) < 0.0001)
    snow.plowEnabled = false
    for _ in 0..<55 { snow.step(1 / 60) }
    precondition(snow.flakes.isEmpty && abs(snow.ground.reduce(0, +) - 330) < 0.0001, "Unload \(snow.flakes.count), ground \(snow.ground.reduce(0, +))")
    print("Small snowplow: limited load, no re-collected discharge, mass conserved when switched off")
}

func checkWedgePaint() throws {
    let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 480, height: 190))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
    snow.density = 0
    snow.plowEnabled = false
    snow.step(0)
    for i in 23...26 { snow.ground[i] = 4 }
    let pointer = CursorShape(rows: [CGRect(x: -2, y: -2, width: 4, height: 4)])
    snow.step(0, cursor: CGPoint(x: 145, y: floorY + 3), shape: pointer)
    snow.step(1 / 60, cursor: CGPoint(x: 225, y: floorY + 3), shape: pointer)
    precondition(snow.ground.reduce(0, +) == 0 && !snow.surfaceTransfers.isEmpty)
    let bitmap = snow.bitmapImageRepForCachingDisplay(in: snow.bounds)!
    snow.cacheDisplay(in: snow.bounds, to: bitmap)
    let scale = CGFloat(bitmap.pixelsWide) / snow.bounds.width
    let hasPaint = (4..<10).contains { y in
        (178..<225).contains { x in
            (bitmap.colorAt(x: Int(CGFloat(x) * scale), y: bitmap.pixelsHigh - Int(CGFloat(y) * scale))?.alphaComponent ?? 0) > 0.18
        }
    }
    precondition(hasPaint, "Moving snow must remain visible between its origin and its destination")
    try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: testOutput + "/wedge.png"))
    print("Pointer push: snow ridge is visible before it reaches its destination")
}

checkWind()
checkPlowFlow()
try checkWedgePaint()
func checkEdgeTravel() {
    let view = SnowView(frame: CGRect(x: 0, y: 0, width: 800, height: 450))
view.workshopEnabled = false
view.heavyPlow.enabled = false
    view.plowEnabled = false
    view.density = 0
    let window = CGRect(x: 170, y: 100, width: 400, height: 230)
    view.syncWindows([(1, window)])
    view.step(0)
    view.ledges[1]!.snow[14] = 8
    let sourceX: CGFloat = 302
    view.step(0, cursor: CGPoint(x: 280, y: 334))
    view.step(1/60, cursor: CGPoint(x: 780, y: 334))
    precondition(!view.surfaceTransfers.isEmpty && view.runoff.isEmpty)
    precondition(view.surfaceTransfers.allSatisfy { abs($0.position.x - sourceX) < 30 })
    var crossedRim = false
    var fellOutside = false
    for _ in 0..<160 {
        view.step(1/120)
        crossedRim = crossedRim || view.runoff.contains { $0.position.x > window.maxX - 16 }
        fellOutside = fellOutside || view.flakes.contains { $0.looseSnow > 0 && $0.x > window.maxX }
    }
    precondition(crossedRim && fellOutside)
    let mass = view.ledges[1]!.snow.reduce(0,+) + view.ground.reduce(0,+) + view.flakes.reduce(0, { $0 + $1.looseSnow })
    precondition(abs(mass-8) < 0.0001)
    print("Fast push: continuous path, rounded corner, falling outside the window, mass conserved")
}
checkEdgeTravel()
func checkFrameTiming() {
    func track(intervals: [CGFloat]) -> [CGFloat] {
        let view = SnowView(frame: CGRect(x:0,y:0,width:800,height:450))
view.workshopEnabled = false
view.heavyPlow.enabled = false
        view.density = 0
        view.plowEnabled = false
        view.step(0)
        for i in 28...38 { view.ground[i] = 8 }
        view.step(0,cursor: CGPoint(x:170,y:5.5))
        var elapsed: CGFloat = 0
        var sample = 0
        while elapsed < 2 - 0.00000001 {
            let boundary: CGFloat = elapsed < 1 - 0.00000001 ? 1 : 2
            let dt = min(intervals[sample % intervals.count], boundary-elapsed)
            elapsed += dt
            let x = elapsed <= 1 ? 170 + 290 * elapsed : 460 - 290 * (elapsed-1)
            view.step(dt,cursor: CGPoint(x:x,y:5.5))
            let mass = view.ground.reduce(0,+) + view.surfaceTransfers.reduce(0,{$0+$1.amount})
                + view.flakes.reduce(0,{$0+$1.looseSnow})
            precondition(abs(mass-88) < 0.003)
            sample += 1
        }
        for _ in 0..<120 { view.step(1/120) }
        return view.ground
    }
    let schedules: [[CGFloat]] = [[1.0/30],[1.0/60],[1.0/120],[1.0/36,1.0/95,1.0/45,1.0/120]]
    let histories = schedules.map { track(intervals:$0) }
    let centers = histories.map { ground in
        ground.enumerated().reduce(0.0) { $0 + (CGFloat($1.offset)+0.5)*8*$1.element } / ground.reduce(0,+)
    }
    precondition(centers.max()! - centers.min()! < 2, "Unstable cursor contact: \(centers)")
    print("30/60/120 and uneven frame rates: centers of mass \(centers)")
}
checkFrameTiming()
func scenario0() throws {
let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 800, height: 500))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
snow.density = 0
snow.plowEnabled = false
let sill = CGRect(x: 170, y: 100, width: 350, height: 160)
snow.syncWindows([(1, sill)])
for index in 3..<15 { snow.ledges[1]!.snow[index] = 0.5 }
snow.syncWindows([(1, sill.offsetBy(dx: 0, dy: 40))])
let removed = 6 - snow.ledges[1]!.snow.reduce(0, +)
precondition(removed > 0.2 && snow.flakes.isEmpty)
for _ in 0..<7 { snow.step(1 / 60) }
precondition((2...4).contains(snow.flakes.count))
precondition(abs(snow.flakes.reduce(0, { $0 + $1.looseSnow }) - removed) < 0.0001)
for _ in 0..<100 { snow.step(1 / 60) }
precondition(snow.flakes.isEmpty && abs(snow.ground.reduce(0, +) - removed) < 0.0001)
snow.clearSnow()
snow.step(0)
snow.ground[22] = 2
let pointer = CursorShape(rows: [CGRect(x: -2, y: -2, width: 4, height: 4)])
snow.step(0, cursor: CGPoint(x: 181, y: floorY + 2), shape: pointer)
snow.step(1 / 60, cursor: CGPoint(x: 181.4, y: floorY + 2), shape: pointer)
precondition(!snow.surfaceTransfers.isEmpty && snow.ground[22] < 2)
for _ in 0..<12 { snow.step(1 / 60) }
precondition(snow.ground[22] < 2 && snow.ground[24] > 0 && snow.ground[25] > 0)
precondition(abs(snow.ground.reduce(0, +) - 2) < 0.0001)
snow.syncWindows([(1, sill)])
snow.ledges[1]!.snow[4] = 8
// This is about the snow on the window edge: Christmas mode must not change it.
// The winter village is a separate, intentional layer and is switched off for
// this comparison; it has its own checks.
snow.villageEnabled = false
func shot(_ festive: Bool) -> Data {
    snow.christmas = festive
    let rep = snow.bitmapImageRepForCachingDisplay(in: snow.bounds)!
    snow.cacheDisplay(in: snow.bounds, to: rep)
    return rep.representation(using: .png, properties: [:])!
}
precondition(shot(false) == shot(true))
print("Checked: powder bundled, snow amount conserved, slow pointer push and no lights on the window edge")

}
FileHandle.standardError.write(Data("v124-bursts.swift\n".utf8))
try scenario0()
func scenario2() throws {
func scene() -> SnowView {
    let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 520, height: 360))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
    snow.density = 0
    snow.plowEnabled = false
    snow.step(0)
    return snow
}
let snow = scene()
let window = CGRect(x: 90, y: 100, width: 340, height: 145)
snow.syncWindows([(1, window)])
snow.flakes = [
    Flake(x: 210, y: 247, vx: 0, vy: -160, radius: 3, phase: 0, depth: .distant),
    Flake(x: 240, y: 247, vx: 0, vy: -160, radius: 3, phase: 0, depth: .middle),
    Flake(x: 270, y: 247, vx: 0, vy: -160, radius: 3, phase: 0, depth: .near)
]
snow.step(1 / 60)
precondition(snow.flakes.count == 1 && snow.flakes[0].depth == .distant && snow.flakes[0].y < window.maxY)
func alpha(at point: CGPoint, on snow: SnowView) -> CGFloat {
    let bitmap = snow.bitmapImageRepForCachingDisplay(in: snow.bounds)!
    snow.cacheDisplay(in: snow.bounds, to: bitmap)
    let scale = CGFloat(bitmap.pixelsWide) / snow.bounds.width
    return bitmap.colorAt(x: Int(point.x * scale), y: Int((snow.bounds.height - point.y) * scale))!.alphaComponent
}
for _ in 0..<12 { snow.step(1 / 60) }
let hidden = CGPoint(x: snow.flakes[0].x, y: snow.flakes[0].y)
precondition(window.contains(hidden) && alpha(at: hidden, on: snow) == 0)
for _ in 0..<53 { snow.step(1 / 60) }
let appeared = CGPoint(x: snow.flakes[0].x, y: snow.flakes[0].y)
precondition(appeared.y < window.minY && alpha(at: appeared, on: snow) > 0.35)
precondition(abs(ledgeDeposit * 0.680 / 0.026 - 1.20) < 0.0001)
precondition(abs(groundDeposit * 0.955 / 0.031 - 1.20) < 0.0001)
let smoothing = scene()
smoothing.ground[30] = 13
for _ in 0..<90 { smoothing.step(1 / 60) }
precondition(smoothing.ground[30] < 8 && smoothing.ground[28] > 0.1 && smoothing.ground[32] > 0.1)
precondition(abs(smoothing.ground.reduce(0, +) - 13) < 0.0001)
smoothing.clearSnow()
smoothing.step(0)
smoothing.plowX = 128
smoothing.plowEnabled = true
smoothing.ground[25] = 12
smoothing.step(1 / 60)
precondition(smoothing.ground[24] > 0 && smoothing.ground[25] < 12,
             "Even at a full blade, a tall pile must be able to slump sideways")
precondition(abs(smoothing.ground.reduce(0,+)+smoothing.plowLoad-12)<0.0001)

func bitmap(_ cursor: NSCursor) -> NSBitmapImageRep {
    NSBitmapImageRep(cgImage: cursor.image.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
}
let arrow = FestiveCursorArt.arrow
precondition(arrow.hotSpot == NSCursor.arrow.hotSpot && arrow.image.size == NSCursor.arrow.image.size)
let original = bitmap(NSCursor.arrow)
let festive = bitmap(arrow)
precondition(original.pixelsWide == festive.pixelsWide && original.pixelsHigh == festive.pixelsHigh)
var candyRed = 0
for y in 0..<festive.pixelsHigh {
    for x in 0..<festive.pixelsWide {
        let a = original.colorAt(x: x, y: y)!
        let b = festive.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
        precondition(abs(a.alphaComponent - b.alphaComponent) < 0.01)
        if b.alphaComponent > 0.8 && b.redComponent > b.blueComponent + 0.24 { candyRed += 1 }
    }
}
precondition(candyRed > 25)
let frame0 = bitmap(FestiveCursorArt.candy[0])
let frame4 = bitmap(FestiveCursorArt.candy[4])
precondition(frame0.representation(using: .png, properties: [:]) != frame4.representation(using: .png, properties: [:]))
// The pointer keeper tells the system's pictures from the festive ones.
let plainMarks = [NSCursor.arrow, .openHand, .closedHand, .iBeam, .pointingHand].map(FestivePointerKeeper.mark)
let festiveMarks = [FestiveCursorArt.arrow, FestiveCursorArt.openHand, FestiveCursorArt.closedHand,
                    FestiveCursorArt.candy[0]].map(FestivePointerKeeper.mark)
precondition(Set(plainMarks).count == plainMarks.count && Set(festiveMarks).count == festiveMarks.count)
precondition(Set(plainMarks).isDisjoint(with: festiveMarks), "Christmas pointer and system pointer must be distinguishable")
precondition(FestivePointerKeeper.mark(NSCursor.arrow) == FestivePointerKeeper.mark(NSCursor.arrow))
FestiveCursorArt.style = .plain
precondition(FestiveCursorArt.pointer == nil && FestiveCursorArt.open(true) === NSCursor.openHand)
FestiveCursorArt.style = .peppermint
precondition(FestiveCursorArt.pointer === FestiveCursorArt.candy[0])
FestiveCursorArt.style = .candyCane
print("Checked: three depths, window mask, 20 percent, smoothed ground, original outline and animated loading ball")

}
FileHandle.standardError.write(Data("v124-depth-ground-cursors.swift\n".utf8))
try scenario2()
func scenario3() throws {
let frame = CGRect(x: 0, y: 0, width: 800, height: 500)
let snow = SnowView(frame: frame)
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
snow.density = 0
snow.plowEnabled = false
snow.step(0)
let pointer = CursorShape(rows: [CGRect(x: -2, y: -2, width: 4, height: 4)])
for index in 24...27 { snow.ground[index] = 4 }
snow.step(0, cursor: CGPoint(x: 90, y: floorY + 3), shape: pointer)
snow.step(1 / 60, cursor: CGPoint(x: 420, y: floorY + 3), shape: pointer)
precondition(snow.surfaceTransfers.reduce(0, { $0 + $1.amount }) == 16)
snow.step(1 / 60, cursor: CGPoint(x: 185, y: floorY + 3), shape: pointer)
precondition(snow.surfaceTransfers.contains(where: { $0.direction == -1 && $0.lift > 0 }))
precondition(snow.flakes.contains(where: { $0.x > 185 && $0.looseSnow > 0 }))
for _ in 0..<90 { snow.step(1 / 60) }
precondition(abs(snow.ground.reduce(0, +) - 16) < 0.0001)
snow.clearSnow()
let window = CGRect(x: 170, y: 100, width: 350, height: 160)
snow.syncWindows([(1, window)])
let moved = window.offsetBy(dx: 30, dy: 0)
snow.syncWindows([(1, moved)], interval: 1 / 60)
let v = snow.ledges[1]!.windowVelocity
precondition(v > 80 && v < 450)
snow.step(1 / 60)
snow.syncWindows([(1, moved)], interval: 1 / 60)
precondition(snow.ledges[1]!.windowVelocity == v)
for _ in 0..<4 { snow.step(1 / 60) }
snow.syncWindows([(1, moved)], interval: 1 / 60)
precondition(snow.ledges[1]!.windowVelocity == 0)
let frost = BannerFrost()
let winter = Winter()
let banner = FrostBanner(id: 7, frame: CGRect(x: 454, y: 380, width: 330, height: 88), level: 25, opacity: 1)
var dismissed = 0
func scan(_ banners: [FrostBanner], at time: TimeInterval) {
    frost.update(banners, at: time, makePanel: { winter.makePanel($0, interactive: false) }, onDismiss: { frame, growth in
        dismissed += 1
        precondition(frame == banner.frame && growth > 0.7)
        snow.shedFrost(from: frame, strength: growth)
    })
}
scan([banner], at: 1)
scan([banner], at: 2)
scan([], at: 2.03)
scan([banner], at: 2.08)
precondition(dismissed == 0)
scan([], at: 2.12)
scan([], at: 2.28)
scan([], at: 2.38)
precondition(dismissed == 1 && snow.flakes.contains(where: { $0.frostShard }))
precondition(snow.flakes.allSatisfy { $0.x > banner.frame.minX && $0.y > 460 })
for _ in 0..<110 { snow.step(1 / 60) }
precondition(snow.flakes.isEmpty && snow.ground.reduce(0, +) > 0.2)
print("Checked: pointer push, ridge and backward dumping, window sampling and frost after closing")

}
FileHandle.standardError.write(Data("v124-frost-push.swift\n".utf8))
try scenario3()
func scenario4() throws {
let screen = CGRect(x: 0, y: 0, width: 800, height: 500)
let window = CGRect(x: 160, y: 160, width: 320, height: 240)
func physicsView() -> SnowView {
    let view = SnowView(frame: screen)
view.workshopEnabled = false
view.heavyPlow.enabled = false
    view.plowEnabled = false
    view.density = 0
    view.syncWindows([(1, window)])
    return view
}
let snow = physicsView()
snow.flakes = [Flake(x: 243, y: 401, vx: 0, vy: -100, radius: 3, phase: 0)]
snow.step(1 / 60)
precondition(abs(snow.ledges[1]!.snow.reduce(0, +) - 3 * 1.16 * ledgeDeposit) < 0.001)
snow.ledges[1]!.snow = snow.ledges[1]!.snow.indices.map { snow.ledges[1]!.capacity(at: $0) }
snow.flakes = [Flake(x: 243, y: 412, vx: 0, vy: -100, radius: 3)]
snow.step(1 / 60)
precondition(snow.flakes.isEmpty && abs(snow.runoff.reduce(0) { $0 + $1.amount } - 3 * 1.16 * ledgeDeposit) < 0.001 && snow.runoff.allSatisfy { $0.direction == -1 })
func movedSnow(dx: CGFloat) -> CGFloat {
    let view = physicsView()
    view.ledges[1]!.snow[10] = 8
    view.syncWindows([(1, window.offsetBy(dx: dx, dy: 0))])
    for _ in 0..<8 { view.step(1 / 60) }
    return view.ledges[1]!.snow[0..<10].reduce(0, +)
}
let gentle = movedSnow(dx: 1.5)
let fast = movedSnow(dx: 32)
precondition(gentle > 0 && fast > gentle * 3)
let knocked = physicsView()
let passing = CGRect(x: 6, y: 352, width: 100, height: 100)
knocked.syncWindows([(2, passing), (1, window)])
knocked.ledges[1]!.snow[5] = 9
knocked.syncWindows([(2, passing.offsetBy(dx: 420, dy: 0)), (1, window)])
for _ in 0..<4 { knocked.step(1 / 60) }
precondition(knocked.ledges[1]!.snow[5] == 0 && knocked.flakes.first?.looseSnow == 9)
let cursor = physicsView()
cursor.syncWindows([])
cursor.flakes = [Flake(x: 228, y: 237, vx: 0, vy: -45, radius: 2, phase: 0),
                 Flake(x: 228, y: 255, vx: 0, vy: -45, radius: 2, phase: 0)]
cursor.step(1 / 60, cursor: CGPoint(x: 165, y: 230))
cursor.step(1 / 60, cursor: CGPoint(x: 288, y: 230))
precondition(cursor.flakes[0].push.dx > 200 && abs(cursor.flakes[1].push.dx) < 1)
let hour = SnowView(frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
hour.workshopEnabled = false
hour.heavyPlow.enabled = false
hour.plowEnabled = false
hour.syncWindows([(1, CGRect(x: 300, y: 300, width: 800, height: 400))])
for _ in 0..<3600 { hour.step(1 / 60) }
let ledge = hour.ledges[1]!.snow
let ledgeMean = ledge.reduce(0, +) / CGFloat(ledge.count)
let groundMean = hour.ground.reduce(0, +) / CGFloat(hour.ground.count)
precondition(ledgeMean < 5 && groundMean < 6)
print(String(format: "After 60 s at Normal, snowplow off: window edge avg %.1f pt, ground avg %.1f pt", ledgeMean, groundMean))
let bannerFrame = CGRect(x: 454, y: 378, width: 330, height: 88)
precondition(FrostBanner.fits(bannerFrame, on: screen))
precondition(!FrostBanner.fits(CGRect(x: 454, y: 100, width: 330, height: 380), on: screen))
let controller = BannerFrost()
let fixture = FrostBanner(id: 1, frame: bannerFrame, level: 25, opacity: 0.9)
var created: [Overlay] = []
func makeFrostPanel(_ frame: CGRect) -> Overlay {
    let panel = Winter().makePanel(frame, interactive: false)
    created.append(panel)
    return panel
}
controller.update([fixture], at: 5, makePanel: makeFrostPanel)
precondition(created.count == 1 && created[0].isVisible && created[0].ignoresMouseEvents)
precondition(created[0].level.rawValue == 26)
controller.update([fixture], at: 6, makePanel: makeFrostPanel)
precondition(created.count == 1 && (created[0].contentView as! FrostView).growth > 0.8)
controller.update([], at: 7, makePanel: makeFrostPanel)
precondition(!created[0].isVisible)
print("Checked: pointer tip, momentum, sliding off windows, overflow and frost window")

}
FileHandle.standardError.write(Data("v124-physics.swift\n".utf8))
try scenario4()
func scenario5() throws {
let viewport = CGRect(x: 0, y: 0, width: 420, height: 310)
let window = CGRect(x: 95, y: 80, width: 230, height: 150)
func scene() -> SnowView {
    let view = SnowView(frame: viewport)
view.workshopEnabled = false
view.heavyPlow.enabled = false
    view.density = 0
    view.plowEnabled = false
    view.step(0)
    return view
}
let alignment = scene()
alignment.syncWindows([(1, window)])
alignment.ledges[1]!.snow = alignment.ledges[1]!.snow.map { _ in 7 }
alignment.ground[3] = 4
alignment.plowEnabled = true
alignment.plowX = 220
let bitmap = alignment.bitmapImageRepForCachingDisplay(in: viewport)!
alignment.cacheDisplay(in: viewport, to: bitmap)
let scale = CGFloat(bitmap.pixelsWide) / viewport.width
func alpha(_ x: CGFloat, _ y: CGFloat) -> CGFloat {
    bitmap.colorAt(x: Int(x * scale), y: Int((viewport.height - y) * scale))!.alphaComponent
}
precondition(alpha(window.minX + 12, window.maxY + 3) == 0)
precondition(alpha(window.maxX - 12, window.maxY + 3) == 0)
precondition(alpha(window.minX + 23, window.maxY + 4) > 0.8)
precondition(alpha(28, 0.8) > 0.7 && alpha(231, 1.1) > 0.45)
let image = NSImage(size: viewport.size)
image.addRepresentation(bitmap)
let background = NSImage(size: viewport.size, flipped: false) { rect in
    NSColor(srgbRed: 0.16, green: 0.22, blue: 0.33, alpha: 1).setFill()
    rect.fill()
    NSColor(srgbRed: 0.93, green: 0.95, blue: 0.98, alpha: 1).setFill()
    NSBezierPath(roundedRect: window, xRadius: 16, yRadius: 16).fill()
    image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
    return true
}
let cg = background.cgImage(forProposedRect: nil, context: nil, hints: nil)!
try NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: testOutput + "/v117-pixel-alignment.png"))
func pushGround(shape: CursorShape) -> Int {
    let snow = scene()
    for index in 11...13 { snow.ground[index] = 3 }
    snow.step(0, cursor: CGPoint(x: 69, y: floorY + 3), shape: shape)
    for step in 1...10 { snow.step(1 / 60, cursor: CGPoint(x: 69 + 46 * CGFloat(step) / 10, y: floorY + 3), shape: shape) }
    precondition(snow.ground[11...13].allSatisfy { $0 < 0.001 })
    for _ in 0..<12 { snow.step(1 / 60) }
    precondition(abs(snow.ground.reduce(0, +) - 9) < 0.001 && snow.flakes.isEmpty)
    return snow.ground.firstIndex(where: { $0 > 0.01 })!
}
let narrow = CursorShape(rows: [CGRect(x: -2, y: -2, width: 4, height: 4)])
let wide = CursorShape(rows: [CGRect(x: -2, y: -2, width: 24, height: 4)])
precondition(pushGround(shape: wide) >= pushGround(shape: narrow) + 2)
let ledge = scene()
ledge.syncWindows([(1, window)])
ledge.ledges[1]!.snow[5] = 3
ledge.ledges[1]!.snow[6] = 2
ledge.step(0, cursor: CGPoint(x: 181, y: window.maxY + 2), shape: narrow)
for step in 1...10 { ledge.step(1 / 60, cursor: CGPoint(x: 181 - 38 * CGFloat(step) / 10, y: window.maxY + 2), shape: narrow) }
for _ in 0..<12 { ledge.step(1 / 60) }
precondition(abs(ledge.ledges[1]!.snow.reduce(0, +) - 5) < 0.001)
precondition(ledge.ledges[1]!.snow[..<4].reduce(0, +) > 3 && ledge.flakes.isEmpty)
print("Checked: Retina edges and wheelbase, snow in front of the pointer, reach of the pointer shape and window edge")

}
FileHandle.standardError.write(Data("v124-pixels-and-cursor.swift\n".utf8))
try scenario5()
func scenario6() throws {
let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 900, height: 500))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
snow.plowEnabled = false
snow.density = 0
let original = CGRect(x: 200, y: 100, width: 163, height: 200)
snow.syncWindows([(1, original)])
snow.ledges[1]!.snow[4] = 8
let expanded = CGRect(x: 188, y: 100, width: 175, height: 200)
snow.syncWindows([(1, expanded)])
precondition(snow.ledges[1]!.snow[5] == 4 && snow.ledges[1]!.snow[6] == 4)
precondition(snow.ledges[1]!.slideVelocity == 0 && snow.flakes.isEmpty)
let cropped = CGRect(x: 236, y: 100, width: 127, height: 200)
snow.syncWindows([(1, cropped)])
for _ in 0..<4 { snow.step(1 / 60) }
precondition(snow.ledges[1]!.snow.reduce(0, +) == 4)
precondition(snow.flakes.reduce(0, { $0 + $1.looseSnow }) == 4)
for _ in 0..<60 { snow.step(1 / 60) }
precondition(snow.flakes.isEmpty && abs(snow.ground.reduce(0, +) - 4) < 0.0001)
snow.clearSnow()
let partial = CGRect(x: 200, y: 100, width: 67, height: 200)
snow.syncWindows([(1, partial)])
snow.ledges[1]!.snow[4] = 9
snow.syncWindows([(1, CGRect(x: 200, y: 100, width: 65, height: 200))])
for _ in 0..<4 { snow.step(1 / 60) }
precondition(snow.ledges[1]!.snow[4] == 3 && snow.flakes.first?.looseSnow == 6)
let start = CGRect(x: 150, y: 290, width: 80, height: 90)
let grow = WindowSweep(from: start, to: CGRect(x: 150, y: 290, width: 115, height: 90))!
precondition(grow.impact(at: CGPoint(x: 245, y: 320))?.dx == 35)
precondition(grow.impact(at: CGPoint(x: 245, y: 405)) == nil)
precondition(grow.impact(at: CGPoint(x: 190, y: 320)) == nil)
let shrink = WindowSweep(from: start, to: CGRect(x: 150, y: 290, width: 50, height: 90))!
precondition(shrink.impact(at: CGPoint(x: 240, y: 320)) == nil)
snow.clearSnow()
let lower = CGRect(x: 235, y: 150, width: 200, height: 150)
snow.syncWindows([(2, start), (1, lower)])
snow.ledges[1]!.snow[1] = 9
snow.syncWindows([(2, CGRect(x: 150, y: 290, width: 115, height: 90)), (1, lower)])
for _ in 0..<4 { snow.step(1 / 60) }
precondition(snow.ledges[1]!.snow[1] == 0 && snow.flakes.isEmpty)
precondition(abs(snow.ledges[1]!.snow.reduce(0,+) + snow.surfaceTransfers.reduce(0,{$0+$1.amount}) - 9) < 0.0001)
print("Checked: left and right window edge, partial cells, snow amount and contact while resizing")

}
FileHandle.standardError.write(Data("v124-resize.swift\n".utf8))
try scenario6()
func scenario7() throws {
let pointer = CursorShape(rows: [CGRect(x: -2, y: -2, width: 4, height: 4)])
func scene() -> SnowView {
    let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 800, height: 500))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
    snow.density = 0
    snow.plowEnabled = false
    snow.step(0)
    return snow
}
func brushFloor(on snow: SnowView) {
    for index in 24...26 { snow.ground[index] = 3 }
    snow.step(0, cursor: CGPoint(x: 90, y: floorY + 3), shape: pointer)
    snow.step(1 / 60, cursor: CGPoint(x: 420, y: floorY + 3), shape: pointer)
}
let snow = scene()
brushFloor(on: snow)
let start = snow.surfaceTransfers.first!.position.x
let mass = snow.surfaceTransfers.reduce(0) { $0 + $1.amount }
precondition(abs(mass - 9) < 0.00001 && snow.ground.reduce(0, +) == 0)
snow.step(1 / 60)
let next = snow.surfaceTransfers.first!.position.x
precondition(next > start + 2 && next < start + 28 && next < 420)
for _ in 0..<45 { snow.step(1 / 60) }
precondition(snow.surfaceTransfers.isEmpty && snow.flakes.isEmpty)
precondition(abs(snow.ground.reduce(0, +) - mass) < 0.00001)
precondition(snow.ground[..<30].reduce(0, +) == 0)

let blocked = scene()
brushFloor(on: blocked)
blocked.syncWindows([(2, CGRect(x: 250, y: 0, width: 150, height: 230))])
for _ in 0..<35 { blocked.step(1 / 60) }
precondition(blocked.surfaceTransfers.isEmpty && abs(blocked.ground.reduce(0, +) - 9) < 0.00001)
precondition(blocked.ground[34...50].reduce(0, +) == 0)

let raised = scene()
let frame = CGRect(x: 160, y: 100, width: 420, height: 200)
raised.syncWindows([(1, frame)])
raised.ledges[1]!.snow[12] = 4
raised.step(0, cursor: CGPoint(x: 252, y: 304), shape: pointer)
raised.step(1 / 60, cursor: CGPoint(x: 390, y: 304), shape: pointer)
let prior = raised.surfaceTransfers.first!.position
raised.syncWindows([(1, frame.offsetBy(dx: 12, dy: 3))])
raised.step(1 / 60)
precondition(raised.surfaceTransfers.first!.position.x > prior.x + 12)
precondition(raised.surfaceTransfers.first!.position.y >= 303)
raised.clearSnow()
precondition(raised.surfaceTransfers.isEmpty)
print("Checked: visible travel, conservation of snow amount, obstacle, window movement and reset")

}
FileHandle.standardError.write(Data("v124-transfer.swift\n".utf8))
try scenario7()
func scenario8() throws {
let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 600, height: 280))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
snow.density = 0
snow.plowX = 13
snow.step(0)
snow.ground[10] = 8
snow.step(4 / 76)
precondition((0.5...0.85).contains(snow.plowLoad) && abs(snow.ground.reduce(0,+) + snow.plowLoad - 8) < 0.0001)
let start = snow.plowX
snow.step(1 / 60)
precondition(snow.plowX - start < 76.0 / 60)
precondition(abs(snow.ground.reduce(0,+) + snow.plowLoad + snow.flakes.reduce(0, { $0 + $1.looseSnow }) - 8) < 0.0001)
snow.plowEnabled = false
precondition(snow.plowLoad == 0)
for _ in 0..<60 { snow.step(1 / 60) }
precondition(snow.flakes.isEmpty && abs(snow.ground.reduce(0, +) - 8) < 0.0001)
snow.plowEnabled = true
snow.plowX = 155
for index in 28...42 { snow.ground[index] = 7 }
for _ in 0..<20 { snow.step(1 / 60) }
precondition(snow.plowLoad > 0.5 && snow.plowLoad <= plowLoadLimit)
let preview = snow.bitmapImageRepForCachingDisplay(in: previewBounds(snow.bounds))!
snow.cacheDisplay(in: previewBounds(snow.bounds), to: preview)
try preview.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: testOutput + "/v110-plow-load.png"))
snow.startPlow()
precondition(snow.plowLoad == 0 && snow.plowX == -70)
print("Checked: partial clearing, mass, load brake, unloading and restart")
func previewBounds(_ bounds: CGRect) -> CGRect {
    CGRect(x: 115, y: 0, width: bounds.width - 250, height: 120)
}

}
FileHandle.standardError.write(Data("v123-plow-load.swift\n".utf8))
try scenario8()
func scenario9() throws {
let snow = SnowView(frame: CGRect(x: 0, y: 0, width: 550, height: 230))
snow.workshopEnabled = false
snow.heavyPlow.enabled = false
snow.displayID = UInt32.max - 30
defer { UserDefaults.standard.removeObject(forKey: "snowmen.\(snow.displayID)") }
snow.density = 0
snow.plowX = 110
let man = Snowman(x: 200 / 550, balls: 3, scarf: .ocean)
snow.snowmen = [man]
snow.saveSnowmen()
snow.step(1 / 60)
let fall = snow.fallingSnowmen.first!
precondition(snow.snowmen.isEmpty && snow.flakes.count == 4)
precondition(fall.visibleBalls(at: snow.time) == 3)
snow.restoreSnowmen()
precondition(snow.snowmen.isEmpty && snow.fallingSnowmen.count == 1)
for _ in 0..<11 { snow.step(1 / 60) }
let head = fall.pieceCenter(height: 78, at: fall.progress(at: snow.time), width: 550)
precondition(head.x > 222 && head.y < 78 && fall.visibleBalls(at: snow.time) == 3)
let bitmap = snow.bitmapImageRepForCachingDisplay(in: snow.bounds)!
snow.cacheDisplay(in: snow.bounds, to: bitmap)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: testOutput + "/v120-collapse.png"))
while fall.progress(at: snow.time) < 0.75 { snow.step(1 / 60) }
precondition(fall.visibleBalls(at: snow.time) == 2)
precondition(snow.flakes.contains(where: { $0.looseSnow >= 1.8 && $0.x > 230 && $0.y > 42 }))
while fall.progress(at: snow.time) < 0.93 { snow.step(1 / 60) }
precondition(fall.visibleBalls(at: snow.time) == 1)
while !snow.fallingSnowmen.isEmpty { snow.step(1 / 60) }
precondition(snow.flakes.contains(where: { $0.looseSnow >= 1.8 && $0.y < 35 }))
snow.plowEnabled = false
for _ in 0..<75 { snow.step(1 / 60) }
precondition(snow.flakes.isEmpty && snow.ground.reduce(0, +) > 40)
snow.clearSnow()
snow.snowmen = [man]
snow.plowEnabled = true
snow.plowX = 110
snow.step(1 / 60)
precondition(snow.fallingSnowmen.count == 1)
snow.clearSnow()
for _ in 0..<30 { snow.step(1 / 60) }
precondition(snow.fallingSnowmen.isEmpty && snow.flakes.isEmpty)
print("Checked: hit, tipping, head, belly, base, snow on the ground and cancellation")

}
FileHandle.standardError.write(Data("v123-collapse.swift\n".utf8))
try scenario9()

func testSaturatedDrift() {
    let snow = SnowView(frame: CGRect(x:0,y:0,width:800,height:400))
    snow.density = 0
    snow.workshopEnabled = false
    snow.heavyPlow.enabled = false
    snow.plowEnabled = false
    snow.step(0)
    for i in 20...79 { snow.ground[i] = 13 }
    snow.flakes = [Flake(x:400,y:15,vx:0,vy:-240,radius:4,looseSnow:24)]
    snow.step(1/120)
    precondition(snow.ground[..<18].allSatisfy { $0 == 0 } && snow.ground[82...].allSatisfy { $0 == 0 })
    precondition(snow.ground[48...52].reduce(0,+) > 65, "Excess must remain at the impact")
    let peak = snow.ground.max()!
    for _ in 0..<180 { snow.step(1/120) }
    precondition(snow.ground.max()! < peak - 3)
    precondition(abs(snow.ground.reduce(0,+)-804) < 0.0001)
    print("Full snow layer: local impact, visible sliding, snow amount conserved")
}
func testPlowTrack() {
    let snow = SnowView(frame: CGRect(x:0,y:0,width:900,height:400))
    snow.density = 0
    snow.workshopEnabled = false
    snow.heavyPlow.enabled = false
    snow.step(0)
    for i in 10...90 { snow.ground[i] = 9 }
    snow.plowX = 11
    var maximumResidue: CGFloat = 0
    for i in 0..<720 {
        snow.step(1/120)
        let blade = snow.plowX + bladeTip
        if i > 120 {
            let first = Int(max(88,blade-45)/8)
            let last = Int(max(88,blade-14)/8)
            maximumResidue = max(maximumResidue,snow.ground[first...last].max() ?? 0)
        }
        let mass = snow.ground.reduce(0,+) + snow.plowLoad + snow.plowRemoved + snow.flakes.reduce(0,{$0+$1.looseSnow})
        precondition(abs(mass-729) < 0.0001, "Snowplow loses snow: \(mass)")
    }
    print("Residual snow right behind the snowplow: \(maximumResidue)")
    precondition(maximumResidue > 7 && maximumResidue <= 9)
    precondition(snow.ground.reduce(0,+) >= 729-plowLoadLimit-0.0001)
}
testSaturatedDrift()
testPlowTrack()
func testWindowContact() {
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density = 0
    view.workshopEnabled = false
    view.heavyPlow.enabled = false
    view.plowEnabled = false
    let shelf = CGRect(x:170,y:100,width:400,height:230)
    var moving = CGRect(x:250,y:50,width:200,height:160)
    view.syncWindows([(2,moving),(1,shelf)])
    view.ledges[1]!.snow[19] = 9
    moving.origin.y = 190
    view.syncWindows([(2,moving),(1,shelf)],interval:1/30)
    precondition(view.ledges[1]!.snow[19] == 0)
    precondition(abs(view.ledges[2]!.snow.reduce(0,+)-9) < 0.00001)
    precondition(view.flakes.isEmpty)
    view.clearSnow()
    moving = CGRect(x:400,y:270,width:80,height:100)
    view.syncWindows([(2,moving),(1,shelf)])
    view.ledges[1]!.snow[19] = 9
    moving.origin.x = 250
    view.syncWindows([(2,moving),(1,shelf)],interval:1/30)
    precondition(view.ledges[1]!.snow[19] == 0)
    for _ in 0..<60 { view.step(1/120) }
    precondition(view.flakes.isEmpty)
    precondition(abs(view.ledges[1]!.snow.reduce(0,+)-9) < 0.00001)
    precondition(view.ledges[1]!.snow[0...8].reduce(0,+) > 8.9)
    print("Windows carry snow upwards and push it sideways ahead of them")
}
testWindowContact()
func testHeavyClearing() {
    let blower = HeavyPlow()
    var ground = Array(repeating:CGFloat(15),count:100)
    for _ in 0..<110 { blower.step(1/120,ground:&ground,cell:8,width:800,smallLoad:29) }
    precondition(!blower.active)
    for _ in 0..<320 { blower.step(1/120,ground:&ground,cell:8,width:800,smallLoad:0) }
    precondition(blower.active)
    for _ in 0..<1500 { blower.step(1/120,ground:&ground,cell:8,width:800,smallLoad:0) }
    precondition(!blower.active && ground.reduce(0,+) < 0.00001)
    precondition(abs(blower.removed-1500) < 0.0001)
    let gentle = HeavyPlow()
    var light = Array(repeating:CGFloat(1),count:100)
    for _ in 0..<300 { gentle.step(1/120,ground:&light,cell:8,width:800,smallLoad:4) }
    precondition(!gentle.active && gentle.removed == 0)
    print("Big snow blower takes over on overload, clears completely and stays off when there is little snow")
}
testHeavyClearing()
func testSlowCorner() {
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density = 0
    view.plowEnabled = false
    view.workshopEnabled = false
    view.heavyPlow.enabled = false
    view.step(0)
    let rect = CGRect(x:170,y:100,width:400,height:230)
    view.syncWindows([(1,rect)])
    let end = view.ledges[1]!.snow.count-1
    view.ledges[1]!.snow[end] = 8
    view.step(0,cursor:CGPoint(x:520,y:334))
    for i in 1...80 { view.step(1/120,cursor:CGPoint(x:520+CGFloat(i)*0.5,y:334)) }
    precondition(view.ledges[1]!.snow[end] < 0.1)
    for _ in 0..<160 { view.step(1/120) }
    precondition(abs(view.ground.reduce(0,+)-8) < 0.001)
    precondition(view.runoff.isEmpty && view.surfaceTransfers.isEmpty)
    print("Slow swipe over the rounded corner: no wall, no leftover pile, snow lands below")
}
testSlowCorner()

func testWorkshopIntegration() {
let snow = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
snow.density = 0
snow.plowEnabled = false
snow.step(0)
snow.syncWindows([(1,CGRect(x:100,y:100,width:600,height:200))])
for i in snow.ledges[1]!.snow.indices { snow.ledges[1]!.snow[i] = 6 }
let initial = snow.ledges[1]!.snow.reduce(0,+)
snow.step(0,cursor:CGPoint(x:140,y:305))
for i in 1...300 { snow.step(1/120,cursor:CGPoint(x:140+CGFloat(i)*1.5,y:305)) }
let mass = snow.ledges[1]!.snow.reduce(0,+) + snow.ground.reduce(0,+) + snow.surfaceTransfers.reduce(0,{$0+$1.amount})
    + snow.runoff.reduce(0,{$0+$1.amount}) + snow.flakes.reduce(0,{$0+$1.looseSnow}) + snow.workshop.balls.reduce(0,{$0+$1.mass})
print("Ball formation",snow.workshop.balls.map { ($0.x,$0.radius,$0.mass) },"Mass",mass,initial)
precondition(snow.workshop.balls.count == 1 && abs(mass-initial) < 0.001)
precondition(snow.workshop.balls[0].mass > 200 && snow.workshop.balls[0].x > 620)
precondition(snow.workshop.balls[0].lastPush > 2.48, "Pressure contact must not break off while growing")
for sizes: [CGFloat] in [[18,12,7],[7,18,12],[12,7,18]] {
    let model = SnowWorkshop()
    for (i,r) in sizes.enumerated() {
        model.form(at:CGPoint(x:100+CGFloat(i)*110,y:r+1),mass:r*r*CGFloat.pi/8,surface:nil,
                   frame:CGRect(x:0,y:0.5,width:800,height:1))
    }
    for index in 1...2 {
        let ball = model.balls[index]
        let target = model.balls[index-1]
        model.down(at:CGPoint(x:ball.x,y:ball.y),visible:{_ in true})
        model.up(at:CGPoint(x:ball.x,y:ball.y))
        precondition(model.held == ball.id)
        let point = CGPoint(x:target.x,y:target.y+target.radius+ball.radius-0.5)
        model.moveHeld(to:point)
        model.down(at:point,visible:{_ in true})
        precondition(model.held == nil)
    }
    precondition(model.snowmen.count == 1 && model.snowmen[0].map(\.radius) == sizes)
}
print("Checked: clicking, lifting, free stacking and three different proportions")

}
testWorkshopIntegration()
func testCoveredInputAndStorage() throws {
    let view = SnowView(frame:CGRect(x:0,y:0,width:400,height:300))
    view.density = 0
    view.plowEnabled = false
    view.step(0)
    view.workshop.form(at:CGPoint(x:100,y:20),mass:100,surface:nil,frame:CGRect(x:0,y:0.5,width:400,height:1))
    let controller = Winter()
    let panel = controller.makePanel(view.bounds,interactive:false)
    panel.contentView = view
    controller.overlays = [(panel,view)]
    controller.lastScan = CACurrentMediaTime()+10
    view.syncWindows([(99,view.bounds)])
    precondition(!view.shouldAnimate)
    panel.ignoresMouseEvents = false
    controller.tick()
    precondition(panel.ignoresMouseEvents)
    view.workshop.down(at:CGPoint(x:100,y:20),visible:{_ in true})
    controller.tick()
    precondition(!panel.ignoresMouseEvents)
    view.workshop.release(at:CGPoint(x:120,y:40))
    controller.tick()
    precondition(panel.ignoresMouseEvents)
    let key = "snowday.test.packing." + UUID().uuidString
    defer { UserDefaults.standard.removeObject(forKey:key); panel.close() }
    view.workshop.storageKey = key
    view.workshop.save()
    let restored = SnowWorkshop()
    restored.storageKey = key
    restored.restore()
    precondition(restored.balls.count == 1 && restored.balls[0].mass == 100)
    print("Clicks released after dropping, even with the desktop covered; snowballs restored")
}
try testCoveredInputAndStorage()

func testPackedContactsAndWindows() {
    func ball(_ model:SnowWorkshop,_ x:CGFloat,_ radius:CGFloat,_ y:CGFloat? = nil,_ surface:UInt32? = nil,_ anchor:CGRect? = nil) {
        model.form(at:CGPoint(x:x,y:y ?? radius+0.5),mass:radius*radius*CGFloat.pi/8,surface:surface,
                   frame:anchor ?? CGRect(x:0,y:0.5,width:800,height:1))
    }
    func advance(_ model:SnowWorkshop,_ frame:Int,_ sweep:CursorSweep? = nil,_ ledges:[UInt32:Ledge] = [:]) {
        model.step(1/120,time:CGFloat(frame)/120,sweep:sweep,ledges:ledges,bounds:CGRect(x:0,y:0,width:800,height:500),
                   groundHeight:{ _ in 0.5 },visible:{ _ in true },collect:{ _,_,_,_ in 0 })
    }
    let touching = SnowWorkshop()
    ball(touching,200,12)
    ball(touching,245,22)
    let mass = touching.balls.reduce(0) { $0+$1.mass }
    for frame in 0..<180 {
        let start = CGPoint(x:177+CGFloat(frame)*0.5,y:14)
        advance(touching,frame,CursorSweep(start:start,end:CGPoint(x:start.x+0.5,y:start.y),shape:CursorShape.arrow!,duration:1/120))
        let a = touching.balls[0], b = touching.balls[1]
        precondition(hypot(a.x-b.x,a.y-b.y) >= a.radius+b.radius-0.4,"Snowballs overlap each other")
    }
    precondition(touching.balls[1].x > 265 && touching.balls.reduce(0,{$0+$1.mass}) == mass)
    let vertical = SnowWorkshop()
    ball(vertical,300,16)
    for frame in 0..<50 {
        advance(vertical,frame,CursorSweep(start:CGPoint(x:300,y:80-CGFloat(frame)),
                end:CGPoint(x:300,y:79-CGFloat(frame)),shape:CursorShape.arrow!,duration:1/120))
    }
    precondition(vertical.balls[0].x == 300,"Approaching vertically must not push the snowball sideways")
    let snow = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    snow.density = 0
    snow.plowEnabled = false
    snow.step(0)
    let back = CGRect(x:100,y:100,width:600,height:200)
    let front = CGRect(x:220,y:30,width:250,height:200)
    snow.syncWindows([(1,front),(2,back)])
    ball(snow.workshop,350,15,315,2,CGRect(x:116,y:300,width:568,height:1))
    snow.syncWindows([(1,front.offsetBy(dx:0,dy:110)),(2,back)])
    precondition(snow.workshop.balls[0].surface == 1 && snow.workshop.balls[0].y == 355)
    let liftMass = snow.workshop.balls[0].mass
    snow.syncWindows([(1,front.offsetBy(dx:45,dy:110)),(2,back)])
    snow.step(1/120)
    precondition(snow.workshop.balls[0].x > 390 && snow.workshop.balls[0].mass == liftMass)
    let side = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    side.density = 0
    side.plowEnabled = false
    side.step(0)
    let sideFront = CGRect(x:100,y:200,width:180,height:180)
    side.syncWindows([(1,sideFront),(2,back)])
    ball(side.workshop,330,15,315,2,CGRect(x:116,y:300,width:568,height:1))
    side.syncWindows([(1,sideFront.offsetBy(dx:100,dy:0)),(2,back)])
    precondition(side.workshop.balls[0].x >= 395 && side.workshop.balls[0].surface == 2)
    print("Snowballs push each other aside without losing mass; vertical grab stable; windows lift and push snowballs")
}
testPackedContactsAndWindows()

extension SnowView {
    func injectBudgetDrop() { dropSnow(at:CGPoint(x:400,y:350),amount:100,sideways:0) }
}
func testSnowBudgetFallback() {
    let snow = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    snow.density = 0
    snow.workshopEnabled = false
    snow.heavyPlow.enabled = false
    snow.plowEnabled = false
    snow.step(0)
    for i in snow.ground.indices { snow.ground[i] = 13 }
    snow.flakes = (0..<960).map { _ in Flake(x:400,y:450,vx:0,vy:-20,radius:1,depth:.distant) }
    let expected = snow.ground.reduce(0,+)+100
    snow.injectBudgetDrop()
    precondition(abs(snow.ground.reduce(0,+)-expected) < 0.001)
    precondition(snow.ground[50] == 113)
    print("Even with a full particle budget, the snow amount at the impact point is conserved")
}
testSnowBudgetFallback()

func testGrabbingAtPressureContact() {
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density = 0
    view.plowEnabled = false
    view.step(0)
    view.workshop.form(at:CGPoint(x:200,y:16.5),mass:16*16*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    var pointer = CGPoint(x:164,y:18)
    view.step(0,cursor:pointer)
    for _ in 0..<100 {
        pointer.x += 0.5
        view.step(1/120,cursor:pointer)
    }
    precondition(view.wantsInteraction(at:pointer),"A pushed snowball must be grabbable at the same contact point")
    view.workshop.down(at:pointer,visible:{_ in true})
    precondition(view.workshop.held != nil)
    let rest = SnowWorkshop()
    rest.form(at:CGPoint(x:180,y:18.5),mass:18*18*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    rest.form(at:CGPoint(x:400,y:10.5),mass:10*10*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    rest.down(at:CGPoint(x:400,y:10.5),visible:{_ in true})
    rest.release(at:CGPoint(x:180,y:160))
    for frame in 0..<100 {
        rest.step(1/120,time:CGFloat(frame)/120,sweep:nil,ledges:[:],bounds:view.bounds,
                  groundHeight:{_ in 0.5},visible:{_ in true},collect:{_,_,_,_ in 0})
    }
    precondition(rest.balls[1].parent == rest.balls[0].id && !rest.balls[1].falling)
    let support = SnowWorkshop()
    support.form(at:CGPoint(x:180,y:16.5),mass:16*16*CGFloat.pi/8,surface:1,frame:CGRect(x:116,y:300,width:568,height:1))
    let snowy = Ledge(frame:CGRect(x:116,y:100,width:568,height:200),windowFrame:CGRect(x:100,y:100,width:600,height:200),
                     snow:Array(repeating:6,count:71),exposed:Array(repeating:true,count:71),lip:300)
    support.step(1/120,time:1,sweep:nil,ledges:[1:snowy],bounds:view.bounds,groundHeight:{_ in 0.5},
                 visible:{_ in true},collect:{_,_,_,_ in 0})
    precondition(abs(support.balls[0].y-322) < 0.001)
    print("Snowball grabbable at the pressure point; falling onto another snowball stacks; support follows snow height")
}
testGrabbingAtPressureContact()

func testDesktopSuspension() {
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density = 0; view.plowEnabled = false
    view.step(0)
    let frame = CGRect(x:100,y:100,width:600,height:200)
    view.syncWindows([(1,frame)],existingWindows:[1])
    for i in view.ledges[1]!.snow.indices { view.ledges[1]!.snow[i] = 4 }
    view.workshop.form(at:CGPoint(x:300,y:320),mass:100,surface:1,frame:CGRect(x:116,y:300,width:568,height:1))
    view.step(1/120)
    let ball = view.workshop.balls[0]
    let heights = view.ledges[1]!.snow
    view.syncWindows([],existingWindows:[1])
    precondition(view.ledges[1] == nil && view.workshop.isSuspended(view.workshop.balls[0]))
    for _ in 0..<600 { view.step(1/120,cursor:CGPoint(x:300,y:320)) }
    precondition(view.workshop.balls[0].x == ball.x && view.workshop.balls[0].y == ball.y)
    precondition(!view.wantsInteraction(at:CGPoint(x:300,y:320)))
    view.syncWindows([(1,frame)],existingWindows:[1])
    view.step(1/120)
    precondition(view.ledges[1]!.snow == heights)
    precondition(view.workshop.balls[0].mass == ball.mass && view.workshop.balls[0].surface == 1)
    precondition(abs(view.workshop.balls[0].y-ball.y)<0.001)
    precondition(!view.workshop.isSuspended(view.workshop.balls[0]))
    print("Show desktop: window snow and snowball stay frozen and return unchanged")
}
testDesktopSuspension()

func testBacklogAndPlowExclusion() {
    for values in [Array(repeating:CGFloat(2),count:100),[CGFloat(35)]+Array(repeating:CGFloat(0),count:99)] {
        let blower = HeavyPlow()
        var ground = values
        for _ in 0..<1200 { blower.step(1/120,ground:&ground,cell:8,width:800,smallLoad:29) }
        precondition(!blower.active,"A full blade or a single tall crumb is not a snow jam")
    }
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density = 0; view.workshopEnabled = false
    view.step(0)
    for i in view.ground.indices { view.ground[i] = 15 }
    var stopped:CGFloat?
    var resumed = false
    for _ in 0..<2400 {
        view.step(1/120)
        if view.heavyPlow.active {
            if let stopped { precondition(view.plowX == stopped,"Small snowplow moves while the snow blower is running") }
            else { stopped = view.plowX }
        } else if stopped != nil {
            precondition(view.plowX < 0)
            resumed = true
            break
        }
    }
    precondition(stopped != nil && resumed)
    print("Snow blower only on a sustained ground jam; small snowplow waits meanwhile and then restarts from the left")
}
testBacklogAndPlowExclusion()

func testGenerousGrabAndFixedStackSize() {
    let model = SnowWorkshop()
    model.grabMargin = 22
    for (x,r):(CGFloat,CGFloat) in [(200,18),(350,12),(500,8)] {
        model.form(at:CGPoint(x:x,y:r+0.5),mass:r*r*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    }
    let edge = CGPoint(x:200-18-21,y:18.5)
    precondition(model.hit(at:edge,shape:nil,visible:{_ in true}) == model.balls[0].id)
    precondition(model.hit(at:CGPoint(x:edge.x-3,y:edge.y),shape:nil,visible:{_ in true}) == nil)
    precondition(model.hit(at:edge,shape:nil,visible:{_ in false}) == nil)
    for i in 1...2 {
        let ball = model.balls[i], target = model.balls[i-1]
        model.down(at:CGPoint(x:ball.x,y:ball.y),visible:{_ in true})
        model.release(at:CGPoint(x:target.x,y:target.y+target.radius+ball.radius-1))
    }
    let masses = model.balls.map(\.mass)
    var collected = 0
    for frame in 0..<180 {
        let x = CGFloat(176)+CGFloat(frame)*0.5
        let sweep = CursorSweep(start:CGPoint(x:x,y:20),end:CGPoint(x:x+0.5,y:20),shape:CursorShape.arrow!,duration:1/120)
        model.step(1/120,time:CGFloat(frame)/120,sweep:sweep,ledges:[:],bounds:CGRect(x:0,y:0,width:800,height:500),
                   groundHeight:{_ in 0.5},visible:{_ in true},collect:{_,_,_,_ in collected += 1; return 1 })
    }
    precondition(model.snowmen.count == 1 && model.balls.map(\.mass) == masses && collected == 0)
    print("Large grab zone guards against desktop clicks; complete snowmen do not grow when pushed")
}
testGenerousGrabAndFixedStackSize()

func testHiddenBallsCannotCatchNewOnes() {
    let model = SnowWorkshop()
    let surface = CGRect(x:100,y:300,width:600,height:1)
    model.form(at:CGPoint(x:200,y:315),mass:15*15*CGFloat.pi/8,surface:1,frame:surface)
    model.suspendSurfaces([1])
    precondition(model.canForm(at:CGPoint(x:200,y:315)))
    model.form(at:CGPoint(x:450,y:8.5),mass:8*8*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    model.down(at:CGPoint(x:450,y:8.5),visible:{_ in true})
    model.release(at:CGPoint(x:200,y:350))
    precondition(model.balls[1].parent == nil)
    for i in 0..<180 {
        model.step(1/120,time:CGFloat(i)/120,sweep:nil,ledges:[:],bounds:CGRect(x:0,y:0,width:800,height:500),
                   groundHeight:{_ in 0.5},visible:{_ in true},collect:{_,_,_,_ in 0})
    }
    precondition(model.balls.count == 1 && model.balls[0].y == 315)
    precondition(model.impacts.count == 1 && abs(model.impacts[0].mass-8*8*CGFloat.pi/8) < 0.001)
    print("Stored invisible snowballs block neither forming nor falling nor stacking")
}
testHiddenBallsCannotCatchNewOnes()

extension Winter {
    var checkedCursorRows: [CGRect]? { cursorShape?.rows }
}
func testGrabHandDoesNotChangePressure() {
    let controller = Winter()
    let panel = controller.makePanel(CGRect(x:0,y:0,width:800,height:500),interactive:false)
    defer { panel.close() }
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.workshop.grabMargin = 22
    view.workshop.form(at:CGPoint(x:200,y:16.5),mass:16*16*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    panel.contentView = view
    controller.overlays = [(panel,view)]
    controller.sampleCursor(at:CGPoint(x:500,y:200),system:.arrow)
    let original = controller.checkedCursorRows
    precondition(view.wantsInteraction(at:CGPoint(x:163,y:16.5)))
    controller.sampleCursor(at:CGPoint(x:163,y:16.5),system:.openHand)
    precondition(controller.checkedCursorRows == original)
    controller.sampleCursor(at:CGPoint(x:500,y:200),system:.iBeam)
    precondition(controller.checkedCursorRows == CursorShape(NSCursor.iBeam)?.rows)
    print("Grab hand and 5 mm click zone do not change the pressure outline; real app pointers are still recognized")
}
testGrabHandDoesNotChangePressure()

func testPartiallyHiddenWindowAndRestoredPressure() {
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density = 0; view.plowEnabled = false
    view.step(0)
    let frame = CGRect(x:100,y:100,width:600,height:200)
    view.syncWindows([(1,frame)],existingWindows:[1])
    for i in view.ledges[1]!.snow.indices { view.ledges[1]!.snow[i] = 2 }
    let before = view.ledges[1]!.snow
    view.syncWindows([(1,frame.offsetBy(dx:0,dy:-260))],existingWindows:[1])
    precondition(view.ledges[1] == nil)
    view.step(1/60)
    view.syncWindows([(1,frame)],existingWindows:[1])
    view.step(1/60)
    precondition(view.ledges[1]!.snow == before && view.flakes.isEmpty)
    let key = "snowday.test.restore-pressure."+UUID().uuidString
    defer { UserDefaults.standard.removeObject(forKey:key) }
    let model = SnowWorkshop()
    model.storageKey = key
    model.form(at:CGPoint(x:200,y:16.5),mass:16*16*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    let sweep = CursorSweep(start:CGPoint(x:180,y:18),end:CGPoint(x:181,y:18),shape:CursorShape.arrow!,duration:1/120)
    model.step(1/120,time:2000,sweep:sweep,ledges:[:],bounds:view.bounds,groundHeight:{_ in 0.5},visible:{_ in true},collect:{_,_,_,_ in 0})
    precondition(model.balls[0].lastPush == 2000 && model.balls[0].vx > 0)
    model.save()
    let restored = SnowWorkshop()
    restored.storageKey = key
    restored.restore()
    precondition(restored.balls[0].lastPush < 0 && restored.balls[0].vx == 0)
    precondition(restored.balls[0].mass == model.balls[0].mass && restored.balls[0].x == model.balls[0].x)
    print("A narrow remaining window strip keeps its snow; restoring does not carry over stale cursor momentum")
}
testPartiallyHiddenWindowAndRestoredPressure()

func testPackedBallRoundCorners() {
    for direction:CGFloat in [-1,1] {
        let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
        view.density = 0; view.plowEnabled = false
        view.step(0)
        let window = CGRect(x:100,y:100,width:600,height:200)
        view.syncWindows([(1,window)],existingWindows:[1])
        let x:CGFloat = direction > 0 ? 674 : 126
        let radius:CGFloat = 12
        view.workshop.form(at:CGPoint(x:x,y:300+radius),mass:radius*radius*CGFloat.pi/8,surface:1,
                           frame:CGRect(x:116,y:300,width:568,height:1))
        var p = CGPoint(x:x-direction*22,y:314)
        view.step(0,cursor:p)
        var rounded = 0
        for frame in 0..<300 {
            if frame < 100 { p.x += direction*0.3 }
            view.step(1/120,cursor:frame < 100 ? p : nil)
            guard let ball = view.workshop.balls.first else { continue }
            if ball.edgeSurface != nil {
                rounded += 1
                let cornerX:CGFloat = direction > 0 ? 684 : 116
                precondition(hypot(ball.x-cornerX,ball.y-284) >= 28-0.001)
            }
            let disk = CGRect(x:ball.x-radius,y:ball.y-radius,width:radius*2,height:radius*2)
            precondition(!window.contains(disk),"Snowball disappears into the window while rolling slowly")
        }
        precondition(rounded > 3 && view.workshop.balls.isEmpty)
        let landed = view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
        precondition(abs(landed-radius*radius*CGFloat.pi/8) < 0.001)
    }
    print("Snowballs roll left and right over the rounded corner, fall outside the window and keep their mass")
}
testPackedBallRoundCorners()

func testGroundImpactBreakup() {
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density = 0; view.plowEnabled = false
    view.step(0)
    view.workshop.form(at:CGPoint(x:300,y:20.5),mass:20*20*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    let mass = view.workshop.balls[0].mass
    view.workshop.down(at:CGPoint(x:300,y:20.5),visible:{_ in true})
    view.workshop.release(at:CGPoint(x:300,y:260))
    var sawFragments = false
    for _ in 0..<420 {
        view.step(1/120)
        if view.workshop.balls.isEmpty && view.flakes.contains(where:{$0.looseSnow>0}) { sawFragments = true }
        let current = view.workshop.balls.reduce(0,{$0+$1.mass})+view.flakes.reduce(0,{$0+$1.looseSnow})+view.ground.reduce(0,+)
        precondition(abs(current-mass) < 0.001,"Impact must conserve the snow amount")
    }
    precondition(sawFragments && view.workshop.balls.isEmpty && abs(view.ground.reduce(0,+)-mass)<0.001)
    let gentle = SnowWorkshop()
    gentle.form(at:CGPoint(x:200,y:12.5),mass:12*12*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    gentle.down(at:CGPoint(x:200,y:12.5),visible:{_ in true})
    gentle.release(at:CGPoint(x:200,y:25))
    for frame in 0..<100 {
        gentle.step(1/120,time:CGFloat(frame)/120,sweep:nil,ledges:[:],bounds:view.bounds,groundHeight:{_ in 0.5},
                    visible:{_ in true},collect:{_,_,_,_ in 0})
    }
    precondition(gentle.balls.count == 1 && !gentle.balls[0].falling && gentle.impacts.isEmpty)
    print("Hard ground impact breaks snowballs into snow; gentle drop stays intact; mass conserved at every step")
}
testGroundImpactBreakup()

func testThrowMomentumAndStackImpact() {
    let model = SnowWorkshop()
    let bounds = CGRect(x:0,y:0,width:800,height:500)
    model.form(at:CGPoint(x:200,y:16.5),mass:16*16*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    model.down(at:CGPoint(x:200,y:16.5),time:1,visible:{_ in true})
    model.moveHeld(to:CGPoint(x:200,y:260),time:1.2)
    model.drag(at:CGPoint(x:215,y:240),time:1.2+1/60)
    model.drag(at:CGPoint(x:230,y:220),time:1.2+2/60)
    model.up(at:CGPoint(x:230,y:220),time:1.2+2/60+1/240)
    precondition(model.held == nil && model.balls[0].vx > 250 && model.balls[0].vy < -300)
    let mass = model.balls[0].mass
    for frame in 0..<240 {
        model.step(1/120,time:CGFloat(frame)/120,sweep:nil,ledges:[:],bounds:bounds,
                   groundHeight:{_ in 0.5},visible:{_ in true},collect:{_,_,_,_ in 0})
    }
    precondition(model.balls.isEmpty && model.impacts.count == 1 && model.impacts[0].mass == mass)
    let stack = SnowWorkshop()
    for (x,r):(CGFloat,CGFloat) in [(200,18),(350,12),(500,8)] {
        stack.form(at:CGPoint(x:x,y:r+0.5),mass:r*r*CGFloat.pi/8,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
    }
    for i in 1...2 {
        let a = stack.balls[i], b = stack.balls[i-1]
        stack.down(at:CGPoint(x:a.x,y:a.y),visible:{_ in true})
        stack.release(at:CGPoint(x:b.x,y:b.y+b.radius+a.radius-1))
    }
    let total = stack.balls.reduce(0,{$0+$1.mass})
    let base = stack.balls[0]
    stack.down(at:CGPoint(x:base.x,y:base.y),visible:{_ in true})
    stack.release(at:CGPoint(x:200,y:280))
    for frame in 0..<360 {
        stack.step(1/120,time:CGFloat(frame)/120,sweep:nil,ledges:[:],bounds:bounds,
                   groundHeight:{_ in 0.5},visible:{_ in true},collect:{_,_,_,_ in 0})
        precondition(stack.balls.allSatisfy { ball in ball.parent == nil || stack.balls.contains {$0.id==ball.parent} })
    }
    precondition(stack.balls.isEmpty && stack.impacts.count == 3)
    precondition(abs(stack.impacts.reduce(0,{$0+$1.mass})-total)<0.001)
    print("Throw takes over the hand motion; a hard landing on a stack breaks apart piece by piece with no floating snowballs")
}
testThrowMomentumAndStackImpact()

func testCornerStackSuspension() {
    let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density = 0; view.plowEnabled = false
    view.step(0)
    let frame = CGRect(x:100,y:100,width:600,height:200)
    let anchor = CGRect(x:116,y:300,width:568,height:1)
    view.syncWindows([(1,frame)],existingWindows:[1])
    for (x,r):(CGFloat,CGFloat) in [(674,12),(400,8),(250,6)] {
        view.workshop.form(at:CGPoint(x:x,y:300+r),mass:r*r*CGFloat.pi/8,surface:1,frame:anchor)
    }
    for i in 1...2 {
        let a = view.workshop.balls[i], b = view.workshop.balls[i-1]
        view.workshop.down(at:CGPoint(x:a.x,y:a.y),visible:{_ in true})
        view.workshop.release(at:CGPoint(x:b.x,y:b.y+b.radius+a.radius-1))
    }
    var cursor = CGPoint(x:652,y:314)
    view.step(0,cursor:cursor)
    for _ in 0..<100 {
        cursor.x += 0.3
        view.step(1/120,cursor:cursor)
        if view.workshop.balls[0].edgeSurface != nil { break }
    }
    precondition(view.workshop.balls[0].edgeSurface == 1)
    let positions = view.workshop.balls.map { CGPoint(x:$0.x,y:$0.y) }
    let masses = view.workshop.balls.map(\.mass)
    view.syncWindows([],existingWindows:[1])
    for _ in 0..<60 { view.step(1/120) }
    precondition(view.workshop.balls.allSatisfy(view.workshop.isSuspended))
    precondition(view.workshop.balls.map { CGPoint(x:$0.x,y:$0.y) } == positions)
    view.syncWindows([(1,frame)],existingWindows:[1])
    view.step(1/120)
    precondition(view.workshop.balls.allSatisfy { !view.workshop.isSuspended($0) })
    precondition(view.workshop.balls.map(\.mass) == masses && view.workshop.snowmen.count == 1)
    print("Even a snowman rolling over the corner right now is fully saved when hidden")
}
testCornerStackSuspension()

func testSingleTravelAtCornerAndSteadyThrow() {
    let model = SnowWorkshop()
    let bounds = CGRect(x:0,y:0,width:800,height:500)
    let ledge = Ledge(frame:CGRect(x:116,y:100,width:568,height:200),windowFrame:CGRect(x:100,y:100,width:600,height:200),
                      snow:Array(repeating:0,count:71),exposed:Array(repeating:true,count:71),lip:300)
    model.form(at:CGPoint(x:683.9,y:312),mass:12*12*CGFloat.pi/8,surface:1,frame:CGRect(x:116,y:300,width:568,height:1))
    let shape = CursorShape(rows:[CGRect(x:-1,y:-1,width:2,height:2)])
    let start = CGPoint(x:683.9-shape.bounds.maxX-1-12,y:312)
    model.step(1/120,time:1/120,sweep:CursorSweep(start:start,end:CGPoint(x:start.x+0.3,y:start.y),shape:shape,duration:1/120),
               ledges:[1:ledge],bounds:bounds,groundHeight:{_ in 0.5},visible:{_ in true},collect:{_,_,_,_ in 0})
    let edge = model.balls[0]
    precondition(edge.edgeSurface == 1 && edge.x-683.9 < 0.302,"A physics step must not travel twice as far at the corner")
    var impulses:[CGVector] = []
    for rate:CGFloat in [30,60,120] {
        let model = SnowWorkshop()
        model.form(at:CGPoint(x:200,y:16.5),mass:100,surface:nil,frame:CGRect(x:0,y:0.5,width:800,height:1))
        model.down(at:CGPoint(x:200,y:16.5),time:0,visible:{_ in true})
        model.moveHeld(to:CGPoint(x:200,y:260),time:0.2)
        for frame in 1...Int(rate/5) {
            let t = CGFloat(frame)/rate
            model.moveHeld(to:CGPoint(x:200+600*t,y:260-200*t),time:0.2+t)
        }
        model.release(at:CGPoint(x:320,y:220),time:0.4)
        impulses.append(CGVector(dx:model.balls[0].vx,dy:model.balls[0].vy))
    }
    precondition((impulses.map(\.dx).max()!-impulses.map(\.dx).min()!) < 0.001)
    precondition((impulses.map(\.dy).max()!-impulses.map(\.dy).min()!) < 0.001)
    print("No jump in motion when switching to falling; throw momentum equal at 30/60/120 samples")
}
testSingleTravelAtCornerAndSteadyThrow()

func testSmallPlowOnlyNibblesAndNeverBuildsSpikes() {
    for rate:CGFloat in [30,60,120] {
        let view = SnowView(frame:CGRect(x:0,y:0,width:800,height:400))
        view.density = 0; view.workshopEnabled = false; view.heavyPlow.enabled = false
        view.step(0)
        for i in view.ground.indices { view.ground[i] = 14 }
        var completed = false
        for _ in 0..<Int(rate*40) {
            view.step(1/rate)
            let total = view.ground.reduce(0,+)+view.plowLoad+view.plowRemoved
            precondition(abs(total-1400)<0.0001)
            precondition(view.plowLoad <= 12 && view.ground.max()! <= 14.0001)
            precondition(view.flakes.isEmpty,"No new snow spike from re-collected discharge")
            if view.plowRemoved > 0 {
                precondition(abs(view.plowRemoved-12)<0.0001 && view.ground.reduce(0,+)>1387.99)
                completed = true
                break
            }
        }
        precondition(completed)
    }
    let loaded = SnowView(frame:CGRect(x:0,y:0,width:800,height:400))
    loaded.density = 0; loaded.workshopEnabled = false; loaded.heavyPlow.enabled = false
    loaded.step(0); loaded.plowX = 100
    loaded.flakes = [Flake(x:168,y:8,vx:0,vy:-180,radius:3,looseSnow:100)]
    for _ in 0..<360 {
        loaded.step(1/120)
        precondition(loaded.plowLoad <= 12)
        let total=loaded.ground.reduce(0,+)+loaded.plowLoad+loaded.plowRemoved+loaded.flakes.reduce(0,{$0+$1.looseSnow})
        precondition(abs(total-100)<0.0001,"Even snow that falls onto the full blade must not disappear")
    }
    precondition(loaded.flakes.isEmpty && loaded.ground.reduce(0,+)>=88)
    print("Small snowplow takes at most 12 per run, leaves the rest and builds no spikes at 30/60/120 Hz")
}
testSmallPlowOnlyNibblesAndNeverBuildsSpikes()

func testOneHeavyPassAfterActualAccumulation() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:800,height:400))
    view.density=0;view.workshopEnabled=false
    view.step(0)
    for i in view.ground.indices { view.ground[i]=2 }
    for _ in 0..<1800 { view.step(1/120) }
    precondition(!view.heavyPlow.active && view.heavyPlow.removed==0)
    let initial=view.ground.reduce(0,+)+view.plowLoad+view.plowRemoved
    for i in view.ground.indices { view.ground[i]+=14 }
    let total=initial+1400
    var heavyPasses=0, wasActive=false
    var stopped:CGFloat?
    for _ in 0..<9600 {
        view.step(1/120)
        if view.heavyPlow.active {
            if !wasActive { heavyPasses+=1;stopped=view.plowX }
            precondition(view.plowX==stopped)
        }
        wasActive=view.heavyPlow.active
        let mass=view.ground.reduce(0,+)+view.plowLoad+view.plowRemoved+view.heavyPlow.removed
        precondition(abs(mass-total)<0.0001,"Handover to the big snow blower loses or duplicates snow")
    }
    precondition(heavyPasses==1 && view.heavyPlow.removed>total*0.9)
    precondition(view.ground.max()!<2.1)
    print("After real snow buildup the snow blower clears thoroughly exactly once; the small run pauses and mass stays balanced")
}
testOneHeavyPassAfterActualAccumulation()

func addFightSnowman(_ view:SnowView,x:CGFloat,sizes:[CGFloat],offset:CGFloat=0,surface:UInt32?=nil,lip:CGFloat=0.5) {
    let anchor=CGRect(x:surface == nil ? 0 : 116,y:lip,width:surface == nil ? view.bounds.width : 568,height:1)
    var ids:[UUID]=[]
    for (index,r) in sizes.enumerated() {
        view.workshop.form(at:CGPoint(x:x+CGFloat(index)*75,y:lip+r),mass:r*r*CGFloat.pi/8,surface:surface,frame:anchor)
        ids.append(view.workshop.balls.last!.id)
    }
    for index in 1...2 {
        let ball=view.workshop.balls.first{$0.id==ids[index]}!,parent=view.workshop.balls.first{$0.id==ids[index-1]}!
        view.workshop.down(at:CGPoint(x:ball.x,y:ball.y),visible:{_ in true})
        view.workshop.release(at:CGPoint(x:parent.x+offset,y:parent.y+parent.radius+ball.radius-1))
    }
}
func testSnowmanPersonalityAndPlacement() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:1200,height:500))
    view.density=0;view.plowEnabled=false;view.step(0)
    addFightSnowman(view,x:170,sizes:[23,16,11],offset:3)
    let stack=view.workshop.snowmen[0]
    precondition(stack.allSatisfy { abs($0.x-stack[0].x)<0.001 },"Each snowball must sit exactly centered on the snowball below")
    let look=SnowmanLook(stack)
    let key="snowday.test.personality";view.workshop.storageKey=key;defer{UserDefaults.standard.removeObject(forKey:key)}
    view.workshop.crown(stack[0].id);view.workshop.save()
    let restored=SnowWorkshop();restored.storageKey=key;restored.restore()
    let saved=restored.snowmen[0],same=SnowmanLook(saved)
    precondition(saved[0].crowned==true && saved.allSatisfy { abs($0.x-saved[0].x)<0.001 })
    precondition(same.palette==look.palette && same.hat==look.hat && same.carrotLength==look.carrotLength)
    var legacy=saved
    legacy[1].x += 7; legacy[2].x -= 5
    UserDefaults.standard.set(try! JSONEncoder().encode(legacy),forKey:key)
    let upgraded=SnowWorkshop();upgraded.storageKey=key;upgraded.restore()
    precondition(upgraded.snowmen[0].allSatisfy { abs($0.x-upgraded.snowmen[0][0].x)<0.001 },
                 "Previously saved stacks must also be centered immediately")
    var hats=Set<Int>(),colors=Set<Int>(),widths=Set<CGFloat>()
    for i in 0..<60 {
        var sample=stack
        sample[0]=PackedSnowball(id:UUID(uuidString:String(format:"00000000-0000-0000-0000-%012d",i))!,x:0,y:0,mass:stack[0].mass)
        let variant=SnowmanLook(sample);hats.insert(variant.hat);colors.insert(variant.palette);widths.insert(variant.branchWidth)
    }
    precondition(hats.count==6 && colors.count==7 && widths.count>=4)
    print("Six hat shapes, seven colors, varied twigs and carrots; snowballs are centered, personality and crown stay saved")
}
testSnowmanPersonalityAndPlacement()

func testSnowballFightRoundAndConservation() {
    for rate:CGFloat in [30,120] {
        let view=SnowView(frame:CGRect(x:0,y:0,width:1000,height:500))
        view.density=0;view.step(0)
        for (x,sizes):(CGFloat,[CGFloat]) in [(160,[22,15,10]),(470,[12,20,15]),(790,[18,12,21])] {
            addFightSnowman(view,x:x,sizes:sizes)
        }
        let initial=view.workshop.balls.reduce(0,{$0+$1.mass})
        precondition(view.fightEligibleCount==3 && view.startSnowballFight())
        let stopped=view.plowX
        var sawFlight=false,sawDamage=false,won=false
        for _ in 0..<Int(rate*70) {
            view.step(1/rate)
            sawFlight = sawFlight || !view.fight.shots.isEmpty
            sawDamage = sawDamage || !view.flakes.isEmpty
            let mass=view.workshop.balls.reduce(0,{$0+$1.mass})+view.fight.shots.reduce(0,{$0+$1.mass})
                + view.flakes.reduce(0,{$0+$1.looseSnow})+view.ground.reduce(0,+)
            precondition(abs(mass-initial)<0.001,"Snowball fight loses snow: \(mass), expected \(initial)")
            precondition(view.plowX==stopped && !view.heavyPlow.active)
            if let winner=view.fight.winner {
                precondition(!view.fight.fighting && view.workshop.snowmen.count==1)
                precondition(view.workshop.snowmen[0][0].id==winner && view.workshop.snowmen[0][0].crowned==true)
                precondition(view.fight.shots.isEmpty && view.fight.pose(for:winner).celebrating>0)
                won=true;break
            }
        }
        precondition(sawFlight && sawDamage && won,"Every round must run until there is one crowned survivor")
    }
    print("Snowball fight at 30/120 Hz: throws, hits, crumbling, one winner with a crown; snow amount conserved and snowplows paused")
}
testSnowballFightRoundAndConservation()

func testFightHiddenPauseAndCancellation() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:1000,height:500))
    view.density=0;view.plowEnabled=false;view.step(0)
    let frame=CGRect(x:100,y:100,width:600,height:200)
    view.syncWindows([(1,frame)],existingWindows:[1])
    addFightSnowman(view,x:160,sizes:[20,14,10],surface:1,lip:300)
    precondition(!view.startSnowballFight())
    addFightSnowman(view,x:470,sizes:[18,13,9],surface:1,lip:300)
    precondition(view.startSnowballFight())
    for _ in 0..<200 { view.step(1/120) }
    let stamp=view.fight.clock,masses=view.workshop.balls.map(\.mass),shots=view.fight.shots.map(\.age)
    view.syncWindows([],existingWindows:[1])
    for _ in 0..<120 { view.step(1/120) }
    precondition(view.fight.clock==stamp && view.workshop.balls.map(\.mass)==masses && view.fight.shots.map(\.age)==shots)
    view.syncWindows([(1,frame)],existingWindows:[1])
    view.step(1/120);precondition(view.fight.clock>stamp)
    let initial=view.workshop.balls.reduce(0,{$0+$1.mass})+view.fight.shots.reduce(0,{$0+$1.mass})
        + view.flakes.reduce(0,{$0+$1.looseSnow})+view.ground.reduce(0,+)
    view.stopSnowballFight()
    precondition(!view.fight.isRunning && view.fight.shots.isEmpty && view.fight.winner==nil)
    let after=view.workshop.balls.reduce(0,{$0+$1.mass})+view.flakes.reduce(0,{$0+$1.looseSnow})+view.ground.reduce(0,+)
    precondition(abs(initial-after)<0.001)
    print("A single figure does not start a fight; hidden figures pause the round; ending it returns thrown snow")
}
testFightHiddenPauseAndCancellation()

func testBattleNeverPaintsOverWorkingWindow() throws {
    let view=SnowView(frame:CGRect(x:0,y:0,width:1000,height:500))
    view.density=0;view.plowEnabled=false;view.step(0)
    addFightSnowman(view,x:170,sizes:[22,16,11])
    addFightSnowman(view,x:800,sizes:[21,15,10])
    let window=CGRect(x:360,y:35,width:300,height:250)
    view.syncWindows([(20,window)],existingWindows:[20])
    precondition(view.startSnowballFight())
    var checked=false
    for _ in 0..<1200 {
        view.step(1/120)
        if let shot=view.fight.shots.first(where:{window.insetBy(dx:8,dy:8).contains($0.point(at:$0.age))}) {
            let point=shot.point(at:shot.age)
            let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
            view.cacheDisplay(in:view.bounds,to:rep)
            let scale=CGFloat(rep.pixelsWide)/view.bounds.width
            let alpha=rep.colorAt(x:Int(point.x*scale),y:rep.pixelsHigh-1-Int(point.y*scale))!.alphaComponent
            precondition(alpha<0.01,"Thrown snowballs must not paint over working windows")
            checked=true;break
        }
    }
    precondition(checked)
    view.clearSnowmen()
    precondition(!view.fight.isRunning && view.fight.shots.isEmpty && view.workshop.balls.isEmpty)
    print("Thrown balls stay behind working windows; removing the figures also ends a running round")
}
try testBattleNeverPaintsOverWorkingWindow()

func testChristmasVisitorsAndWindowMask() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:520))
    view.density=0;view.plowEnabled=false;view.christmas=true
    let window=CGRect(x:120,y:65,width:660,height:400)
    view.syncWindows([(45,window)],existingWindows:[45])
    view.step(0);view.inviteChristmasMoment()
    var sawSanta=false,sawReindeer=false,checkedMask=false
    for _ in 0..<2400 {
        view.step(1/120)
        sawSanta = sawSanta || view.christmasScene.hasSanta
        sawReindeer = sawReindeer || view.christmasScene.hasReindeer
        if let point=view.christmasScene.santaPosition(in:view.bounds), window.insetBy(dx:12,dy:12).contains(point) {
            let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
            view.cacheDisplay(in:view.bounds,to:rep)
            let scale=CGFloat(rep.pixelsWide)/view.bounds.width
            let sample=rep.colorAt(x:Int(point.x*scale),y:rep.pixelsHigh-1-Int(point.y*scale))!
            precondition(sample.alphaComponent<0.01,"The sleigh must not paint over any working window")
            checkedMask=true
        }
        if sawSanta && sawReindeer && checkedMask { break }
    }
    precondition(sawSanta && sawReindeer && checkedMask)
    let mass=view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
    precondition(mass==0,"Christmas visitors must not invent snow mass")
    view.christmas=false
    precondition(!view.christmasScene.hasSanta && !view.christmasScene.hasReindeer)
    print("Christmas visit: sleigh and reindeer appear, windows stay clear, visitors create no snow and can be switched off cleanly")
}
testChristmasVisitorsAndWindowMask()

func renderChristmasPreview() throws {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:460))
    view.density=0;view.plowEnabled=false;view.christmas=true
    let window=CGRect(x:250,y:65,width:400,height:225)
    view.syncWindows([(81,window)],existingWindows:[81])
    view.step(0);view.inviteChristmasMoment()
    for _ in 0..<900 {
        view.step(1/120)
        if let santa=view.christmasScene.santaPosition(in:view.bounds), santa.x > 130,
           view.christmasScene.hasReindeer { break }
    }
    let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
    view.cacheDisplay(in:view.bounds,to:rep)
    let png=rep.representation(using:.png,properties:[:])!
    try png.write(to:URL(fileURLWithPath:testOutput+"/christmas-scene.png"))
    if let output=ProcessInfo.processInfo.environment["SNOW_RENDER_OUTPUT"] {
        try png.write(to:URL(fileURLWithPath:output))
    }
}
try renderChristmasPreview()

func testChristmasGiftAndEmoji() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    let window=CGRect(x:200,y:40,width:460,height:160)
    view.syncWindows([(7,window)],existingWindows:[7])
    view.christmasScene.dropsGifts=true
    view.step(0);view.inviteChristmasMoment()
    var resting:ChristmasScene.Gift?
    var sawParachute=false
    for _ in 0..<5200 {
        view.step(1/120)
        if let gift=view.christmasScene.gifts.first {
            sawParachute = sawParachute || !gift.landed
            if gift.landed { resting=gift;break }
        }
    }
    guard let gift=resting else { preconditionFailure("The sleigh must drop a gift") }
    precondition(sawParachute,"The gift must visibly float down, not appear on the ground instantly")
    precondition(gift.surface == 7,"The gift belongs on the window edge, not on the ground")
    let lip=view.ledges[7]!.height(at:gift.x)
    precondition(abs(gift.y-(lip+gift.size/2))<0.6,"The gift must rest on the snow layer")
    precondition(gift.x>window.minX && gift.x<window.maxX)
    precondition(view.wantsInteraction(at:CGPoint(x:gift.x,y:gift.y)),"A click over the gift must get through")
    precondition(view.giftUnderPointer(at:CGPoint(x:gift.x+gift.reach+6,y:gift.y)) == nil)
    precondition(!view.wantsInteraction(at:CGPoint(x:gift.x,y:gift.y-90)),"Next to it the desktop stays clickable")

    // Covered windows freeze the gift, just like the snow on them.
    view.syncWindows([],existingWindows:[7])
    view.step(1/120)
    precondition(view.giftUnderPointer(at:CGPoint(x:gift.x,y:gift.y)) == nil)
    view.syncWindows([(7,window)],existingWindows:[7])
    view.step(1/120)
    precondition(view.giftUnderPointer(at:CGPoint(x:gift.x,y:gift.y)) == gift.id)

    precondition(view.christmasScene.open(gift.id))
    precondition(!view.christmasScene.open(gift.id),"A gift can only be opened once")
    precondition(view.christmasScene.gifts.isEmpty && view.christmasScene.popCount>=5)
    precondition(view.christmasScene.isAnimating)
    for _ in 0..<300 { view.step(1/120) }
    precondition(view.christmasScene.popCount==0,"The emojis must disappear again")
    let mass=view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
    precondition(mass==0,"Gifts must not invent snow")
    view.christmas=false
    precondition(!view.christmasScene.hasGift && view.christmasScene.popCount==0)
    print("Parachuting gift lands on the window edge, is clickable only there, freezes with the window and bursts into emojis")
}
testChristmasGiftAndEmoji()

func testSantaDropsNoGifts() {
    // By request: Santa no longer drops gifts.
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    view.syncWindows([(7,CGRect(x:200,y:40,width:460,height:160))],existingWindows:[7])
    view.step(0);view.inviteChristmasMoment()
    for _ in 0..<8000 { view.step(1/120); precondition(view.christmasScene.gifts.isEmpty,"No more gifts") }
    print("Santa lands and flies on without dropping gifts")
}
testSantaDropsNoGifts()

func testThrowAnimationPhases() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:480))
    view.density=0;view.plowEnabled=false;view.step(0)
    for (x,sizes):(CGFloat,[CGFloat]) in [(180,[22,15,10]),(620,[21,14,10])] {
        addFightSnowman(view,x:x,sizes:sizes)
    }
    precondition(view.startSnowballFight())
    var lowest:CGFloat=0,highest:CGFloat=0
    var heldWhileDrawingBack=false,emptyAfterRelease=false,sawShot=false,leanedBack=false
    for _ in 0..<2400 {
        view.step(1/120)
        sawShot = sawShot || !view.fight.shots.isEmpty
        for stack in view.workshop.snowmen {
            let pose=view.fight.pose(for:stack[0].id)
            lowest=min(lowest,pose.swing);highest=max(highest,pose.swing)
            if pose.swing < -0.5 {
                heldWhileDrawingBack = heldWhileDrawingBack || pose.ballGrip>0.99
                leanedBack = leanedBack || pose.lean < -0.3
            }
            if sawShot,pose.swing>0.5 { emptyAfterRelease = emptyAfterRelease || pose.ballGrip==0 }
        }
        if lowest < -0.9 && highest > 0.9 && heldWhileDrawingBack && emptyAfterRelease && leanedBack { break }
    }
    precondition(lowest < -0.9,"The arm must visibly wind up")
    precondition(highest > 0.9,"After release the arm must swing through forwards")
    precondition(heldWhileDrawingBack,"During the wind-up the ball is in the hand")
    precondition(emptyAfterRelease,"After the throw the hand is empty")
    precondition(leanedBack,"The body shifts its weight during the wind-up")
    print("Throw animation: wind-up with ball in hand, weight shift, snap forwards and empty hand afterwards")
}
testThrowAnimationPhases()

func renderShowcase() throws {
    let width: CGFloat = 560
    func capture(_ view:SnowView) -> NSImage {
        let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
        view.cacheDisplay(in:view.bounds,to:rep)
        let image=NSImage(size:view.bounds.size)
        image.addRepresentation(rep)
        return image
    }
    func plowPanel(christmas:Bool) -> NSImage {
        let view=SnowView(frame:CGRect(x:0,y:0,width:width,height:120))
        view.density=0;view.workshopEnabled=false;view.heavyPlow.enabled=false
        view.christmas=christmas;view.step(0)
        view.plowX = -70
        for index in view.ground.indices where index>14 { view.ground[index]=CGFloat(5+index%4) }
        for _ in 0..<480 { view.step(1/120) }
        return capture(view)
    }
    func heavyPanel() -> NSImage {
        let view=SnowView(frame:CGRect(x:0,y:0,width:width,height:130))
        view.density=0;view.workshopEnabled=false;view.christmas=true;view.step(0)
        for index in view.ground.indices { view.ground[index]=20 }
        for _ in 0..<1600 {
            view.step(1/120)
            if view.heavyPlow.active && view.heavyPlow.mouth>300 { break }
            if view.ground.reduce(0,+)<520 { for index in view.ground.indices { view.ground[index]=20 } }
        }
        return capture(view)
    }
    func fightPanel() -> NSImage {
        let view=SnowView(frame:CGRect(x:0,y:0,width:width,height:170))
        view.density=0;view.plowEnabled=false;view.step(0)
        for (x,sizes):(CGFloat,[CGFloat]) in [(120,[23,16,11]),(400,[21,15,10])] {
            addFightSnowman(view,x:x,sizes:sizes)
        }
        _=view.startSnowballFight()
        for _ in 0..<2400 {
            view.step(1/120)
            let poses=view.workshop.snowmen.map { view.fight.pose(for:$0[0].id) }
            if poses.contains(where:{ $0.swing < -0.75 }) && !view.fight.shots.isEmpty { break }
        }
        return capture(view)
    }
    func giftPanel() -> (NSImage,CGRect) {
        let view=SnowView(frame:CGRect(x:0,y:0,width:width,height:190))
        view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
        let window=CGRect(x:70,y:20,width:400,height:70)
        view.syncWindows([(3,window)],existingWindows:[3])
        view.christmasScene.dropsGifts=true
        view.step(0);view.inviteChristmasMoment()
        for _ in 0..<6000 {
            view.step(1/120)
            if let gift=view.christmasScene.gifts.first,gift.landed {
                _=view.christmasScene.open(gift.id)
                for _ in 0..<34 { view.step(1/120) }
                break
            }
        }
        return (capture(view),window)
    }
    let normal=plowPanel(christmas:false)
    let festive=plowPanel(christmas:true)
    let heavy=heavyPanel()
    let fight=fightPanel()
    let (gift,giftWindow)=giftPanel()
    let panels:[(NSImage,CGRect?)]=[(normal,nil),(festive,nil),(heavy,nil),(fight,nil),(gift,giftWindow)]
    let gap: CGFloat = 8
    let height=panels.reduce(CGFloat(0)) { $0+$1.0.size.height+gap }+gap
    let sheet=NSImage(size:CGSize(width:width,height:height),flipped:false) { _ in
        NSColor(srgbRed:0.13,green:0.19,blue:0.29,alpha:1).setFill()
        CGRect(x:0,y:0,width:width,height:height).fill()
        var y=height
        for (panel,window) in panels {
            y -= panel.size.height+gap
            if let window {
                NSColor(srgbRed:0.93,green:0.95,blue:0.98,alpha:1).setFill()
                NSBezierPath(roundedRect:window.offsetBy(dx:0,dy:y),xRadius:16,yRadius:16).fill()
            }
            panel.draw(in:CGRect(x:0,y:y,width:width,height:panel.size.height),
                       from:.zero,operation:.sourceOver,fraction:1)
        }
        return true
    }
    let cg=sheet.cgImage(forProposedRect:nil,context:nil,hints:nil)!
    let png=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!
    try png.write(to:URL(fileURLWithPath:testOutput+"/showcase.png"))
    if let output=ProcessInfo.processInfo.environment["SNOW_SHOWCASE_OUTPUT"] {
        try png.write(to:URL(fileURLWithPath:output))
    }
    print("Showcase rendered: small snowplow, Christmas snowplow, snow blower, throw and gift")
}
try renderShowcase()

func testFestivePointerOnDesktop() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false
    let window=CGRect(x:200,y:100,width:300,height:200)
    view.syncWindows([(9,window)],existingWindows:[9])
    view.step(0)
    // Menu bar at the top, Dock at the bottom: both stay outside the capture area.
    view.safeArea=CGRect(x:0,y:70,width:800,height:400)
    let free=CGPoint(x:70,y:260),onWindow=CGPoint(x:350,y:200)
    precondition(!view.wantsInteraction(at:free),"Without Christmas mode the desktop stays click-through")
    view.christmas=true
    // Taking over the pointer has been off by default since 1.43: it swallows desktop clicks.
    precondition(!view.desktopPointer,"Default: the desktop keeps its pointer")
    precondition(!view.wantsInteraction(at:free),"When off, the free area stays click-through")
    view.desktopPointer=true
    precondition(view.wantsInteraction(at:free),"When on, the free area takes the pointer")
    precondition(!view.wantsInteraction(at:onWindow),"Over a working window nothing changes")
    precondition(!view.wantsInteraction(at:CGPoint(x:70,y:20)),"Nothing may be captured in the Dock area")
    precondition(!view.wantsInteraction(at:CGPoint(x:70,y:486)),"Nor in the menu bar")
    // A desktop icon at this spot always wins: clicks and drags go to the icon.
    view.desktopIcons=[CGRect(x:40,y:230,width:64,height:72)]
    precondition(!view.wantsInteraction(at:free),"Over a desktop icon Snow Day captures nothing")
    precondition(view.wantsInteraction(at:CGPoint(x:150,y:260)),"Next to it the free area stays with Snow Day")
    view.desktopIcons=[]
    view.desktopPointer=false
    precondition(!view.wantsInteraction(at:free),"When off, the snow layer releases the clicks again")
    view.desktopPointer=true
    view.christmas=false
    precondition(!view.wantsInteraction(at:free),"Outside Christmas mode it stays that way")
    print("Christmas pointer on the desktop: off by default; when on, free area yes, windows, Dock and menu bar no")
}
testFestivePointerOnDesktop()

func testSleighLandingSequence() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    let window=CGRect(x:120,y:40,width:620,height:150)
    view.syncWindows([(4,window)],existingWindows:[4])
    view.step(0);view.inviteChristmasMoment()
    var seen:[ChristmasScene.SleighPhase]=[]
    var touchdownSpeed:CGFloat=0,brakeStart:CGFloat = -1,stopX:CGFloat=0
    var restSeconds:CGFloat=0,climbed:CGFloat=0,leftBy:CGFloat = -1
    var lastSpeed:CGFloat = .infinity,brakeMonotone=true
    var clock:CGFloat=0
    for _ in 0..<9000 {
        view.step(1/120);clock+=1/120
        guard let phase=view.christmasScene.sleighPhase,let contact=view.christmasScene.sleighContact else {
            // Stop after the first visit, otherwise the next one is counted too.
            if seen.contains(.takeoff) { leftBy=clock;break }
            continue
        }
        if seen.last != phase { seen.append(phase) }
        let lip=view.ledges[4]!.height(at:contact.x)
        switch phase {
        case .approach:
            precondition(contact.y>=lip-0.5,"The approach must not sink through the window edge")
        case .brake:
            if brakeStart<0 { brakeStart=clock;touchdownSpeed=view.christmasScene.sleighSpeed;lastSpeed = .infinity }
            precondition(abs(contact.y-lip)<0.6,"While braking, the runners glide on the snow layer")
            let speed=view.christmasScene.sleighSpeed
            brakeMonotone = brakeMonotone && speed<=lastSpeed+0.0001
            lastSpeed=speed
            stopX=contact.x
        case .rest:
            precondition(view.christmasScene.sleighSpeed==0,"At rest nothing moves any more")
            precondition(abs(contact.y-lip)<0.6,"At rest the team stays on the edge")
            restSeconds+=1/120
        case .takeoff:
            climbed=max(climbed,contact.y-lip)
        case .cruise: break
        }
    }
    precondition(seen==[.cruise,.approach,.brake,.rest,.takeoff],"Order of phases: \(seen)")
    precondition(touchdownSpeed>60,"Still moving at touchdown: \(touchdownSpeed)")
    precondition(brakeMonotone,"Braking must not speed up again")
    let sill=view.ledges[4]!.frame
    let direction=1.0
    _=direction
    let nose=stopX+view.christmasScene.sleighDirection*SleighArt.noseX
    let tail=stopX+view.christmasScene.sleighDirection*SleighArt.tailX
    precondition(min(nose,tail)>=sill.minX-1 && max(nose,tail)<=sill.maxX+1,
                 "The whole team must stand on the edge after rolling to a stop: \(tail)…\(nose) in \(sill)")
    precondition(restSeconds>2.5,"The stop lasts visibly long: \(restSeconds)")
    precondition(climbed>40,"On takeoff the team visibly lifts off: \(climbed)")
    precondition(leftBy>0,"The visit ends on its own")
    let mass=view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
    precondition(mass==0,"Landing and takeoff create no snow")
    print("Sleigh landing: approach, touchdown while moving, smooth braking onto the window, stop, push-off and climb")
}
testSleighLandingSequence()

func testSleighLeavesWhenWindowGoes() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    let window=CGRect(x:120,y:40,width:620,height:150)
    view.syncWindows([(4,window)],existingWindows:[4])
    view.step(0);view.inviteChristmasMoment()
    var landed=false
    for _ in 0..<9000 {
        view.step(1/120)
        if view.christmasScene.sleighPhase == .rest { landed=true;break }
    }
    precondition(landed,"For this check the team must land first")
    view.syncWindows([],existingWindows:[4])
    view.step(1/120)
    precondition(view.christmasScene.sleighPhase == .takeoff,"If the window disappears, the team takes off immediately")
    var gone=false
    for _ in 0..<2400 {
        view.step(1/120)
        if view.christmasScene.sleighPhase == nil { gone=true;break }
    }
    precondition(gone,"Then it leaves the screen")
    precondition(!view.christmasScene.hasSanta)
    print("If the window under the team disappears, it lifts off immediately and flies cleanly off screen")
}
testSleighLeavesWhenWindowGoes()

func testRudolphVisit() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:520))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    let window=CGRect(x:120,y:40,width:620,height:150)
    view.syncWindows([(8,window)],existingWindows:[8])
    view.step(0);view.inviteChristmasMoment()
    var seen:[ChristmasScene.ReindeerPhase]=[]
    var clumsy=false,sawSparkles=false,sawLook=false,flewIn=false
    var standSeconds:CGFloat=0,leapHeight:CGFloat = -1000
    var standX:CGFloat=0,runupX:CGFloat=0
    for _ in 0..<13000 {
        view.step(1/120)
        guard let phase=view.christmasScene.reindeerPhase,let point=view.christmasScene.reindeerPoint else {
            // Stop after the first visit, otherwise the next one is counted too.
            if seen.contains(.climb) { break }
            continue
        }
        if seen.last != phase { seen.append(phase) }
        clumsy = clumsy || view.christmasScene.reindeerIsClumsy
        let lip=view.ledges[8]!.height(at:point.x)
        switch phase {
        case .arrive:
            flewIn = flewIn || point.y>lip+18
            sawSparkles = sawSparkles || view.christmasScene.reindeerSparkles>0
        case .stand:
            precondition(abs(point.y-lip)<0.6,"At rest he stands on the window edge")
            standSeconds+=1/120
            standX=point.x
            sawLook = sawLook || view.christmasScene.reindeerHeadTurn>0.9
        case .runup:
            runupX=point.x
        case .leap,.flop,.climb:
            leapHeight=max(leapHeight,point.y-lip)
            sawSparkles = sawSparkles || view.christmasScene.reindeerSparkles>0
        case .land: break
        }
    }
    // A clumsy visit takes several run-ups: arrive, land, stand, then
    // any number of runup/leap/flop rounds and finally climb.
    precondition(Array(seen.prefix(3))==[.arrive,.land,.stand],"Start: \(seen)")
    precondition(seen.last == .climb,"Finally he climbs away: \(seen)")
    precondition(seen.dropFirst(3).dropLast().allSatisfy { [.runup,.leap,.flop].contains($0) },"Sequence: \(seen)")
    let leaps=seen.filter { $0 == .leap }.count
    if clumsy {
        precondition(seen.contains(.flop),"A clumsy visit only manages the jump after failed attempts")
        precondition(leaps>=2,"He tries several times: \(seen)")
    } else {
        precondition(leaps==1 && !seen.contains(.flop),"Without clumsiness it works on the first run-up")
    }
    precondition(flewIn,"Rudolph must fly in, not appear on the edge")
    precondition(sawSparkles,"Gold dust sparkles at the hooves")
    precondition(sawLook,"At rest he turns his head to the front")
    precondition(standSeconds>8.5 && standSeconds<12,"He stays about ten seconds: \(standSeconds)")
    precondition(abs(runupX-standX)>24,"Before the jump he takes a run-up: \(standX) → \(runupX)")
    precondition(leapHeight>30,"He visibly jumps over the edge: \(leapHeight)")
    let mass=view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
    precondition(mass==0,"Rudolph creates no snow")
    print("Rudolph: fly-in with gold dust, landing, standing facing forwards, run-up, jump — when clumsy, only after several failed attempts")
}
testRudolphVisit()

func testRudolphComesBack() {
    // Guards against the bug where the visit never ends while sparkles are
    // still in the air: then no reindeer would ever come again.
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:520))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    view.syncWindows([(8,CGRect(x:120,y:40,width:620,height:150))],existingWindows:[8])
    view.step(0);view.inviteChristmasMoment()
    var visits=0,present=false
    for _ in 0..<26000 {
        view.step(1/120)
        let here=view.christmasScene.hasReindeer
        if here && !present { visits+=1 }
        present=here
        if visits>=2 && !present { break }
    }
    precondition(visits>=2,"After the first visit a second one must come: \(visits)")
    print("Rudolph's visit ends cleanly and repeats")
}
testRudolphComesBack()

func testOnlyOneRudolph() {
    // Rudolph pulls the sleigh at the front. While the sleigh is out, he must
    // not also stand alone on a window, and vice versa.
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:520))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    view.syncWindows([(8,CGRect(x:120,y:40,width:620,height:150))],existingWindows:[8])
    view.step(0);view.inviteChristmasMoment()
    var sleighSeen=false,rudolphSeen=false
    for _ in 0..<90000 {
        view.step(1/120)
        let sleigh=view.christmasScene.sleighPhase != nil
        let alone=view.christmasScene.hasReindeer
        precondition(!(sleigh && alone),"Rudolph must not be alone and in front of the sleigh at the same time")
        sleighSeen = sleighSeen || sleigh
        rudolphSeen = rudolphSeen || alone
    }
    precondition(sleighSeen || rudolphSeen,"Within twelve minutes at least one of the two must come")
    print("Only one Rudolph: never alone on the window while he pulls the sleigh")
}
testOnlyOneRudolph()

func testPondIsVisible() {
    // Until 1.72 the ice pond was hidden behind the front chalets.
    for size in [CGSize(width: 1512, height: 982), CGSize(width: 1440, height: 900), CGSize(width: 2560, height: 1440),
                 CGSize(width: 1280, height: 800)] {
        let layout = AdventLayout.make(in: CGRect(origin: .zero, size: size))
        for chalet in layout.chalets {
            let eaves = chalet.base.width * 0.4
            let house = CGRect(x: chalet.base.minX - eaves, y: chalet.base.minY,
                               width: chalet.base.width + eaves * 2, height: chalet.base.height + chalet.roof * 1.6)
            precondition(!house.intersects(layout.lake), "A chalet hides the pond at \(size)")
        }
        precondition(layout.bounds.contains(layout.lake), "The pond must be on screen at \(size)")
    }
    print("The ice pond is in clear view, at four screen sizes")
}
testPondIsVisible()

func testDoorsShowBeforeAdvent() {
    // Until 1.74 the doors were not visible at all in November. They must
    // always stand in the valley, closed and with a number plaque.
    let bounds = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let layout = AdventLayout.make(in: bounds)
    var parts = DateComponents(); parts.year = 2026; parts.month = 11; parts.day = 10; parts.hour = 13
    let date = Calendar(identifier: .gregorian).date(from: parts)!
    let suite = UserDefaults(suiteName: "snowday.check.november")!
    suite.removePersistentDomain(forName: "snowday.check.november")
    let season = AdventCalendar(defaults: suite).season(at: date)
    precondition(!season.inSeason && season.openedCount == 0, "For this check: November, nothing open")
    let image = AdventVillage.backdrop(layout, season: season, sky: AdventSky.at(date), scale: 1)!
    let rep = NSBitmapImageRep(cgImage: image)
    var plaques = 0
    for door in layout.doors {
        // Left part of the plaque above the door, clear of the digits.
        let x = Int(door.rect.midX - door.rect.width * 0.40)
        let y = Int(bounds.height - (door.rect.maxY + door.rect.width * 0.10 + max(9, door.rect.height * 0.38) * 0.5))
        guard let colour = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
        // The cream plaque is warm; snow around it is cool and bluish.
        if colour.redComponent > 0.6, colour.redComponent - colour.blueComponent > 0.05 { plaques += 1 }
    }
    precondition(plaques >= 22, "In November the door plaques must be visible: \(plaques) of 24")
    print("Doors stand in the valley even before Advent: \(plaques) of 24 plaques visible")
}
testDoorsShowBeforeAdvent()

func testDoorTestModeIsSeparate() {
    // Test mode opens doors in a separate calendar; the real one stays empty.
    let real = UserDefaults(suiteName: "snowday.check.real")!
    real.removePersistentDomain(forName: "snowday.check.real")
    let trial = UserDefaults(suiteName: "snowday.check.trial")!
    trial.removePersistentDomain(forName: "snowday.check.trial")
    trial.set(Array(1..<7), forKey: "advent.opened.2026")
    var parts = DateComponents(); parts.year = 2026; parts.month = 12; parts.day = 7; parts.hour = 18
    let view = SnowView(frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
    view.density = 0; view.plowEnabled = false; view.workshopEnabled = false; view.christmas = true
    view.adventCalendar = AdventCalendar(defaults: trial)
    view.adventDate = Calendar(identifier: .gregorian).date(from: parts)
    view.syncWindows([], existingWindows: []); view.step(0); view.step(1 / 120)
    precondition(view.openAdventDoor(7) == .garland, "In the test, door 7 must open")
    precondition(view.openAdventDoor(8) == nil, "Only the door of the test day may open")
    precondition((trial.array(forKey: "advent.opened.2026") as? [Int])?.contains(7) == true, "Test calendar remembers 7")
    precondition(real.array(forKey: "advent.opened.2026") == nil, "The real calendar stays untouched")
    print("Door test mode: separate calendar, only the door of the test day, real calendar untouched")
}
testDoorTestModeIsSeparate()

func testNoDoorBehindAHouse() {
    // Until 1.87 doors sat behind nearer houses and were drawn over their
    // walls (the 3 was stuck on the chalet with the 17).
    for size in [CGSize(width: 1512, height: 982), CGSize(width: 1440, height: 900), CGSize(width: 2560, height: 1440),
                 CGSize(width: 1280, height: 800), CGSize(width: 1728, height: 1117),
                 CGSize(width: 1920, height: 1080), CGSize(width: 1366, height: 768)] {
        let layout = AdventLayout.make(in: CGRect(origin: .zero, size: size))
        precondition(Set(layout.doors.map(\.day)) == Set(1...24), "All 24 doors at \(size)")
        let hidden = layout.doors.filter { AdventLayout.doorIsHidden($0, in: layout) }.map(\.day)
        precondition(hidden.isEmpty, "Hidden doors at \(size): \(hidden)")
    }
    print("No door behind houses, fir trees, the village tree or lanterns, at seven screen sizes")
}
testNoDoorBehindAHouse()

func testRudolphLeavesWithTheWindow() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:520))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    view.syncWindows([(8,CGRect(x:120,y:40,width:620,height:150))],existingWindows:[8])
    view.step(0);view.inviteChristmasMoment()
    var standing=false
    for _ in 0..<13000 {
        view.step(1/120)
        if view.christmasScene.reindeerPhase == .stand { standing=true;break }
    }
    precondition(standing,"For this check he must be standing first")
    view.syncWindows([],existingWindows:[8])
    view.step(1/120)
    precondition(view.christmasScene.reindeerPhase == .leap,"If the edge goes away, he jumps off immediately")
    var gone=false
    for _ in 0..<2400 {
        view.step(1/120)
        if !view.christmasScene.hasReindeer { gone=true;break }
    }
    precondition(gone,"Then he leaves the screen")
    print("If the window edge under Rudolph disappears, he jumps off and flies away")
}
testRudolphLeavesWithTheWindow()

func adventSuite(_ name:String,_ opened:[Int]) -> UserDefaults {
    let suite=UserDefaults(suiteName:name)!
    suite.removePersistentDomain(forName:name)
    if !opened.isEmpty { suite.set(opened,forKey:"advent.opened.2026") }
    return suite
}
func december(_ day:Int,_ year:Int=2026) -> Date {
    var parts=DateComponents();parts.year=year;parts.month=12;parts.day=day;parts.hour=12
    var calendar=Calendar(identifier:.gregorian);calendar.timeZone = .current
    return calendar.date(from:parts)!
}

func testAdventCalendarRules() {
    let name="snowday.test.advent"
    let calendar=AdventCalendar(defaults:adventSuite(name,[]))
    defer { UserDefaults().removePersistentDomain(forName:name) }
    var parts=DateComponents();parts.year=2026;parts.month=11;parts.day=20;parts.hour=12
    var gregorian=Calendar(identifier:.gregorian);gregorian.timeZone = .current
    let november=gregorian.date(from:parts)!
    precondition(calendar.season(at:november).today == nil,"In November no door is due")
    precondition(calendar.open(1,at:november) == nil,"Nothing can be opened before December")

    precondition(calendar.season(at:december(5)).today == 5)
    precondition(calendar.open(6,at:december(5)) == nil,"A later door stays closed")
    precondition(calendar.open(4,at:december(5)) == nil,"A missed door also stays closed")
    precondition(calendar.open(5,at:december(5)) == .smoke,"On the 5th you get the smoke")
    precondition(calendar.open(5,at:december(5)) == nil,"Opening twice is not possible")
    precondition(calendar.season(at:december(5)).isOpen(5))
    precondition(calendar.season(at:december(6)).isOpen(5),"Opened doors stay open")
    precondition(!calendar.season(at:december(6,2027)).isOpen(5),"The next season starts fresh")

    let full=AdventCalendar(defaults:adventSuite(name+".full",Array(1...24)))
    defer { UserDefaults().removePersistentDomain(forName:name+".full") }
    let season=full.season(at:december(24))
    precondition(season.warmth==1 && season.has(.rudolph) && season.has(.sleigh) && season.has(.aurora))
    precondition(AdventGift.forDay(6) == .rudolph && AdventGift.forDay(23) == .sleigh)
    for day in 1...24 { precondition(AdventGift.forDay(day) != .warmth, "Door \(day) brings a real gift") }
    precondition(Set((1...24).map { AdventGift.forDay($0).title }).count == 24, "24 different gifts")
    print("Advent calendar: only today's door, once, stays open, new season starts fresh")
}
testAdventCalendarRules()

func testAdventDoorsOnScreen() {
    let name="snowday.test.doors"
    let view=SnowView(frame:CGRect(x:0,y:0,width:1000,height:700))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false
    view.adventCalendar=AdventCalendar(defaults:adventSuite(name,Array(1...13)))
    defer { UserDefaults().removePersistentDomain(forName:name) }
    view.adventDate=december(14)
    view.christmas=true
    view.syncWindows([],existingWindows:[])
    view.step(0)
    precondition(view.villageBounds==view.bounds,"The valley fills the whole background")
    var today:CGPoint?
    var others:[CGPoint]=[]
    for day in 1...24 {
        guard let point=view.adventDoorCenter(day) else { preconditionFailure("Door \(day) is missing") }
        precondition(view.bounds.insetBy(dx:-1,dy:-1).contains(point),"Door \(day) is on screen")
        for other in others {
            precondition(hypot(other.x-point.x,other.y-point.y)>6,"Doors must not overlap")
        }
        if day==14 { today=point } else { others.append(point) }
    }
    guard let today else { preconditionFailure("Door 14 is missing") }
    precondition(view.adventDoor(at:today)==14,"Today's door accepts the click")
    precondition(view.wantsInteraction(at:today))
    for point in others { precondition(view.adventDoor(at:point)==nil,"Other doors stay click-through") }
    precondition(view.advent.openedCount==13)
    precondition(view.openAdventDoor(14) == .market)
    precondition(view.advent.openedCount==14 && view.advent.isOpen(14))
    precondition(view.adventDoor(at:today)==nil,"An opened door no longer accepts clicks")
    precondition(view.openAdventDoor(14) == nil)
    // Outside Christmas mode the village stays off.
    view.christmas=false
    precondition(view.adventDoor(at:today)==nil)
    // The street lighting grows with every door.
    let layout=AdventLayout.make(in:CGRect(x:0,y:0,width:1400,height:900))
    let lamps=layout.roads.reduce(0) { $0+$1.lamps.count }
    precondition(lamps>=20,"There are enough lanterns for a visible progression: \(lamps)")
    precondition(layout.litLamps(warmth:0)==0 && layout.litLamps(warmth:1)==lamps)
    var previous = -1
    for opened in 0...24 {
        let burning=layout.litLamps(warmth:CGFloat(opened)/24)
        precondition(burning>=previous,"The lighting must never go out again")
        previous=burning
    }
    for hour in [3, 8, 13, 17, 21] {
        var parts=DateComponents();parts.year=2026;parts.month=12;parts.day=14;parts.hour=hour
        var gregorian=Calendar(identifier:.gregorian);gregorian.timeZone = .current
        let sky=AdventSky.at(gregorian.date(from:parts)!)
        precondition(AdventVillage.backdrop(layout,season:AdventSeason(year:2026,today:14,opened:Set(1...13)),
                                            sky:sky,scale:1) != nil,"The background renders at \(hour):00")
    }
    print("24 doors across the whole valley, only today's is clickable, lighting grows with every door")
}
testAdventDoorsOnScreen()

func testAdventUnlocksVisitors() {
    SnowView.visitorsNeedDoors = true
    defer { SnowView.visitorsNeedDoors = false }
    // In November, before Advent, nobody comes either.
    do {
        var parts=DateComponents();parts.year=2026;parts.month=11;parts.day=13;parts.hour=15
        let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
        view.density=0;view.plowEnabled=false;view.workshopEnabled=false
        view.adventCalendar=AdventCalendar(defaults:adventSuite("snowday.test.november",[]))
        view.adventDate=Calendar(identifier:.gregorian).date(from:parts)
        view.christmas=true
        view.syncWindows([(3,CGRect(x:120,y:40,width:620,height:150))],existingWindows:[3])
        view.step(0);view.inviteChristmasMoment()
        var saw=false
        for _ in 0..<9000 { view.step(1/120); saw = saw || view.christmasScene.hasSanta || view.christmasScene.hasReindeer }
        UserDefaults().removePersistentDomain(forName:"snowday.test.november")
        precondition(!saw,"In November neither Rudolph nor Santa flies")
    }
    func scene(_ name:String,_ opened:[Int],_ day:Int) -> SnowView {
        let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
        view.density=0;view.plowEnabled=false;view.workshopEnabled=false
        view.adventCalendar=AdventCalendar(defaults:adventSuite(name,opened))
        view.adventDate=december(day)
        view.christmas=true
        view.syncWindows([(3,CGRect(x:120,y:40,width:620,height:150))],existingWindows:[3])
        view.step(0);view.inviteChristmasMoment()
        return view
    }
    let locked=scene("snowday.test.locked",[1,2],2)
    defer { UserDefaults().removePersistentDomain(forName:"snowday.test.locked") }
    var sawAny=false
    for _ in 0..<9000 {
        locked.step(1/120)
        sawAny = sawAny || locked.christmasScene.hasSanta || locked.christmasScene.hasReindeer
    }
    precondition(!sawAny,"Without the matching doors there is no visit")

    // From St Nicholas' Day Rudolph comes, the sleigh not yet.
    let stNicholas=scene("snowday.test.nikolaus",Array(1...6),6)
    defer { UserDefaults().removePersistentDomain(forName:"snowday.test.nikolaus") }
    var deerEarly=false,sleighEarly=false
    for _ in 0..<9000 {
        stNicholas.step(1/120)
        deerEarly = deerEarly || stNicholas.christmasScene.hasReindeer
        sleighEarly = sleighEarly || stNicholas.christmasScene.hasSanta
    }
    precondition(deerEarly && !sleighEarly,"From door 6 Rudolph comes, Santa only from door 23")

    let open=scene("snowday.test.unlocked",Array(1...23),23)
    defer { UserDefaults().removePersistentDomain(forName:"snowday.test.unlocked") }
    var sawDeer=false,sawSleigh=false
    for _ in 0..<9000 {
        open.step(1/120)
        sawDeer = sawDeer || open.christmasScene.hasReindeer
        sawSleigh = sawSleigh || open.christmasScene.hasSanta
        if sawDeer && sawSleigh { break }
    }
    precondition(sawDeer && sawSleigh,"With doors 6 and 23, Rudolph and the sleigh come")
    print("Rudolph and the sleigh depend on their doors; before that the village stays quiet")
}
testAdventUnlocksVisitors()

func testDesktopWidgetsStayVisible() {
    // It snows over widgets, but the valley is left out there.
    // If a window lies half over a widget, the window stays completely clear.
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    let widget=CGRect(x:20,y:340,width:180,height:180)
    let window=CGRect(x:120,y:300,width:300,height:160)
    view.syncWindows([(7,window)],widgets:[widget],existingWindows:[7])
    view.step(0)
    let inWidget=CGPoint(x:60,y:480), overlap=CGPoint(x:160,y:400)
    precondition(view.isVisible(inWidget),"It may snow inside the widget")
    precondition(!view.isVillageVisible(inWidget),"No valley is painted inside the widget")
    precondition(!view.isVisible(overlap),"Where the window lies over the widget, it does not snow")
    precondition(!view.isVillageVisible(overlap),"And there is no valley there either")
    precondition(view.isVisible(CGPoint(x:700,y:400)) && view.isVillageVisible(CGPoint(x:700,y:400)),"Next to it, both")
    view.syncWindows([(7,window)],widgets:[],existingWindows:[7])
    precondition(view.isVillageVisible(inWidget),"Without the widget the spot is painted again")
    print("It snows over desktop widgets, the valley stays clear there; windows above them stay completely clear")
}
testDesktopWidgetsStayVisible()

func testGroundSnowInFrontOfDock() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false
    view.safeArea=CGRect(x:0,y:80,width:900,height:455)
    view.syncWindows([],existingWindows:[])
    view.step(0)
    for index in view.ground.indices { view.ground[index]=30 }
    func alpha(_ v: NSView, at p: CGPoint) -> CGFloat {
        let rep=v.bitmapImageRepForCachingDisplay(in:v.bounds)!
        v.cacheDisplay(in:v.bounds,to:rep)
        let scale=CGFloat(rep.pixelsWide)/v.bounds.width
        return rep.colorAt(x:Int(p.x*scale),y:rep.pixelsHigh-1-Int(p.y*scale))!.alphaComponent
    }
    let inStrip=CGPoint(x:450,y:12), above=CGPoint(x:450,y:120)
    precondition(alpha(view,at:inStrip)>0.5,"Without the Dock front window, ground snow lies in the main window as before")
    let front=DockFrontView(frame:view.bounds)
    front.snow=view
    view.dockView=front
    precondition(alpha(view,at:inStrip)<0.01,"In the Dock strip the main window leaves out the ground snow")
    precondition(alpha(front,at:inStrip)>0.5,"The window in front of the Dock shows the ground snow there")
    precondition(alpha(front,at:above)<0.01,"Above the Dock the front window draws nothing")
    view.dockView=nil
    print("Ground snow and snowplows sit in front of the Dock: the main window leaves out the Dock strip, the front window fills it")
}
testGroundSnowInFrontOfDock()

func testEveryDoorInSightAndOwnPresent() {
    let kinds = (1...24).map { AdventVillage.treasureKind($0) }
    precondition(Set(kinds).count == 24, "Every door has its own motif")
    precondition(kinds[23] == 2, "The star belongs to Christmas Eve")
    for size in [CGSize(width: 1512, height: 982), CGSize(width: 1440, height: 900),
                 CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1440)] {
        let layout = AdventLayout.make(in: CGRect(origin: .zero, size: size))
        let days = layout.chalets.compactMap { $0.day }
        precondition(Set(days).count == 24, "All 24 doors stand in the village (\(size))")
        for house in layout.chalets {
            guard let day = house.day else { continue }
            let area = AdventLayout.doorArea(house)
            let blocked = layout.chalets.contains { $0.depth > house.depth && AdventLayout.covers($0, area) }
            precondition(!blocked, "Door \(day) is behind a nearer house or its roof snow (\(size))")
        }
    }
    print("All 24 doors clearly visible, even behind roof snow, at four screen sizes; 24 different motifs")
}
testEveryDoorInSightAndOwnPresent()


func testHorseSleighBelongsToDoorOne() {
    var closed = AdventSeason(); closed.year = 2026; closed.today = 1
    var opened = closed; opened.opened = [1]
    AdventVillage.roadShift = 0
    precondition(AdventGift.forDay(1) == .horseSleigh, "Door 1 brings the horse-drawn sleigh")
    for time in stride(from: CGFloat(0), to: 280, by: 3.5) {
        let road = AdventVillage.roadTraffic(season: closed, time: time)
        precondition(road.sleigh == nil, "Before door 1 no horse-drawn sleigh runs (t=\(time))")
    }
    // The tractor has its own door, 2.
    precondition(AdventVillage.roadTraffic(season: closed, time: 100).tractor == nil)
    var withTractor = opened; withTractor.opened = [1, 2]
    precondition(AdventVillage.roadTraffic(season: withTractor, time: 100).tractor != nil)
    precondition(AdventVillage.roadTraffic(season: opened, time: 20).sleigh != nil, "After door 1 the sleigh runs")
    // Opened while the road waits: the sleigh sets off at once from the edge.
    AdventVillage.cueHorseSleigh(at: 40)
    let now = AdventVillage.roadTraffic(season: opened, time: 40)
    precondition(now.sleigh != nil && now.sleigh!.t < 0.001, "The sleigh starts right after opening")
    // Opened while the tractor is out: it is not cut short.
    AdventVillage.roadShift = 0
    let before = AdventVillage.roadTraffic(season: withTractor, time: 100).tractor
    AdventVillage.cueHorseSleigh(at: 100)
    let after = AdventVillage.roadTraffic(season: withTractor, time: 100).tractor
    precondition(before != nil && after != nil && abs(before!.t - after!.t) < 0.0001, "A moving tractor is not cut short")
    AdventVillage.roadShift = 0
    print("Horse-drawn sleigh belongs to door 1: before that only the tractor, on opening the sleigh sets off at once")
}
testHorseSleighBelongsToDoorOne()

func testAllDoorsTestMode() {
    let suite = adventSuite("snowday.test.alldoors", [])
    defer { UserDefaults().removePersistentDomain(forName: "snowday.test.alldoors") }
    let normal = AdventCalendar(defaults: suite)
    precondition(!normal.season(at: december(5)).canOpen(9), "Normally only today's door is open")
    let all = AdventCalendar(defaults: suite, anyDay: true)
    for day in 1...24 { precondition(all.season(at: december(24)).canOpen(day), "In test mode door \(day) is clickable") }
    precondition(all.open(9, at: december(24)) != nil && all.open(1, at: december(24)) == .horseSleigh)
    let state = all.season(at: december(24))
    precondition(state.isOpen(9) && state.isOpen(1) && !state.canOpen(9) && state.canOpen(10), "Opened ones stay open, the rest stay clickable")
    // The view: a click on any door's rect opens it.
    let view = SnowView(frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
    view.density = 0; view.plowEnabled = false; view.workshopEnabled = false
    view.adventCalendar = AdventCalendar(defaults: adventSuite("snowday.test.alldoors2", []), anyDay: true)
    defer { UserDefaults().removePersistentDomain(forName: "snowday.test.alldoors2") }
    view.adventDate = december(24)
    view.christmas = true
    view.syncWindows([], existingWindows: [])
    view.step(0)
    let layout = AdventLayout.make(in: view.bounds)
    for door in layout.doors { precondition(view.adventDoor(at: CGPoint(x: door.rect.midX, y: door.rect.midY)) == door.day, "Click hits door \(door.day)") }
    print("Test mode: all 24 doors clickable at once, real calendar untouched")
}
testAllDoorsTestMode()

func testVignetteOnEveryMonitor() {
    let context = CIContext()
    func edge(_ width: Int, _ height: Int) -> UInt8 {
        let white = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
        let out = AdventVillage.vignette(white, extent: white.extent)
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(out, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: height / 2, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return pixel[0]
    }
    let laptop = edge(3024, 1964)
    for (width, height) in [(3840, 2160), (5120, 2160), (6880, 2880), (7680, 2160)] {
        let side = edge(width, height)
        precondition(abs(Int(side) - Int(laptop)) <= 6, "Edge at \(width)×\(height): \(side) instead of about \(laptop)")
    }
    print("Vignette the same on every monitor: side edge stays as bright as on a MacBook, even on ultrawide")
}
testVignetteOnEveryMonitor()

func testSmokeStampLooksLikeGradient() {
    // A puff of smoke as a stamp must look like the former gradient:
    // same color, same extent, same soft edge.
    func render(_ paint: (CGContext) -> Void) -> [UInt8] {
        let ctx = CGContext(data: nil, width: 120, height: 80, bitsPerComponent: 8, bytesPerRow: 480,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: 2, y: 2)
        paint(ctx)
        return Array(UnsafeBufferPointer(start: ctx.data!.assumingMemoryBound(to: UInt8.self), count: 120 * 80 * 4))
    }
    for (radius, alpha) in [(6.3 as CGFloat, 0.45 as CGFloat), (13.8, 0.8), (21.2, 0.2)] {
        let old = render { ctx in
            ctx.saveGState(); ctx.translateBy(x: 30, y: 20); ctx.scaleBy(x: 1.25, y: 1)
            AdventPaint.glow(ctx, at: .zero, radius: radius, 0x8e97aa, alpha); ctx.restoreGState()
        }
        let new = render { ctx in AdventPaint.glowStamp(ctx, at: CGPoint(x: 30, y: 20), radius: radius, 0x8e97aa, alpha, stretch: 1.25) }
        var worst = 0, total = 0
        for i in 0..<old.count { let d = abs(Int(old[i]) - Int(new[i])); worst = max(worst, d); total += d }
        let mean = Double(total) / Double(old.count)
        precondition(worst <= 24 && mean < 1.0, "Smoke stamp r=\(radius): largest deviation \(worst), mean \(mean)")
    }
    print("Smoke from stamps: looks like the former gradient but no longer costs graphics performance")
}
testSmokeStampLooksLikeGradient()

func testEveryPointerHasAChristmasPicture() {
    let keeper = FestivePointerKeeper()
    let pairs = FestiveCursorArt.festivePairs()
    precondition(pairs.count >= 17, "Too few pointers: \(pairs.count)")
    for pair in pairs {
        let festive = pair.festive()
        precondition(FestivePointerKeeper.mark(festive) != FestivePointerKeeper.mark(pair.plain),
                     "Christmas image must differ from the system pointer")
        precondition(festive.image.size.width > 4 && festive.image.size.height > 4)
    }
    // The text cursor keeps its hot spot so the insertion point sits in the same place.
    let beam = FestiveCursorArt.candyBeam(like: .iBeam, vertical: false)
    precondition(beam.hotSpot == NSCursor.iBeam.hotSpot && beam.image.size == NSCursor.iBeam.image.size)
    // Resize: the center of the fir trees is the hot spot.
    let trees = FestiveCursorArt.firTrees([90, 270])
    precondition(trees.hotSpot == CGPoint(x: 14, y: 14))
    _ = keeper
    print("All \(pairs.count) system pointers have a Christmas image: candy cane text cursor, fir trees for resizing")
}
testEveryPointerHasAChristmasPicture()
