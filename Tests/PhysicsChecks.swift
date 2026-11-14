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
    print("Seitenwind: \(columns), \(evaluated) Stichproben, beide Richtungen")
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
        precondition(snow.flakes.isEmpty,"Kleiner Pflug darf keine Rückkopplung durch Auswurf vor der Schaufel erzeugen")
        precondition(snow.ground.max()! <= 11)
    }
    precondition(snow.plowLoad > 5 && snow.ground.reduce(0,+) >= 318)
    let mass = snow.ground.reduce(0, +) + snow.plowLoad + snow.plowRemoved + snow.flakes.reduce(0, { $0 + $1.looseSnow })
    precondition(abs(mass - 330) < 0.0001)
    snow.plowEnabled = false
    for _ in 0..<55 { snow.step(1 / 60) }
    precondition(snow.flakes.isEmpty && abs(snow.ground.reduce(0, +) - 330) < 0.0001, "Unload \(snow.flakes.count), ground \(snow.ground.reduce(0, +))")
    print("Kleiner Pflug: begrenzte Ladung, kein wieder eingesammelter Auswurf, Masse beim Ausschalten erhalten")
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
    print("Zeigerschub: Schneewulst ist sichtbar, bevor er sein Ziel erreicht")
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
    print("Schneller Schub: kontinuierlicher Weg, Rundung, Fall außerhalb des Fensters, Masse erhalten")
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
    print("30/60/120 und ungleichmäßige Bildraten: Schwerpunkte \(centers)")
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
// Hier geht es um den Schnee auf der Fensterkante: der Weihnachtsmodus darf ihn
// nicht verändern. Das Winterdorf ist eine eigene, gewollte Ebene und wird für
// diesen Vergleich abgeschaltet; es hat eigene Prüfungen.
snow.villageEnabled = false
func shot(_ festive: Bool) -> Data {
    snow.christmas = festive
    let rep = snow.bitmapImageRepForCachingDisplay(in: snow.bounds)!
    snow.cacheDisplay(in: snow.bounds, to: rep)
    return rep.representation(using: .png, properties: [:])!
}
precondition(shot(false) == shot(true))
print("Pulver gebündelt, Schneemenge erhalten, langsamer Zeigerschub und keine Lichter auf der Fensterkante geprüft")

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
             "Auch an der vollen Schaufel muss ein hoher Haufen seitlich absinken können")
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
precondition(Set(plainMarks).isDisjoint(with: festiveMarks), "Weihnachtszeiger und Systemzeiger müssen unterscheidbar sein")
precondition(FestivePointerKeeper.mark(NSCursor.arrow) == FestivePointerKeeper.mark(NSCursor.arrow))
FestiveCursorArt.style = .plain
precondition(FestiveCursorArt.pointer == nil && FestiveCursorArt.open(true) === NSCursor.openHand)
FestiveCursorArt.style = .peppermint
precondition(FestiveCursorArt.pointer === FestiveCursorArt.candy[0])
FestiveCursorArt.style = .candyCane
print("Drei Tiefen, Fenstermaske, 20 Prozent, geglätteter Boden, Originalkontur und animierter Ladeball geprüft")

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
print("Zeigerschub, Wulst und rückwärtiger Abwurf, Fensterabtastung und Frost nach Schließen geprüft")

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
print(String(format: "Nach 60 s bei Normal, Pflug aus: Fensterkante Ø %.1f pt, Boden Ø %.1f pt", ledgeMean, groundMean))
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
print("Zeigerspitze, Impuls, Fensterrutschen, Überlauf und Frostfenster geprüft")

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
print("Retina-Kanten und Radstand, Schnee vor dem Zeiger, Reichweite der Zeigerform und Fensterkante geprüft")

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
print("Linke und rechte Fensterkante, Teilfelder, Schneemenge und Kontakt beim Vergrößern geprüft")

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
print("Sichtbare Reise, Erhaltung der Schneemenge, Hindernis, Fensterbewegung und Zurücksetzen geprüft")

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
print("Teilräumung, Masse, Lastbremse, Abladen und Neustart geprüft")
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
print("Treffer, Kippen, Kopf, Bauch, Sockel, Schnee am Boden und Abbruch geprüft")

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
    print("Volle Schneeschicht: örtlicher Aufprall, sichtbares Abrutschen, Schneemenge erhalten")
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
        precondition(abs(mass-729) < 0.0001, "Pflug verliert Schnee: \(mass)")
    }
    print("Restschnee direkt hinter dem Pflug: \(maximumResidue)")
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
    print("Fenster nehmen Schnee aufwärts mit und schieben ihn seitlich vor sich her")
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
    print("Große Schneefräse übernimmt bei Überlast, räumt vollständig und bleibt bei wenig Schnee aus")
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
    print("Langsames Wischen über die Rundung: keine Wand, kein Resthaufen, Schnee landet unten")
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
print("Ballbildung",snow.workshop.balls.map { ($0.x,$0.radius,$0.mass) },"Masse",mass,initial)
precondition(snow.workshop.balls.count == 1 && abs(mass-initial) < 0.001)
precondition(snow.workshop.balls[0].mass > 200 && snow.workshop.balls[0].x > 620)
precondition(snow.workshop.balls[0].lastPush > 2.48, "Druckkontakt darf beim Wachsen nicht abreißen")
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
print("Klicken, Anheben, freies Stapeln und drei verschiedene Proportionen geprüft")

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
    let key = "Schneetag.test.packing." + UUID().uuidString
    defer { UserDefaults.standard.removeObject(forKey:key); panel.close() }
    view.workshop.storageKey = key
    view.workshop.save()
    let restored = SnowWorkshop()
    restored.storageKey = key
    restored.restore()
    precondition(restored.balls.count == 1 && restored.balls[0].mass == 100)
    print("Klicks nach dem Ablegen freigegeben, auch bei verdecktem Desktop; Kugeln wiederhergestellt")
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
        precondition(hypot(a.x-b.x,a.y-b.y) >= a.radius+b.radius-0.4,"Kugeln durchdringen sich")
    }
    precondition(touching.balls[1].x > 265 && touching.balls.reduce(0,{$0+$1.mass}) == mass)
    let vertical = SnowWorkshop()
    ball(vertical,300,16)
    for frame in 0..<50 {
        advance(vertical,frame,CursorSweep(start:CGPoint(x:300,y:80-CGFloat(frame)),
                end:CGPoint(x:300,y:79-CGFloat(frame)),shape:CursorShape.arrow!,duration:1/120))
    }
    precondition(vertical.balls[0].x == 300,"Senkrechtes Annähern darf Kugel nicht seitlich vertreiben")
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
    print("Kugeln verdrängen sich ohne Masseverlust; senkrechter Griff stabil; Fenster heben und schieben Kugeln")
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
    print("Auch bei vollem Partikelbudget bleibt die Schneemenge am Aufprallort erhalten")
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
    precondition(view.wantsInteraction(at:pointer),"Geschobene Kugel muss am selben Berührungspunkt greifbar sein")
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
    print("Kugel am Druckpunkt greifbar; Fallen auf andere Kugel stapelt; Auflage folgt Schneehöhe")
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
    print("Desktop einblenden: Fensterauflage und Kugel bleiben eingefroren und kehren unverändert zurück")
}
testDesktopSuspension()

func testBacklogAndPlowExclusion() {
    for values in [Array(repeating:CGFloat(2),count:100),[CGFloat(35)]+Array(repeating:CGFloat(0),count:99)] {
        let blower = HeavyPlow()
        var ground = values
        for _ in 0..<1200 { blower.step(1/120,ground:&ground,cell:8,width:800,smallLoad:29) }
        precondition(!blower.active,"Volle Schaufel oder einzelner hoher Krümel ist kein Schneestau")
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
            if let stopped { precondition(view.plowX == stopped,"Kleiner Pflug fährt während der Fräsenfahrt") }
            else { stopped = view.plowX }
        } else if stopped != nil {
            precondition(view.plowX < 0)
            resumed = true
            break
        }
    }
    precondition(stopped != nil && resumed)
    print("Fräse nur bei anhaltendem Bodenstau; kleiner Pflug steht währenddessen und startet danach von links")
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
    print("Große Greifzone schützt vor Desktop-Klicks; ganze Schneemänner wachsen beim Schieben nicht")
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
    print("Gespeicherte unsichtbare Kugeln blockieren weder Formen noch Fallen oder Stapeln")
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
    print("Greifhand und 5-mm-Klickzone verändern die Druckkontur nicht; echte App-Zeiger werden weiterhin erkannt")
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
    let key = "Schneetag.test.restore-pressure."+UUID().uuidString
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
    print("Schmaler Fensterrest erhält die Auflage; Wiederherstellung übernimmt keine veralteten Cursorimpulse")
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
            precondition(!window.contains(disk),"Kugel verschwindet beim langsamen Rollen im Fenster")
        }
        precondition(rounded > 3 && view.workshop.balls.isEmpty)
        let landed = view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
        precondition(abs(landed-radius*radius*CGFloat.pi/8) < 0.001)
    }
    print("Kugeln rollen links und rechts über die Rundung, fallen außerhalb des Fensters und behalten ihre Masse")
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
        precondition(abs(current-mass) < 0.001,"Aufprall muss die Schneemenge erhalten")
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
    print("Harter Bodenaufprall zerlegt Kugeln in Schnee; sanftes Ablegen bleibt heil; Masse in jedem Schritt erhalten")
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
    print("Wurf übernimmt die Handbewegung; harte Stapellandung zerfällt nacheinander ohne hängende Kugeln")
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
    print("Auch ein gerade über die Ecke rollender Schneemann bleibt beim Ausblenden vollständig gespeichert")
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
    precondition(edge.edgeSurface == 1 && edge.x-683.9 < 0.302,"Ein Physikschritt darf an der Ecke nicht doppelt weit gehen")
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
    print("Kein Bewegungssprung beim Übergang in den Fall; Wurfimpuls bei 30/60/120 Abtastungen gleich")
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
            precondition(view.flakes.isEmpty,"Keine neue Schneespitze durch wieder eingesammelten Auswurf")
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
        precondition(abs(total-100)<0.0001,"Auch Schnee, der auf die volle Schaufel fällt, darf nicht verschwinden")
    }
    precondition(loaded.flakes.isEmpty && loaded.ground.reduce(0,+)>=88)
    print("Kleiner Pflug nimmt je Fahrt höchstens 12 mit, lässt den Rest liegen und baut bei 30/60/120 Hz keine Spitzen auf")
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
        precondition(abs(mass-total)<0.0001,"Übergabe an die große Fräse verliert oder dupliziert Schnee")
    }
    precondition(heavyPasses==1 && view.heavyPlow.removed>total*0.9)
    precondition(view.ground.max()!<2.1)
    print("Nach echtem Schneeaufbau räumt die Fräse genau einmal gründlich; kleine Fahrt pausiert und Masse bleibt bilanziert")
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
    precondition(stack.allSatisfy { abs($0.x-stack[0].x)<0.001 },"Jede Kugel muss genau mittig über der unteren Kugel stehen")
    let look=SnowmanLook(stack)
    let key="schneetag.test.personality";view.workshop.storageKey=key;defer{UserDefaults.standard.removeObject(forKey:key)}
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
                 "Auch gespeicherte frühere Stapel müssen sofort mittig ausgerichtet werden")
    var hats=Set<Int>(),colors=Set<Int>(),widths=Set<CGFloat>()
    for i in 0..<60 {
        var sample=stack
        sample[0]=PackedSnowball(id:UUID(uuidString:String(format:"00000000-0000-0000-0000-%012d",i))!,x:0,y:0,mass:stack[0].mass)
        let variant=SnowmanLook(sample);hats.insert(variant.hat);colors.insert(variant.palette);widths.insert(variant.branchWidth)
    }
    precondition(hats.count==6 && colors.count==7 && widths.count>=4)
    print("Sechs Hutformen, sieben Farben, variable Äste und Karotten; Kugeln stehen mittig, Persönlichkeit und Krone bleiben gespeichert")
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
            precondition(abs(mass-initial)<0.001,"Schneeballschlacht verliert Schnee: \(mass), erwartet \(initial)")
            precondition(view.plowX==stopped && !view.heavyPlow.active)
            if let winner=view.fight.winner {
                precondition(!view.fight.fighting && view.workshop.snowmen.count==1)
                precondition(view.workshop.snowmen[0][0].id==winner && view.workshop.snowmen[0][0].crowned==true)
                precondition(view.fight.shots.isEmpty && view.fight.pose(for:winner).celebrating>0)
                won=true;break
            }
        }
        precondition(sawFlight && sawDamage && won,"Jede Runde muss bis zu einem gekrönten Überlebenden laufen")
    }
    print("Schneeballschlacht bei 30/120 Hz: Würfe, Treffer, Zerfallen, ein Sieger mit Krone; Schneemenge erhalten und Pflüge pausiert")
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
    print("Eine Figur startet keine Schlacht; ausgeblendete Figuren pausieren die Runde; Beenden gibt geworfenen Schnee zurück")
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
            precondition(alpha<0.01,"Geworfene Schneebälle dürfen Arbeitsfenster nicht übermalen")
            checked=true;break
        }
    }
    precondition(checked)
    view.clearSnowmen()
    precondition(!view.fight.isRunning && view.fight.shots.isEmpty && view.workshop.balls.isEmpty)
    print("Geworfene Bälle bleiben hinter Arbeitsfenstern; Entfernen der Figuren beendet auch eine laufende Runde")
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
            precondition(sample.alphaComponent<0.01,"Der Schlitten darf kein Arbeitsfenster übermalen")
            checkedMask=true
        }
        if sawSanta && sawReindeer && checkedMask { break }
    }
    precondition(sawSanta && sawReindeer && checkedMask)
    let mass=view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
    precondition(mass==0,"Weihnachtsbesuche dürfen keine Schneemasse erfinden")
    view.christmas=false
    precondition(!view.christmasScene.hasSanta && !view.christmasScene.hasReindeer)
    print("Weihnachtsbesuch: Schlitten und Rentier erscheinen, Fenster bleiben frei, Besucher erzeugen keinen Schnee und lassen sich sauber ausschalten")
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
    guard let gift=resting else { preconditionFailure("Der Schlitten muss ein Geschenk abwerfen") }
    precondition(sawParachute,"Das Geschenk muss sichtbar herunterschweben, nicht sofort liegen")
    precondition(gift.surface == 7,"Das Geschenk gehört auf die Fensterkante, nicht auf den Boden")
    let lip=view.ledges[7]!.height(at:gift.x)
    precondition(abs(gift.y-(lip+gift.size/2))<0.6,"Das Geschenk muss auf der Auflage aufsitzen")
    precondition(gift.x>window.minX && gift.x<window.maxX)
    precondition(view.wantsInteraction(at:CGPoint(x:gift.x,y:gift.y)),"Über dem Geschenk muss der Klick ankommen")
    precondition(view.giftUnderPointer(at:CGPoint(x:gift.x+gift.reach+6,y:gift.y)) == nil)
    precondition(!view.wantsInteraction(at:CGPoint(x:gift.x,y:gift.y-90)),"Daneben bleibt der Desktop klickbar")

    // Verdeckte Fenster frieren das Geschenk ein, wie die Schneeauflage auch.
    view.syncWindows([],existingWindows:[7])
    view.step(1/120)
    precondition(view.giftUnderPointer(at:CGPoint(x:gift.x,y:gift.y)) == nil)
    view.syncWindows([(7,window)],existingWindows:[7])
    view.step(1/120)
    precondition(view.giftUnderPointer(at:CGPoint(x:gift.x,y:gift.y)) == gift.id)

    precondition(view.christmasScene.open(gift.id))
    precondition(!view.christmasScene.open(gift.id),"Ein Geschenk lässt sich nur einmal öffnen")
    precondition(view.christmasScene.gifts.isEmpty && view.christmasScene.popCount>=5)
    precondition(view.christmasScene.isAnimating)
    for _ in 0..<300 { view.step(1/120) }
    precondition(view.christmasScene.popCount==0,"Die Emojis müssen wieder verschwinden")
    let mass=view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
    precondition(mass==0,"Geschenke dürfen keinen Schnee erfinden")
    view.christmas=false
    precondition(!view.christmasScene.hasGift && view.christmasScene.popCount==0)
    print("Geschenk am Fallschirm landet auf der Fensterkante, ist nur dort klickbar, friert mit dem Fenster ein und platzt in Emojis")
}
testChristmasGiftAndEmoji()

func testSantaDropsNoGifts() {
    // Auf Wunsch: Der Weihnachtsmann wirft keine Geschenke mehr ab.
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    view.syncWindows([(7,CGRect(x:200,y:40,width:460,height:160))],existingWindows:[7])
    view.step(0);view.inviteChristmasMoment()
    for _ in 0..<8000 { view.step(1/120); precondition(view.christmasScene.gifts.isEmpty,"Kein Geschenk mehr") }
    print("Der Weihnachtsmann landet und fliegt weiter, ohne Geschenke abzuwerfen")
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
    precondition(lowest < -0.9,"Der Arm muss sichtbar ausholen")
    precondition(highest > 0.9,"Nach dem Lösen muss der Arm nach vorn durchschwingen")
    precondition(heldWhileDrawingBack,"Beim Ausholen liegt der Ball in der Hand")
    precondition(emptyAfterRelease,"Nach dem Wurf ist die Hand leer")
    precondition(leanedBack,"Der Körper verlagert sein Gewicht beim Ausholen")
    print("Wurfanimation: Ausholen mit Ball in der Hand, Gewichtsverlagerung, Schnappen nach vorn und leere Hand danach")
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
    print("Schaubild gerendert: kleiner Pflug, Weihnachtspflug, Fräse, Wurf und Geschenk")
}
try renderShowcase()

func testFestivePointerOnDesktop() {
    let view=SnowView(frame:CGRect(x:0,y:0,width:800,height:500))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false
    let window=CGRect(x:200,y:100,width:300,height:200)
    view.syncWindows([(9,window)],existingWindows:[9])
    view.step(0)
    // Menüleiste oben, Dock unten: beides bleibt außerhalb der Fangfläche.
    view.safeArea=CGRect(x:0,y:70,width:800,height:400)
    let free=CGPoint(x:70,y:260),onWindow=CGPoint(x:350,y:200)
    precondition(!view.wantsInteraction(at:free),"Ohne Weihnachtsmodus bleibt der Desktop durchlässig")
    view.christmas=true
    // Die Übernahme ist seit 1.43 standardmäßig aus: sie schluckt Desktop-Klicks.
    precondition(!view.desktopPointer,"Voreinstellung: der Desktop behält seinen Zeiger")
    precondition(!view.wantsInteraction(at:free),"Abgeschaltet bleibt die freie Fläche durchlässig")
    view.desktopPointer=true
    precondition(view.wantsInteraction(at:free),"Eingeschaltet nimmt die freie Fläche den Zeiger an")
    precondition(!view.wantsInteraction(at:onWindow),"Über einem Arbeitsfenster bleibt alles unverändert")
    precondition(!view.wantsInteraction(at:CGPoint(x:70,y:20)),"Im Dock-Bereich darf nichts abgefangen werden")
    precondition(!view.wantsInteraction(at:CGPoint(x:70,y:486)),"In der Menüleiste ebenso wenig")
    // Ein Desktop-Symbol an dieser Stelle gewinnt immer: klicken und ziehen gehen an das Symbol.
    view.desktopIcons=[CGRect(x:40,y:230,width:64,height:72)]
    precondition(!view.wantsInteraction(at:free),"Über einem Desktop-Symbol fängt Schneetag nichts ab")
    precondition(view.wantsInteraction(at:CGPoint(x:150,y:260)),"Daneben bleibt die freie Fläche bei Schneetag")
    view.desktopIcons=[]
    view.desktopPointer=false
    precondition(!view.wantsInteraction(at:free),"Abgeschaltet gibt die Schneeschicht die Klicks wieder frei")
    view.desktopPointer=true
    view.christmas=false
    precondition(!view.wantsInteraction(at:free),"Außerhalb des Weihnachtsmodus bleibt es dabei")
    print("Weihnachtszeiger auf dem Desktop: standardmäßig aus; eingeschaltet freie Fläche ja, Fenster, Dock und Menüleiste nein")
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
            // Nach dem ersten Besuch aufhören, sonst zählt der nächste mit.
            if seen.contains(.takeoff) { leftBy=clock;break }
            continue
        }
        if seen.last != phase { seen.append(phase) }
        let lip=view.ledges[4]!.height(at:contact.x)
        switch phase {
        case .approach:
            precondition(contact.y>=lip-0.5,"Der Anflug darf nicht durch die Fensterkante sinken")
        case .brake:
            if brakeStart<0 { brakeStart=clock;touchdownSpeed=view.christmasScene.sleighSpeed;lastSpeed = .infinity }
            precondition(abs(contact.y-lip)<0.6,"Beim Bremsen laufen die Kufen auf der Auflage")
            let speed=view.christmasScene.sleighSpeed
            brakeMonotone = brakeMonotone && speed<=lastSpeed+0.0001
            lastSpeed=speed
            stopX=contact.x
        case .rest:
            precondition(view.christmasScene.sleighSpeed==0,"Im Stand bewegt sich nichts mehr")
            precondition(abs(contact.y-lip)<0.6,"Im Stand bleibt das Gespann auf der Kante")
            restSeconds+=1/120
        case .takeoff:
            climbed=max(climbed,contact.y-lip)
        case .cruise: break
        }
    }
    precondition(seen==[.cruise,.approach,.brake,.rest,.takeoff],"Reihenfolge der Phasen: \(seen)")
    precondition(touchdownSpeed>60,"Beim Aufsetzen ist noch Fahrt drauf: \(touchdownSpeed)")
    precondition(brakeMonotone,"Die Bremsung darf nicht wieder beschleunigen")
    let sill=view.ledges[4]!.frame
    let direction=1.0
    _=direction
    let nose=stopX+view.christmasScene.sleighDirection*SleighArt.noseX
    let tail=stopX+view.christmasScene.sleighDirection*SleighArt.tailX
    precondition(min(nose,tail)>=sill.minX-1 && max(nose,tail)<=sill.maxX+1,
                 "Das ganze Gespann muss nach dem Ausrollen auf der Kante stehen: \(tail)…\(nose) in \(sill)")
    precondition(restSeconds>2.5,"Der Halt dauert sichtbar an: \(restSeconds)")
    precondition(climbed>40,"Beim Start hebt das Gespann sichtbar ab: \(climbed)")
    precondition(leftBy>0,"Der Besuch endet von selbst")
    let mass=view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
    precondition(mass==0,"Landung und Start erzeugen keinen Schnee")
    print("Schlittenlandung: Anflug, Aufsetzen mit Fahrt, gleichmäßige Bremsung aufs Fenster, Halt, Abdruck und Steigflug")
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
    precondition(landed,"Für diese Prüfung muss das Gespann erst landen")
    view.syncWindows([],existingWindows:[4])
    view.step(1/120)
    precondition(view.christmasScene.sleighPhase == .takeoff,"Verschwindet das Fenster, startet das Gespann sofort")
    var gone=false
    for _ in 0..<2400 {
        view.step(1/120)
        if view.christmasScene.sleighPhase == nil { gone=true;break }
    }
    precondition(gone,"Danach verlässt es den Bildschirm")
    precondition(!view.christmasScene.hasSanta)
    print("Verschwindet das Fenster unter dem Gespann, hebt es sofort ab und fliegt sauber aus dem Bild")
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
            // Nach dem ersten Besuch aufhören, sonst zählt der nächste mit.
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
            precondition(abs(point.y-lip)<0.6,"Im Stand steht er auf der Fensterkante")
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
    // Ein tollpatschiger Besuch läuft mehrmals an: arrive, land, stand, dann
    // beliebig viele runup/leap/flop-Runden und am Ende climb.
    precondition(Array(seen.prefix(3))==[.arrive,.land,.stand],"Anfang: \(seen)")
    precondition(seen.last == .climb,"Zuletzt steigt er weg: \(seen)")
    precondition(seen.dropFirst(3).dropLast().allSatisfy { [.runup,.leap,.flop].contains($0) },"Ablauf: \(seen)")
    let leaps=seen.filter { $0 == .leap }.count
    if clumsy {
        precondition(seen.contains(.flop),"Ein tollpatschiger Besuch schafft den Absprung erst nach Fehlversuchen")
        precondition(leaps>=2,"Er probiert es mehrmals: \(seen)")
    } else {
        precondition(leaps==1 && !seen.contains(.flop),"Ohne Tollpatschigkeit klappt es im ersten Anlauf")
    }
    precondition(flewIn,"Rudolph muss einfliegen, nicht auf der Kante erscheinen")
    precondition(sawSparkles,"An den Hufen glitzert Goldstaub")
    precondition(sawLook,"Im Stand dreht er den Kopf nach vorn")
    precondition(standSeconds>8.5 && standSeconds<12,"Er bleibt rund zehn Sekunden: \(standSeconds)")
    precondition(abs(runupX-standX)>24,"Vor dem Absprung nimmt er Anlauf: \(standX) → \(runupX)")
    precondition(leapHeight>30,"Er springt sichtbar über die Kante: \(leapHeight)")
    let mass=view.ground.reduce(0,+)+view.flakes.reduce(0,{$0+$1.looseSnow})
    precondition(mass==0,"Rudolph erzeugt keinen Schnee")
    print("Rudolph: Einflug mit Goldstaub, Landung, Stehen mit Blick nach vorn, Anlauf, Absprung — tollpatschig erst nach mehreren Fehlversuchen")
}
testRudolphVisit()

func testRudolphComesBack() {
    // Sicherung gegen den Fehler, dass der Besuch nie endet, solange noch
    // Glitzer in der Luft hängt: dann käme nie wieder ein Rentier.
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
    precondition(visits>=2,"Nach dem ersten Besuch muss ein zweiter kommen: \(visits)")
    print("Rudolphs Besuch endet sauber und wiederholt sich")
}
testRudolphComesBack()

func testOnlyOneRudolph() {
    // Rudolph zieht den Schlitten an der Spitze. Solange der Schlitten
    // unterwegs ist, darf er nicht zusätzlich allein auf einem Fenster stehen,
    // und umgekehrt.
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:520))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    view.syncWindows([(8,CGRect(x:120,y:40,width:620,height:150))],existingWindows:[8])
    view.step(0);view.inviteChristmasMoment()
    var sleighSeen=false,rudolphSeen=false
    for _ in 0..<90000 {
        view.step(1/120)
        let sleigh=view.christmasScene.sleighPhase != nil
        let alone=view.christmasScene.hasReindeer
        precondition(!(sleigh && alone),"Rudolph darf nicht gleichzeitig allein und vor dem Schlitten sein")
        sleighSeen = sleighSeen || sleigh
        rudolphSeen = rudolphSeen || alone
    }
    precondition(sleighSeen || rudolphSeen,"In zwölf Minuten muss mindestens einer der beiden kommen")
    print("Nur ein Rudolph: nie allein auf dem Fenster, während er den Schlitten zieht")
}
testOnlyOneRudolph()

func testPondIsVisible() {
    // Der Eisweiher lag bis 1.72 unsichtbar hinter den vorderen Chalets.
    for size in [CGSize(width: 1512, height: 982), CGSize(width: 1440, height: 900), CGSize(width: 2560, height: 1440),
                 CGSize(width: 1280, height: 800)] {
        let layout = AdventLayout.make(in: CGRect(origin: .zero, size: size))
        for chalet in layout.chalets {
            let eaves = chalet.base.width * 0.4
            let house = CGRect(x: chalet.base.minX - eaves, y: chalet.base.minY,
                               width: chalet.base.width + eaves * 2, height: chalet.base.height + chalet.roof * 1.6)
            precondition(!house.intersects(layout.lake), "Ein Chalet verdeckt den Weiher bei \(size)")
        }
        precondition(layout.bounds.contains(layout.lake), "Der Weiher muss im Bild liegen bei \(size)")
    }
    print("Der Eisweiher liegt frei im Bild, bei vier Bildschirmgrößen")
}
testPondIsVisible()

func testDoorsShowBeforeAdvent() {
    // Im November waren die Türchen bis 1.74 gar nicht zu sehen. Sie müssen
    // immer im Tal stehen, geschlossen und mit Nummernschild.
    let bounds = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let layout = AdventLayout.make(in: bounds)
    var parts = DateComponents(); parts.year = 2026; parts.month = 11; parts.day = 10; parts.hour = 13
    let date = Calendar(identifier: .gregorian).date(from: parts)!
    let suite = UserDefaults(suiteName: "schneetag.check.november")!
    suite.removePersistentDomain(forName: "schneetag.check.november")
    let season = AdventCalendar(defaults: suite).season(at: date)
    precondition(!season.inSeason && season.openedCount == 0, "Für diese Prüfung: November, nichts offen")
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
    precondition(plaques >= 22, "Im November müssen die Türschilder zu sehen sein: \(plaques) von 24")
    print("Türchen stehen auch vor dem Advent im Tal: \(plaques) von 24 Schildern sichtbar")
}
testDoorsShowBeforeAdvent()

func testDoorTestModeIsSeparate() {
    // Der Testmodus öffnet Türchen in einem eigenen Kalender; der echte bleibt leer.
    let real = UserDefaults(suiteName: "schneetag.check.real")!
    real.removePersistentDomain(forName: "schneetag.check.real")
    let trial = UserDefaults(suiteName: "schneetag.check.trial")!
    trial.removePersistentDomain(forName: "schneetag.check.trial")
    trial.set(Array(1..<7), forKey: "advent.opened.2026")
    var parts = DateComponents(); parts.year = 2026; parts.month = 12; parts.day = 7; parts.hour = 18
    let view = SnowView(frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
    view.density = 0; view.plowEnabled = false; view.workshopEnabled = false; view.christmas = true
    view.adventCalendar = AdventCalendar(defaults: trial)
    view.adventDate = Calendar(identifier: .gregorian).date(from: parts)
    view.syncWindows([], existingWindows: []); view.step(0); view.step(1 / 120)
    precondition(view.openAdventDoor(7) == .garland, "Im Test muss Türchen 7 aufgehen")
    precondition(view.openAdventDoor(8) == nil, "Nur das Türchen des Testtags darf aufgehen")
    precondition((trial.array(forKey: "advent.opened.2026") as? [Int])?.contains(7) == true, "Testkalender merkt sich 7")
    precondition(real.array(forKey: "advent.opened.2026") == nil, "Der echte Kalender bleibt unberührt")
    print("Türchen-Testmodus: eigener Kalender, nur das Türchen des Testtags, echter Kalender unberührt")
}
testDoorTestModeIsSeparate()

func testNoDoorBehindAHouse() {
    // Bis 1.87 lagen Türchen hinter näheren Häusern und wurden über deren
    // Wand gezeichnet (die 3 klebte auf dem Chalet mit der 17).
    for size in [CGSize(width: 1512, height: 982), CGSize(width: 1440, height: 900), CGSize(width: 2560, height: 1440),
                 CGSize(width: 1280, height: 800), CGSize(width: 1728, height: 1117),
                 CGSize(width: 1920, height: 1080), CGSize(width: 1366, height: 768)] {
        let layout = AdventLayout.make(in: CGRect(origin: .zero, size: size))
        precondition(Set(layout.doors.map(\.day)) == Set(1...24), "Alle 24 Türchen bei \(size)")
        let hidden = layout.doors.filter { AdventLayout.doorIsHidden($0, in: layout) }.map(\.day)
        precondition(hidden.isEmpty, "Verdeckte Türchen bei \(size): \(hidden)")
    }
    print("Kein Türchen hinter Häusern, Tannen, Dorfbaum oder Laternen, bei sieben Bildschirmgrößen")
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
    precondition(standing,"Für diese Prüfung muss er erst stehen")
    view.syncWindows([],existingWindows:[8])
    view.step(1/120)
    precondition(view.christmasScene.reindeerPhase == .leap,"Fällt die Kante weg, springt er sofort ab")
    var gone=false
    for _ in 0..<2400 {
        view.step(1/120)
        if !view.christmasScene.hasReindeer { gone=true;break }
    }
    precondition(gone,"Danach verlässt er den Bildschirm")
    print("Verschwindet die Fensterkante unter Rudolph, springt er ab und fliegt davon")
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
    let name="schneetag.test.advent"
    let calendar=AdventCalendar(defaults:adventSuite(name,[]))
    defer { UserDefaults().removePersistentDomain(forName:name) }
    var parts=DateComponents();parts.year=2026;parts.month=11;parts.day=20;parts.hour=12
    var gregorian=Calendar(identifier:.gregorian);gregorian.timeZone = .current
    let november=gregorian.date(from:parts)!
    precondition(calendar.season(at:november).today == nil,"Im November ist kein Türchen dran")
    precondition(calendar.open(1,at:november) == nil,"Vor Dezember lässt sich nichts öffnen")

    precondition(calendar.season(at:december(5)).today == 5)
    precondition(calendar.open(6,at:december(5)) == nil,"Ein späteres Türchen bleibt zu")
    precondition(calendar.open(4,at:december(5)) == nil,"Ein verpasstes Türchen bleibt ebenfalls zu")
    precondition(calendar.open(5,at:december(5)) == .smoke,"Am 5. gibt es den Rauch")
    precondition(calendar.open(5,at:december(5)) == nil,"Zweimal öffnen geht nicht")
    precondition(calendar.season(at:december(5)).isOpen(5))
    precondition(calendar.season(at:december(6)).isOpen(5),"Geöffnete Türchen bleiben offen")
    precondition(!calendar.season(at:december(6,2027)).isOpen(5),"Die nächste Saison fängt neu an")

    let full=AdventCalendar(defaults:adventSuite(name+".full",Array(1...24)))
    defer { UserDefaults().removePersistentDomain(forName:name+".full") }
    let season=full.season(at:december(24))
    precondition(season.warmth==1 && season.has(.rudolph) && season.has(.sleigh) && season.has(.aurora))
    precondition(AdventGift.forDay(6) == .rudolph && AdventGift.forDay(23) == .sleigh)
    for day in 1...24 { precondition(AdventGift.forDay(day) != .warmth, "Türchen \(day) bringt ein echtes Geschenk") }
    precondition(Set((1...24).map { AdventGift.forDay($0).title }).count == 24, "24 verschiedene Geschenke")
    print("Adventskalender: nur das Türchen von heute, einmal, bleibt offen, neue Saison fängt neu an")
}
testAdventCalendarRules()

func testAdventDoorsOnScreen() {
    let name="schneetag.test.doors"
    let view=SnowView(frame:CGRect(x:0,y:0,width:1000,height:700))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false
    view.adventCalendar=AdventCalendar(defaults:adventSuite(name,Array(1...13)))
    defer { UserDefaults().removePersistentDomain(forName:name) }
    view.adventDate=december(14)
    view.christmas=true
    view.syncWindows([],existingWindows:[])
    view.step(0)
    precondition(view.villageBounds==view.bounds,"Das Tal füllt den ganzen Hintergrund")
    var today:CGPoint?
    var others:[CGPoint]=[]
    for day in 1...24 {
        guard let point=view.adventDoorCenter(day) else { preconditionFailure("Türchen \(day) fehlt") }
        precondition(view.bounds.insetBy(dx:-1,dy:-1).contains(point),"Türchen \(day) liegt im Bild")
        for other in others {
            precondition(hypot(other.x-point.x,other.y-point.y)>6,"Türchen dürfen nicht übereinander liegen")
        }
        if day==14 { today=point } else { others.append(point) }
    }
    guard let today else { preconditionFailure("Türchen 14 fehlt") }
    precondition(view.adventDoor(at:today)==14,"Das Türchen von heute nimmt den Klick an")
    precondition(view.wantsInteraction(at:today))
    for point in others { precondition(view.adventDoor(at:point)==nil,"Andere Türchen bleiben durchlässig") }
    precondition(view.advent.openedCount==13)
    precondition(view.openAdventDoor(14) == .market)
    precondition(view.advent.openedCount==14 && view.advent.isOpen(14))
    precondition(view.adventDoor(at:today)==nil,"Ein geöffnetes Türchen nimmt keine Klicks mehr")
    precondition(view.openAdventDoor(14) == nil)
    // Außerhalb des Weihnachtsmodus bleibt das Dorf aus.
    view.christmas=false
    precondition(view.adventDoor(at:today)==nil)
    // Die Straßenbeleuchtung wächst mit jedem Türchen.
    let layout=AdventLayout.make(in:CGRect(x:0,y:0,width:1400,height:900))
    let lamps=layout.roads.reduce(0) { $0+$1.lamps.count }
    precondition(lamps>=20,"Es gibt genug Laternen für eine sichtbare Staffelung: \(lamps)")
    precondition(layout.litLamps(warmth:0)==0 && layout.litLamps(warmth:1)==lamps)
    var previous = -1
    for opened in 0...24 {
        let burning=layout.litLamps(warmth:CGFloat(opened)/24)
        precondition(burning>=previous,"Die Beleuchtung darf nie wieder ausgehen")
        previous=burning
    }
    for hour in [3, 8, 13, 17, 21] {
        var parts=DateComponents();parts.year=2026;parts.month=12;parts.day=14;parts.hour=hour
        var gregorian=Calendar(identifier:.gregorian);gregorian.timeZone = .current
        let sky=AdventSky.at(gregorian.date(from:parts)!)
        precondition(AdventVillage.backdrop(layout,season:AdventSeason(year:2026,today:14,opened:Set(1...13)),
                                            sky:sky,scale:1) != nil,"Der Hintergrund rendert um \(hour) Uhr")
    }
    print("24 Türchen im ganzen Tal, nur das heutige ist anklickbar, Beleuchtung wächst mit jedem Türchen")
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
        view.adventCalendar=AdventCalendar(defaults:adventSuite("schneetag.test.november",[]))
        view.adventDate=Calendar(identifier:.gregorian).date(from:parts)
        view.christmas=true
        view.syncWindows([(3,CGRect(x:120,y:40,width:620,height:150))],existingWindows:[3])
        view.step(0);view.inviteChristmasMoment()
        var saw=false
        for _ in 0..<9000 { view.step(1/120); saw = saw || view.christmasScene.hasSanta || view.christmasScene.hasReindeer }
        UserDefaults().removePersistentDomain(forName:"schneetag.test.november")
        precondition(!saw,"Im November fliegen weder Rudolph noch der Weihnachtsmann")
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
    let locked=scene("schneetag.test.locked",[1,2],2)
    defer { UserDefaults().removePersistentDomain(forName:"schneetag.test.locked") }
    var sawAny=false
    for _ in 0..<9000 {
        locked.step(1/120)
        sawAny = sawAny || locked.christmasScene.hasSanta || locked.christmasScene.hasReindeer
    }
    precondition(!sawAny,"Ohne die passenden Türchen bleibt der Besuch aus")

    // From St Nicholas' Day Rudolph comes, the sleigh not yet.
    let nikolaus=scene("schneetag.test.nikolaus",Array(1...6),6)
    defer { UserDefaults().removePersistentDomain(forName:"schneetag.test.nikolaus") }
    var deerEarly=false,sleighEarly=false
    for _ in 0..<9000 {
        nikolaus.step(1/120)
        deerEarly = deerEarly || nikolaus.christmasScene.hasReindeer
        sleighEarly = sleighEarly || nikolaus.christmasScene.hasSanta
    }
    precondition(deerEarly && !sleighEarly,"Ab Türchen 6 kommt Rudolph, der Weihnachtsmann erst ab Türchen 23")

    let open=scene("schneetag.test.unlocked",Array(1...23),23)
    defer { UserDefaults().removePersistentDomain(forName:"schneetag.test.unlocked") }
    var sawDeer=false,sawSleigh=false
    for _ in 0..<9000 {
        open.step(1/120)
        sawDeer = sawDeer || open.christmasScene.hasReindeer
        sawSleigh = sawSleigh || open.christmasScene.hasSanta
        if sawDeer && sawSleigh { break }
    }
    precondition(sawDeer && sawSleigh,"Mit Türchen 6 und 23 kommen Rudolph und der Schlitten")
    print("Rudolph und der Schlitten hängen an ihren Türchen; davor bleibt es im Dorf ruhig")
}
testAdventUnlocksVisitors()

func testDesktopWidgetsStayVisible() {
    // Über Widgets schneit es, das Tal bleibt dort aber ausgespart.
    // Liegt ein Fenster halb über einem Widget, bleibt das Fenster ganz frei.
    let view=SnowView(frame:CGRect(x:0,y:0,width:900,height:560))
    view.density=0;view.plowEnabled=false;view.workshopEnabled=false;view.christmas=true
    let widget=CGRect(x:20,y:340,width:180,height:180)
    let window=CGRect(x:120,y:300,width:300,height:160)
    view.syncWindows([(7,window)],widgets:[widget],existingWindows:[7])
    view.step(0)
    let inWidget=CGPoint(x:60,y:480), overlap=CGPoint(x:160,y:400)
    precondition(view.isVisible(inWidget),"Im Widget darf es schneien")
    precondition(!view.isVillageVisible(inWidget),"Im Widget wird kein Tal gemalt")
    precondition(!view.isVisible(overlap),"Wo das Fenster über dem Widget liegt, schneit es nicht")
    precondition(!view.isVillageVisible(overlap),"Und dort ist auch kein Tal")
    precondition(view.isVisible(CGPoint(x:700,y:400)) && view.isVillageVisible(CGPoint(x:700,y:400)),"Daneben beides")
    view.syncWindows([(7,window)],widgets:[],existingWindows:[7])
    precondition(view.isVillageVisible(inWidget),"Ohne Widget wird die Stelle wieder bemalt")
    print("Über Schreibtisch-Widgets schneit es, das Tal bleibt dort frei; Fenster darüber bleiben ganz frei")
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
    precondition(alpha(view,at:inStrip)>0.5,"Ohne Dock-Vorderfenster liegt der Bodenschnee wie bisher im Hauptfenster")
    let front=DockFrontView(frame:view.bounds)
    front.snow=view
    view.dockView=front
    precondition(alpha(view,at:inStrip)<0.01,"Im Dock-Streifen spart das Hauptfenster den Bodenschnee aus")
    precondition(alpha(front,at:inStrip)>0.5,"Das Fenster vor dem Dock zeigt dort den Bodenschnee")
    precondition(alpha(front,at:above)<0.01,"Oberhalb des Docks zeichnet das Vorderfenster nichts")
    view.dockView=nil
    print("Bodenschnee und Räumfahrzeuge liegen vor dem Dock: Hauptfenster spart den Dock-Streifen aus, das Vorderfenster füllt ihn")
}
testGroundSnowInFrontOfDock()

func testEveryDoorInSightAndOwnPresent() {
    let kinds = (1...24).map { AdventVillage.treasureKind($0) }
    precondition(Set(kinds).count == 24, "Jedes Türchen hat ein eigenes Motiv")
    precondition(kinds[23] == 2, "Der Stern gehört zum Heiligabend")
    for size in [CGSize(width: 1512, height: 982), CGSize(width: 1440, height: 900),
                 CGSize(width: 1920, height: 1080), CGSize(width: 2560, height: 1440)] {
        let layout = AdventLayout.make(in: CGRect(origin: .zero, size: size))
        let days = layout.chalets.compactMap { $0.day }
        precondition(Set(days).count == 24, "Alle 24 Türchen stehen im Dorf (\(size))")
        for house in layout.chalets {
            guard let day = house.day else { continue }
            let area = AdventLayout.doorArea(house)
            let blocked = layout.chalets.contains { $0.depth > house.depth && AdventLayout.covers($0, area) }
            precondition(!blocked, "Türchen \(day) liegt hinter einem näheren Haus oder dessen Dachschnee (\(size))")
        }
    }
    print("Alle 24 Türchen frei sichtbar, auch hinter Dachschnee, bei vier Bildschirmgrößen; 24 verschiedene Motive")
}
testEveryDoorInSightAndOwnPresent()


func testHorseSleighBelongsToDoorOne() {
    var closed = AdventSeason(); closed.year = 2026; closed.today = 1
    var opened = closed; opened.opened = [1]
    AdventVillage.roadShift = 0
    precondition(AdventGift.forDay(1) == .horseSleigh, "Türchen 1 bringt den Pferdeschlitten")
    for time in stride(from: CGFloat(0), to: 280, by: 3.5) {
        let road = AdventVillage.roadTraffic(season: closed, time: time)
        precondition(road.sleigh == nil, "Vor Türchen 1 fährt kein Pferdeschlitten (t=\(time))")
    }
    // The tractor has its own door, 2.
    precondition(AdventVillage.roadTraffic(season: closed, time: 100).tractor == nil)
    var withTractor = opened; withTractor.opened = [1, 2]
    precondition(AdventVillage.roadTraffic(season: withTractor, time: 100).tractor != nil)
    precondition(AdventVillage.roadTraffic(season: opened, time: 20).sleigh != nil, "Nach Türchen 1 fährt der Schlitten")
    // Opened while the road waits: the sleigh sets off at once from the edge.
    AdventVillage.cueHorseSleigh(at: 40)
    let now = AdventVillage.roadTraffic(season: opened, time: 40)
    precondition(now.sleigh != nil && now.sleigh!.t < 0.001, "Der Schlitten startet sofort nach dem Öffnen")
    // Opened while the tractor is out: it is not cut short.
    AdventVillage.roadShift = 0
    let before = AdventVillage.roadTraffic(season: withTractor, time: 100).tractor
    AdventVillage.cueHorseSleigh(at: 100)
    let after = AdventVillage.roadTraffic(season: withTractor, time: 100).tractor
    precondition(before != nil && after != nil && abs(before!.t - after!.t) < 0.0001, "Ein fahrender Traktor wird nicht abgeschnitten")
    AdventVillage.roadShift = 0
    print("Pferdeschlitten gehört zu Türchen 1: vorher nur der Traktor, beim Öffnen fährt der Schlitten sofort los")
}
testHorseSleighBelongsToDoorOne()

func testAllDoorsTestMode() {
    let suite = adventSuite("schneetag.test.alldoors", [])
    defer { UserDefaults().removePersistentDomain(forName: "schneetag.test.alldoors") }
    let normal = AdventCalendar(defaults: suite)
    precondition(!normal.season(at: december(5)).canOpen(9), "Normal ist nur das heutige Türchen offen")
    let all = AdventCalendar(defaults: suite, anyDay: true)
    for day in 1...24 { precondition(all.season(at: december(24)).canOpen(day), "Im Testmodus ist Türchen \(day) anklickbar") }
    precondition(all.open(9, at: december(24)) != nil && all.open(1, at: december(24)) == .horseSleigh)
    let state = all.season(at: december(24))
    precondition(state.isOpen(9) && state.isOpen(1) && !state.canOpen(9) && state.canOpen(10), "Geöffnete bleiben offen, der Rest bleibt anklickbar")
    // The view: a click on any door's rect opens it.
    let view = SnowView(frame: CGRect(x: 0, y: 0, width: 1512, height: 982))
    view.density = 0; view.plowEnabled = false; view.workshopEnabled = false
    view.adventCalendar = AdventCalendar(defaults: adventSuite("schneetag.test.alldoors2", []), anyDay: true)
    defer { UserDefaults().removePersistentDomain(forName: "schneetag.test.alldoors2") }
    view.adventDate = december(24)
    view.christmas = true
    view.syncWindows([], existingWindows: [])
    view.step(0)
    let layout = AdventLayout.make(in: view.bounds)
    for door in layout.doors { precondition(view.adventDoor(at: CGPoint(x: door.rect.midX, y: door.rect.midY)) == door.day, "Klick trifft Türchen \(door.day)") }
    print("Testmodus: alle 24 Türchen gleichzeitig anklickbar, echter Kalender unberührt")
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
        precondition(abs(Int(side) - Int(laptop)) <= 6, "Rand bei \(width)×\(height): \(side) statt etwa \(laptop)")
    }
    print("Vignette auf jedem Monitor gleich: Seitenrand bleibt hell wie am MacBook, auch bei Ultrawide")
}
testVignetteOnEveryMonitor()

func testSmokeStampLooksLikeGradient() {
    // Ein Rauchwölkchen als Stempel muss aussehen wie der frühere Verlauf:
    // gleiche Farbe, gleiche Ausdehnung, gleicher weicher Rand.
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
        precondition(worst <= 24 && mean < 1.0, "Rauchstempel r=\(radius): größte Abweichung \(worst), Mittel \(mean)")
    }
    print("Rauch aus Stempeln: sieht aus wie der frühere Verlauf, kostet aber keine Grafikleistung mehr")
}
testSmokeStampLooksLikeGradient()

func testEveryPointerHasAChristmasPicture() {
    let keeper = FestivePointerKeeper()
    let pairs = FestiveCursorArt.festivePairs()
    precondition(pairs.count >= 17, "Zu wenige Zeiger: \(pairs.count)")
    for pair in pairs {
        let festive = pair.festive()
        precondition(FestivePointerKeeper.mark(festive) != FestivePointerKeeper.mark(pair.plain),
                     "Weihnachtsbild muss sich vom Systemzeiger unterscheiden")
        precondition(festive.image.size.width > 4 && festive.image.size.height > 4)
    }
    // Der Textcursor behält seinen Ankerpunkt, damit die Einfügemarke an derselben Stelle sitzt.
    let beam = FestiveCursorArt.candyBeam(like: .iBeam, vertical: false)
    precondition(beam.hotSpot == NSCursor.iBeam.hotSpot && beam.image.size == NSCursor.iBeam.image.size)
    // Größe ändern: Mitte der Tannen ist der Ankerpunkt.
    let trees = FestiveCursorArt.firTrees([90, 270])
    precondition(trees.hotSpot == CGPoint(x: 14, y: 14))
    _ = keeper
    print("Alle \(pairs.count) Systemzeiger haben ein Weihnachtsbild: Zuckerstangen-Textcursor, Tannen zum Größe-Ändern")
}
testEveryPointerHasAChristmasPicture()
