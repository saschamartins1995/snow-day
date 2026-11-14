import AppKit
import CoreImage

/// What a door gives. Most days simply make the village a little warmer; the
/// marked days add something you can point at.
enum AdventGift: Equatable {
    case warmth
    case horseSleigh
    case tractor
    case sledgeChild
    case bells
    case starsInWindows
    case snowmanFamily
    case market
    case crib
    case balloon
    case choir
    case torchRun
    case bonfire
    case lanterns
    case smoke
    case garland
    case pond
    case tree
    case cableCar
    case star
    case flurry
    case rudolph
    case aurora
    case sleigh
    case finale

    /// Every door brings something that can be seen at once, day or night.
    static let schedule: [Int: AdventGift] = [
        1: .horseSleigh, 2: .tractor, 3: .lanterns, 4: .sledgeChild, 5: .smoke, 6: .rudolph,
        7: .garland, 8: .bells, 9: .pond, 10: .starsInWindows, 11: .tree, 12: .snowmanFamily,
        13: .cableCar, 14: .market, 15: .star, 16: .crib, 17: .flurry, 18: .balloon,
        19: .choir, 20: .torchRun, 21: .aurora, 22: .bonfire, 23: .sleigh, 24: .finale
    ]

    static func forDay(_ day: Int) -> AdventGift { schedule[day] ?? .warmth }

    var title: String {
        switch self {
        case .warmth: "Im Dorf wird es heller"
        case .horseSleigh: "Der Pferdeschlitten fährt durchs Dorf"
        case .tractor: "Der Bauer bringt die Christbäume"
        case .lanterns: "Alle Laternen im Dorf brennen"
        case .sledgeChild: "Die Kinder holen die Schlitten raus"
        case .smoke: "In allen Öfen brennt das Feuer"
        case .rudolph: "Rudolph fliegt übers Tal"
        case .garland: "Lichterketten an allen Laternen"
        case .bells: "Die Kirchenglocken läuten"
        case .pond: "Der Dorfteich ist zugefroren"
        case .starsInWindows: "Sterne in allen Fenstern"
        case .tree: "Der Dorfbaum leuchtet"
        case .snowmanFamily: "Eine Schneemann-Familie im Feld"
        case .cableCar: "Die Gondeln sind geschmückt"
        case .market: "Der Glühweinstand hat geöffnet"
        case .star: "Ein Stern über der Kirche"
        case .crib: "Die Krippe vor der Kirche"
        case .flurry: "Ein Schneeschauer zieht durch"
        case .balloon: "Ein Heißluftballon über dem Tal"
        case .choir: "Der Kinderchor singt"
        case .torchRun: "Fackelzug auf der Piste"
        case .aurora: "Polarlicht über dem Tal, sobald es dunkel wird"
        case .bonfire: "Ein Lagerfeuer im Feld"
        case .sleigh: "Der Weihnachtsmann kommt vorbei"
        case .finale: "Das ganze Dorf im Licht"
        }
    }
}

/// What today allows and what has already been opened.
struct AdventSeason: Equatable {
    var year: Int = 0
    /// 1…24 during Advent, otherwise nil.
    var today: Int?
    var opened: Set<Int> = []
    /// Testing: every door that is still shut may be opened, whatever the date.
    var anyDay = false

    var openedCount: Int { opened.count }
    /// 0…1, how far the village has come along.
    var warmth: CGFloat { min(1, CGFloat(opened.count) / 24) }
    var inSeason: Bool { today != nil }

    func isOpen(_ day: Int) -> Bool { opened.contains(day) }
    func canOpen(_ day: Int) -> Bool { (anyDay || today == day) && !opened.contains(day) }

    func has(_ gift: AdventGift) -> Bool {
        if opened.contains(24) { return true }
        return opened.contains { AdventGift.forDay($0) == gift }
    }

    func status(for day: Int) -> String {
        if opened.contains(day) { return AdventGift.forDay(day).title }
        if today == day || anyDay { return "Heute öffnen" }
        return "Öffnet am \(day). Dezember"
    }
}

/// Reads and writes which doors are open. One set per year, so a new December
/// starts over on its own.
struct AdventCalendar {
    var defaults: UserDefaults = .standard
    /// Testing: all doors can be clicked at once.
    var anyDay = false

    func season(at date: Date = Date(), in timeZone: TimeZone = .current) -> AdventSeason {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let today = parts.month == 12 ? parts.day.flatMap { (1...24).contains($0) ? $0 : nil } : nil
        let opened = Set((defaults.array(forKey: "advent.opened.\(year)") as? [Int] ?? [])
            .filter { (1...24).contains($0) })
        return AdventSeason(year: year, today: today, opened: opened, anyDay: anyDay)
    }

    @discardableResult
    func open(_ day: Int, at date: Date = Date(), in timeZone: TimeZone = .current) -> AdventGift? {
        let state = season(at: date, in: timeZone)
        guard state.canOpen(day) else { return nil }
        defaults.set(state.opened.union([day]).sorted(), forKey: "advent.opened.\(state.year)")
        return AdventGift.forDay(day)
    }

    func clear(at date: Date = Date(), in timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let year = calendar.dateComponents([.year], from: date).year ?? 0
        defaults.removeObject(forKey: "advent.opened.\(year)")
    }
}


/// The sky follows the clock on this Mac: sun by day, moon by night and the
/// warm band of alpenglow on the peaks in between.
struct AdventSky: Equatable {
    var zenith: UInt32 = 0x060b1c
    var horizon: UInt32 = 0x16213c
    var alpenglow: UInt32 = 0xff9e7a
    var alpenglowStrength: CGFloat = 0
    var daylight: CGFloat = 0
    var starlight: CGFloat = 1
    var lampStrength: CGFloat = 1
    var sunElevation: CGFloat = -1
    var sunAzimuth: CGFloat = 0
    var moonAzimuth: CGFloat = 0
    /// Changes once a minute, which is when the backdrop is worth redrawing.
    var stamp: Int = 0

    private static let sunrise: CGFloat = 7.0
    private static let sunset: CGFloat = 17.5

    static func at(_ date: Date, in timeZone: TimeZone = .current) -> AdventSky {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        let hour = CGFloat(minute) / 60
        let day = sunset - sunrise
        var sky = AdventSky()
        sky.stamp = minute
        if hour >= sunrise, hour <= sunset {
            sky.sunElevation = sin(.pi * (hour - sunrise) / day)
            sky.sunAzimuth = (hour - sunrise) / day
        } else {
            let night = hour < sunrise ? hour + 24 - sunset : hour - sunset
            sky.sunElevation = -sin(.pi * night / (24 - day))
            sky.moonAzimuth = night / (24 - day)
        }
        sky.daylight = min(1, max(0, (sky.sunElevation + 0.10) / 0.45))
        sky.starlight = min(1, max(0, (0.04 - sky.sunElevation) / 0.22))
        sky.alpenglowStrength = max(0, 1 - abs(sky.sunElevation) / 0.26)
        sky.lampStrength = 1 - sky.daylight * 0.92
        // Night, then dawn or dusk, then full day.
        let night = (zenith: UInt32(0x060b1c), horizon: UInt32(0x16213c))
        let day2 = (zenith: UInt32(0x2b6ab3), horizon: UInt32(0xc5dcef))
        sky.zenith = AdventVillage.blend(night.zenith, day2.zenith, sky.daylight)
        sky.horizon = AdventVillage.blend(night.horizon, day2.horizon, sky.daylight)
        if sky.alpenglowStrength > 0 {
            sky.horizon = AdventVillage.blend(sky.horizon, 0xe8926a, sky.alpenglowStrength * 0.8)
            sky.zenith = AdventVillage.blend(sky.zenith, 0x3b3566, sky.alpenglowStrength * 0.5)
        }
        sky.alpenglow = sky.daylight > 0.7 ? 0xffe3bd : 0xff9d78
        return sky
    }

    /// The light falling on the mountains: full white by day, a cool blue
    /// moonlight at night, warm-tinted while the sun is low.
    var mountainLight: UInt32 {
        let night: UInt32 = 0x6a7ba3
        var light = AdventVillage.blend(night, 0xffffff, daylight)
        if alpenglowStrength > 0 {
            light = AdventVillage.blend(light, 0xf3dccd, alpenglowStrength * 0.35 * daylight)
        }
        return light
    }

    /// The valley is near, so it keeps a little more of its own colour than
    /// the mountains: blue under the moon, never paper white.
    var valleyLight: UInt32 { AdventVillage.blend(mountainLight, 0xffffff, 0.30) }

    func sunPoint(in bounds: CGRect) -> CGPoint? {
        guard sunElevation > -0.05 else { return nil }
        return CGPoint(x: bounds.minX + bounds.width * (0.12 + 0.76 * sunAzimuth),
                       y: bounds.minY + bounds.height * (0.40 + 0.52 * max(0, sunElevation)))
    }

    func moonPoint(in bounds: CGRect) -> CGPoint? {
        guard sunElevation < 0.06 else { return nil }
        let rise = sin(.pi * min(1, max(0, moonAzimuth)))
        return CGPoint(x: bounds.minX + bounds.width * (0.14 + 0.72 * moonAzimuth),
                       y: bounds.minY + bounds.height * (0.46 + 0.46 * rise))
    }
}

// MARK: - Layout

struct AdventDoor {
    let day: Int
    let rect: CGRect
    /// Which road the house stands on: 0 far … 2 near.
    let depth: Int
}

/// A deterministic plan of the whole valley. Drawing and doors both read from
/// it, so a door can never end up next to its house.
struct AdventLayout: Equatable {
    struct Ridge: Equatable {
        var points: [CGPoint]
        var fill: UInt32
        var snowLine: CGFloat
    }
    struct Road: Equatable {
        var points: [CGPoint]
        var width: CGFloat
        var depth: Int
        var lamps: [CGPoint]
    }
    struct Chalet: Equatable {
        var base: CGRect
        var roof: CGFloat
        var depth: Int
        var day: Int?
        var kind: Kind
        /// Sideways offset of the front door from the middle of the house,
        /// used when something in front would otherwise hide it.
        var doorShift: CGFloat = 0
        enum Kind { case chalet, church, barn }
    }

    var bounds: CGRect = .zero
    var ridges: [Ridge] = []
    var matterhorn: [CGPoint] = []
    /// The skyline of every mountain together: the aurora is clipped above it.
    var horizon: [CGPoint] = []
    /// Ski runs winding down the middle range, as sampled polylines.
    var pistes: [[CGPoint]] = []
    var matterhornSummit = 0
    /// The Hörnli ridge from the summit down to the foot of the horn.
    var matterhornRidge: [CGPoint] = []
    var matterhornShoulder: [CGPoint] = []
    /// Summit head, north-face shadow, snowfield and glacier bands.
    var matterhornPatches: [[CGPoint]] = []
    var skyline: [Ridge] = []
    var glacier: CGRect = .zero
    var treeLine: [(x: CGFloat, y: CGFloat, size: CGFloat, ridge: Int)] = []
    var roads: [Road] = []
    var chalets: [Chalet] = []
    var doors: [AdventDoor] = []
    var firs: [(x: CGFloat, y: CGFloat, size: CGFloat, depth: Int)] = []
    var lake: CGRect = .zero
    var tree: CGPoint = .zero
    var treeSize: CGFloat = 0
    var moon: CGPoint = .zero
    var moonRadius: CGFloat = 0
    var stars: [(point: CGPoint, size: CGFloat)] = []
    var clouds: [(center: CGPoint, width: CGFloat, height: CGFloat, seed: Int)] = []
    var sparkles: [(point: CGPoint, size: CGFloat)] = []

    static func == (a: AdventLayout, b: AdventLayout) -> Bool { a.bounds == b.bounds }

    /// Midpoint displacement: a straight ridge line becomes a broken one. Two
    /// rounds are enough to stop a mountain looking like cut paper.
    private static func roughen(_ points: [CGPoint], amplitude: CGFloat, levels: Int, salt: Int) -> [CGPoint] {
        var result = points
        var scale = amplitude
        var seed = salt
        for _ in 0..<levels {
            var next: [CGPoint] = [result[0]]
            for index in 1..<result.count {
                let a = result[index - 1], b = result[index]
                seed += 1
                let mid = CGPoint(x: (a.x + b.x) / 2,
                                  y: (a.y + b.y) / 2 + (hash(index, seed) - 0.5) * scale)
                next.append(mid)
                next.append(b)
            }
            result = next
            scale *= 0.52
        }
        return result
    }

    /// Deterministic 0…1 noise for the painters, so details stay put between frames.
    static func noise(_ n: Int, _ salt: Int) -> CGFloat { hash(n, salt) }

    private static func hash(_ n: Int, _ salt: Int = 0) -> CGFloat {
        var x = UInt64(bitPattern: Int64(n &* 374761393 &+ salt &* 668265263 &+ 1442695040888963407))
        x ^= x >> 33; x = x &* 0xff51afd7ed558ccd; x ^= x >> 29
        return CGFloat(x % 10007) / 10007
    }

    /// Doors are scattered, not numbered left to right: finding today's door is
    /// part of it, and the glow makes it findable anyway.
    private static let dayOrder = [7, 19, 2, 14, 23, 5, 11, 1, 16, 9, 21, 4,
                                   13, 24, 8, 18, 3, 12, 20, 6, 15, 10, 22, 17]

/// Where a house's door and its number plaque sit.
static func doorArea(_ chalet: Chalet) -> CGRect {
        if chalet.kind == .church {
            return CGRect(x: chalet.base.midX - chalet.base.width * 0.2, y: chalet.base.minY,
                          width: chalet.base.width * 0.4, height: chalet.base.height * 0.62)
        }
        let size = CGSize(width: min(22, chalet.base.width * 0.30), height: min(26, chalet.base.height * 0.58))
        let plaque = size.width * 0.1 + max(10.5, size.height * 0.45)
        return CGRect(x: chalet.base.midX + chalet.doorShift - size.width * 0.55, y: chalet.base.minY,
                      width: size.width * 1.1, height: chalet.base.height * 0.06 + size.height + plaque)
    }
/// Whether a house's walls or roof stand in front of the given area.
static func covers(_ house: Chalet, _ area: CGRect) -> Bool {
        let eaves = house.base.width * (house.kind == .barn ? 0.22 : 0.36)
        if house.base.insetBy(dx: -house.base.width * 0.05, dy: 0).intersects(area) { return true }
        // The roof triangle with the cushion of snow lying on it, sampled on
        // a grid over the door area. The snow is up to a sixth of the house
        // wide, deepest at the ridge: without it a door just above a near
        // ridge counted as free and vanished behind the snow.
        let snow = house.kind == .church ? 0 : house.base.width * 0.17
        let left = CGPoint(x: house.base.minX - eaves - snow * 0.6, y: house.base.maxY - house.base.height * 0.05)
        let right = CGPoint(x: house.base.maxX + eaves + snow * 0.6, y: left.y)
        let top = house.base.maxY + house.roof * (house.kind == .church ? 1.5 : 1) + snow
        for i in 0...4 { for j in 0...4 {
            let point = CGPoint(x: area.minX + area.width * CGFloat(i) / 4, y: area.minY + area.height * CGFloat(j) / 4)
            guard point.y >= left.y, point.y <= top else { continue }
            let t = (point.y - left.y) / max(1, top - left.y)
            let half = (right.x - left.x) / 2 * (1 - t)
            if abs(point.x - house.base.midX) <= half { return true }
        } }
        return false
    }
    /// The big firs at the screen edges: x and y as fractions, and size in units.
    static let frameTreeSpots: [(CGFloat, CGFloat, CGFloat)] = [
        (-0.010, 0.015, 4.6), (0.045, 0.004, 3.4), (0.022, 0.060, 2.6),
        (1.008, 0.012, 4.9), (0.958, 0.002, 3.6), (0.982, 0.058, 2.8)
    ]

    /// Whether one of those firs stands in front of the given area: each is
    /// a triangle narrowing from its lowest boughs to the tip.
    static func frameTreesCover(_ area: CGRect, in bounds: CGRect) -> Bool {
        let unit = min(bounds.height * 0.052, bounds.width / 26)
        // The village tree on the near road (0.42, 0.135, 2.6 units) counts too.
        for (fx, fy, scale) in frameTreeSpots + [(0.42, 0.135, 2.6)] {
            let size = unit * scale
            let foot = CGPoint(x: bounds.minX + bounds.width * fx, y: bounds.minY + bounds.height * fy)
            for i in 0...4 { for j in 0...4 {
                let point = CGPoint(x: area.minX + area.width * CGFloat(i) / 4, y: area.minY + area.height * CGFloat(j) / 4)
                let t = (point.y - foot.y - size * 0.1) / (size * 0.92)
                guard t >= 0, t <= 1 else { continue }
                if abs(point.x - foot.x) <= size * 0.42 * (1 - t * 0.85) { return true }
            } }
        }
        return false
    }

    /// Where a near-road lantern stands, post and head.
    static func lanternArea(_ lamp: CGPoint, road: Road) -> CGRect {
        CGRect(x: lamp.x - road.width * 0.42, y: lamp.y, width: road.width * 0.84, height: road.width * 2.8)
    }

    /// Whether any nearer house hides this door.
    static func doorIsHidden(_ door: AdventDoor, in layout: AdventLayout) -> Bool {
        guard let owner = layout.chalets.first(where: { $0.day == door.day }) else { return false }
        let area = doorArea(owner)
        if layout.chalets.contains(where: { $0.depth > owner.depth && covers($0, area) }) { return true }
        if frameTreesCover(area, in: layout.bounds) { return true }
        // Lanterns of nearer roads stand in front too.
        // Lanterns stand on the front edge of their road, so they are in
        // front of the houses of their own road as well.
        for (index, road) in layout.roads.enumerated() where index >= owner.depth {
            if road.lamps.contains(where: { lanternArea($0, road: road).intersects(area) }) { return true }
        }
        return false
    }

    static func make(in bounds: CGRect) -> AdventLayout {
        var layout = AdventLayout(bounds: bounds)
        let w = bounds.width, h = bounds.height
        let unit = min(h * 0.052, w / 26)

        // Sky furniture.
        layout.moon = CGPoint(x: bounds.minX + w * 0.80, y: bounds.minY + h * 0.84)
        layout.moonRadius = min(w, h) * 0.035
        for index in 0..<90 {
            let x = bounds.minX + w * hash(index, 1)
            let y = bounds.minY + h * (0.46 + hash(index, 2) * 0.53)
            guard hypot(x - layout.moon.x, y - layout.moon.y) > layout.moonRadius * 2.2 else { continue }
            layout.stars.append((CGPoint(x: x, y: y), 0.8 + hash(index, 3) * 1.5))
        }

        // The Matterhorn exactly as it stands over Zermatt, traced point by
        // point from a photograph taken in the village and kept in the same
        // proportions on every screen. The left skyline is the Hörnli side:
        // a long slope, a steep step, the flat shoulder, then the dark summit
        // head rising almost sheer. From the top the crooked tip runs off to
        // the right, breaks away steeply above the deep shadow of the north
        // face and ends in the white snowfield and the lower right shoulder.
        let hornUnit = h * 0.34
        let hornSummit = CGPoint(x: bounds.minX + w * 0.30, y: bounds.minY + h * 0.94)
        func hornPoint(_ p: (CGFloat, CGFloat)) -> CGPoint {
            CGPoint(x: hornSummit.x + hornUnit * p.0, y: hornSummit.y - hornUnit + hornUnit * p.1)
        }
        let horn: [(CGFloat, CGFloat)] = [
            (-1.150, -0.450), (-0.950, -0.250), (-0.810, -0.103), (-0.776, -0.041), (-0.741, -0.021),
            (-0.707, 0.003), (-0.672, 0.028), (-0.638, 0.048), (-0.603, 0.079), (-0.569, 0.117),
            (-0.534, 0.141), (-0.500, 0.162), (-0.466, 0.190), (-0.431, 0.214), (-0.397, 0.245),
            (-0.362, 0.293), (-0.328, 0.410), (-0.293, 0.600), (-0.259, 0.624), (-0.224, 0.621),
            (-0.190, 0.679), (-0.155, 0.686), (-0.121, 0.841), (-0.086, 0.914), (-0.052, 0.959),
            (-0.017, 0.997), (0.000, 1.000), (0.017, 0.997), (0.052, 0.990), (0.086, 0.976),
            (0.121, 0.969), (0.155, 0.945), (0.190, 0.921), (0.224, 0.886), (0.259, 0.855),
            (0.293, 0.824), (0.328, 0.793), (0.362, 0.772), (0.397, 0.741), (0.431, 0.662),
            (0.466, 0.600), (0.500, 0.534), (0.534, 0.455), (0.569, 0.397), (0.603, 0.345),
            (0.638, 0.303), (0.672, 0.262), (0.707, 0.224), (0.776, 0.145), (0.845, 0.128),
            (0.914, 0.131), (0.983, 0.083), (1.052, 0.028), (1.121, -0.007), (1.190, -0.041),
            (1.300, -0.200), (1.450, -0.450)
        ]
        // The Hörnli spur from the summit down through the middle of the horn.
        let ridge: [(CGFloat, CGFloat)] = [
            (0.000, 1.000), (0.084, 0.852), (0.148, 0.691), (0.175, 0.521), (0.159, 0.360),
            (0.116, 0.200), (0.041, 0.013), (-0.055, -0.147), (-0.162, -0.280), (-0.300, -0.450)
        ]
        let shoulderLine: [(CGFloat, CGFloat)] = [(-0.293, 0.600), (-0.259, 0.624), (-0.224, 0.621), (-0.190, 0.679), (-0.155, 0.686)]
        // Light and shade as in the photograph: the dark summit head, the deep
        // shadow under the north face, its snowfield, the glacier bands.
        let patches: [[(CGFloat, CGFloat)]] = [
            // The summit head: the whole block above the shoulder on the left,
            // bare warm rock up to the line where the snowy right flank begins.
            [(-0.030, 1.020), (0.012, 0.992), (0.066, 0.925), (0.120, 0.850), (0.112, 0.782), (-0.010, 0.735),
             (-0.127, 0.690), (-0.185, 0.690), (-0.160, 0.840), (-0.120, 0.920), (-0.080, 0.975)],
            [(0.468, 0.670), (0.522, 0.521), (0.554, 0.392), (0.639, 0.307), (0.719, 0.254), (0.682, 0.173), (0.575, 0.067),
             (0.506, -0.094), (0.468, -0.227), (0.426, -0.094), (0.399, 0.120), (0.388, 0.334), (0.415, 0.521)],
            [(0.639, 0.296), (0.799, 0.200), (0.933, 0.136), (1.040, 0.083), (1.173, -0.077), (1.120, -0.200), (0.906, -0.307),
             (0.639, -0.387), (0.479, -0.344), (0.506, -0.147), (0.586, 0.040), (0.693, 0.173)],
            [(-0.188, -0.216), (0.105, -0.280), (0.426, -0.344), (0.639, -0.387), (0.612, -0.494), (0.319, -0.451), (0.052, -0.377), (-0.162, -0.291)],
            [(-0.616, -0.227), (-0.375, -0.206), (-0.242, -0.270), (-0.482, -0.312)],
            // The shaded gully along the right side of the Hörnli rib.
            [(0.150, 0.690), (0.205, 0.660), (0.265, 0.560), (0.305, 0.410), (0.300, 0.220), (0.250, 0.100),
             (0.120, 0.120), (0.160, 0.360), (0.178, 0.520)],
            // The snow plastered on the sunlit right flank of the summit.
            [(0.02, 0.985), (0.159, 0.937), (0.276, 0.857), (0.399, 0.734), (0.468, 0.654), (0.436, 0.531), (0.351, 0.521), (0.255, 0.627), (0.169, 0.745), (0.095, 0.862)]
        ]
        layout.matterhorn = roughen(horn.map(hornPoint), amplitude: hornUnit * 0.005, levels: 2, salt: 311)
        layout.matterhornSummit = layout.matterhorn.enumerated().max { $0.element.y < $1.element.y }?.offset ?? 0
        layout.matterhornRidge = ridge.map(hornPoint)
        layout.matterhornRidge[0] = layout.matterhorn[layout.matterhornSummit]
        layout.matterhornShoulder = shoulderLine.map(hornPoint)
        layout.matterhornPatches = patches.map { $0.map(hornPoint) }
        layout.glacier = CGRect(x: hornSummit.x - hornUnit * 0.3, y: hornSummit.y - hornUnit * 1.25,
                                width: hornUnit * 1.0, height: h * 0.05)

        // The rest of the skyline around it, each massif with its own character.
        func massif(_ profile: [(CGFloat, CGFloat)], left: CGFloat, width: CGFloat,
                    base: CGFloat, height: CGFloat, fill: UInt32) -> Ridge {
            var points = profile.map {
                CGPoint(x: bounds.minX + w * (left + width * $0.0), y: bounds.minY + h * (base + height * $0.1))
            }
            points.insert(CGPoint(x: bounds.minX, y: bounds.minY + h * base), at: 0)
            points.append(CGPoint(x: bounds.maxX, y: bounds.minY + h * base))
            return Ridge(points: roughen(points, amplitude: h * height * 0.05, levels: 2, salt: 420),
                         fill: fill, snowLine: bounds.minY + h * (base + height * 0.18))
        }
        // Dent Blanche: a sharp tooth on the left.
        layout.skyline.append(massif([(0.00, 0.00), (0.22, 0.46), (0.40, 0.78), (0.50, 1.00),
                                      (0.62, 0.74), (0.78, 0.44), (1.00, 0.00)],
                                     left: -0.02, width: 0.20, base: 0.54, height: 0.23, fill: 0x4e6881))
        // Breithorn: a broad glaciated dome with a long flat summit ridge.
        layout.skyline.append(massif([(0.00, 0.00), (0.16, 0.42), (0.30, 0.74), (0.44, 0.92),
                                      (0.58, 0.97), (0.72, 0.88), (0.86, 0.58), (1.00, 0.00)],
                                     left: 0.52, width: 0.30, base: 0.58, height: 0.19, fill: 0x51708b))
        // Monte Rosa: a wide massif with several summits.
        layout.skyline.append(massif([(0.00, 0.00), (0.14, 0.40), (0.26, 0.66), (0.36, 0.56),
                                      (0.48, 0.84), (0.58, 0.70), (0.70, 0.90), (0.82, 0.60),
                                      (1.00, 0.00)],
                                     left: 0.76, width: 0.30, base: 0.57, height: 0.22, fill: 0x56758f))

        // Mountains, far to near. Distant ranges are hazier and sit higher.
        let ranges: [(base: CGFloat, amp: CGFloat, peaks: Int, fill: UInt32, snow: CGFloat)] = [
            // In winter the snow reaches the valley: only forest and steep rock
            // stay dark, so the snow line sits at the foot of each range.
            (0.60, 0.13, 7, 0x5a7390, 0.45),
            (0.49, 0.14, 6, 0x47607e, 0.36),
            (0.38, 0.12, 5, 0x374d68, 0.28)
        ]
        for (index, range) in ranges.enumerated() {
            var points: [CGPoint] = [CGPoint(x: bounds.minX, y: bounds.minY + h * range.base * 0.82)]
            for peak in 0...range.peaks {
                let t = CGFloat(peak) / CGFloat(range.peaks)
                let jitter = (hash(peak, 10 + index) - 0.5) * 0.6 / CGFloat(range.peaks)
                let sharpness = 0.55 + hash(peak, 20 + index) * 0.45
                points.append(CGPoint(x: bounds.minX + w * min(1, max(0, t + jitter)),
                                      y: bounds.minY + h * (range.base + range.amp * sharpness)))
                if peak < range.peaks {
                    let valley = 0.46 + hash(peak, 30 + index) * 0.34
                    points.append(CGPoint(x: bounds.minX + w * (t + 0.5 / CGFloat(range.peaks)),
                                          y: bounds.minY + h * (range.base + range.amp * valley * 0.5)))
                }
            }
            points.append(CGPoint(x: bounds.maxX, y: bounds.minY + h * range.base * 0.78))
            let broken = roughen(points, amplitude: h * range.amp * 0.34, levels: 2, salt: 70 + index * 13)
            layout.ridges.append(Ridge(points: broken, fill: range.fill,
                                       snowLine: bounds.minY + h * range.snow))
        }

        // The range right in front of the Matterhorn frames it as in the
        // photograph: a rocky ridge falling from the left, a dip where the
        // foot of the horn shows, and a wooded hill rising to the right.
        if !layout.ridges.isEmpty {
            // Positions as fractions of the screen, kept just above the next
            // range so the whole horn shows down to its foot.
            let frame: [(CGFloat, CGFloat)] = [
                (0.030, 0.652), (0.060, 0.700), (0.090, 0.690), (0.120, 0.675), (0.150, 0.655), (0.180, 0.640),
                (0.210, 0.626), (0.240, 0.616), (0.270, 0.610), (0.300, 0.607), (0.330, 0.607), (0.360, 0.608),
                (0.390, 0.611), (0.420, 0.613), (0.450, 0.614), (0.480, 0.617), (0.505, 0.626), (0.525, 0.632),
                (0.550, 0.631), (0.575, 0.628), (0.600, 0.629), (0.620, 0.630)
            ]
            let custom = roughen(frame.map { CGPoint(x: bounds.minX + w * $0.0, y: bounds.minY + h * $0.1) },
                                 amplitude: h * 0.004, levels: 2, salt: 77)
            let left = custom.first!.x, right = custom.last!.x
            layout.ridges[0].points = layout.ridges[0].points.filter { $0.x < left } + custom
                + layout.ridges[0].points.filter { $0.x > right }
        }

        // Three roads across the valley, far to near.
        let roadPlan: [(y: CGFloat, wave: CGFloat, width: CGFloat, lamps: Int)] = [
            (0.345, 0.018, unit * 0.30, 7),
            (0.225, 0.030, unit * 0.52, 8),
            (0.135, 0.040, unit * 0.86, 9)
        ]
        for (depth, plan) in roadPlan.enumerated() {
            var points: [CGPoint] = []
            let samples = 24
            for step in 0...samples {
                let t = CGFloat(step) / CGFloat(samples)
                let x = bounds.minX + w * t
                let y = bounds.minY + h * (plan.y + plan.wave * sin(t * 5.4 + CGFloat(depth) * 1.7))
                points.append(CGPoint(x: x, y: y))
            }
            var lamps: [CGPoint] = []
            for index in 0..<plan.lamps {
                let t = (CGFloat(index) + 0.5) / CGFloat(plan.lamps)
                let sample = points[min(points.count - 1, Int(t * CGFloat(samples)))]
                lamps.append(CGPoint(x: sample.x, y: sample.y - plan.width * 0.55))
            }
            layout.roads.append(Road(points: points, width: plan.width, depth: depth, lamps: lamps))
        }

        // Houses line the roads: a few far ones, more near ones.
        var day = 0
        // One house more on the far road than there are doors: a spare whose
        // doorway nothing ever hides, in case a nearer house covers a door.
        let perRoad = [11, 9, 7]
        for (depth, count) in perRoad.enumerated() {
            let road = layout.roads[depth]
            let scale = [0.52, 0.88, 1.75][depth]
            for index in 0..<count {
                let t = (CGFloat(index) + 0.22 + hash(index, 40 + depth) * 0.56) / CGFloat(count)
                let sample = road.points[min(road.points.count - 1, Int(t * 24))]
                let size = unit * scale * (0.82 + hash(index, 50 + depth) * 0.42)
                let base = CGRect(x: sample.x - size * 0.62, y: sample.y + road.width * 0.35,
                                  width: size * 1.24, height: size * 0.78)
                day += 1
                // The 24th door belongs to the church, not to a house.
                let assigned = day <= 24 && dayOrder[day - 1] != 24 ? dayOrder[day - 1] : nil
                layout.chalets.append(Chalet(base: base, roof: size * 0.62, depth: depth,
                                             day: assigned, kind: .chalet))
            }
        }
        // Numbers go to the near and middle roads first; the spare houses
        // without a door end up on the far road, where nothing stands in front
        // of them, so a door that gets hidden later can move there.
        do {
            let order = layout.chalets.indices.sorted {
                layout.chalets[$0].depth != layout.chalets[$1].depth
                    ? layout.chalets[$0].depth > layout.chalets[$1].depth : $0 < $1
            }
            var next = 0
            for index in order {
                while next < dayOrder.count && dayOrder[next] == 24 { next += 1 }
                layout.chalets[index].day = next < dayOrder.count ? dayOrder[next] : nil
                if next < dayOrder.count { next += 1 }
            }
        }
        // A church on the middle road and a barn out on the far one.
        if let road = layout.roads.dropFirst().first {
            let sample = road.points[4]
            let size = unit * 1.15
            layout.chalets.append(Chalet(base: CGRect(x: sample.x - size * 0.5, y: sample.y + road.width * 0.35,
                                                      width: size, height: size * 1.25),
                                         roof: size * 1.0, depth: 1, day: 24, kind: .church))
        }
        // Granaries on stilts between the houses, as in any Valais village.
        for (depth, sampleIndex, scale) in [(0, 19, 0.75), (1, 14, 1.0), (2, 22, 1.45)] {
            let road = layout.roads[depth]
            let sample = road.points[sampleIndex]
            let size = unit * CGFloat(scale)
            layout.chalets.append(Chalet(base: CGRect(x: sample.x - size * 0.45, y: sample.y + road.width * 0.3,
                                                      width: size * 0.9, height: size * 0.95),
                                         roof: size * 0.42, depth: depth, day: nil, kind: .barn))
        }

        // Häuser an derselben Straße dürfen sich nicht überlappen.
        for depth in 0..<3 {
            var indices = layout.chalets.indices.filter { layout.chalets[$0].depth == depth }
            indices.sort { layout.chalets[$0].base.minX < layout.chalets[$1].base.minX }
            for step in 1..<max(1, indices.count) {
                let previous = layout.chalets[indices[step - 1]].base
                var current = layout.chalets[indices[step]].base
                let gap = current.minX - previous.maxX
                // The eaves stand well clear of the walls, so houses need room.
                let wanted = current.width * 0.62
                if gap < wanted {
                    current.origin.x += wanted - gap
                    layout.chalets[indices[step]].base = current
                }
            }
        }
        // Keep every house inside the picture, eaves included.
        for index in layout.chalets.indices {
            var rect = layout.chalets[index].base
            let eaves = rect.width * 0.36
            if rect.minX - eaves < bounds.minX { rect.origin.x = bounds.minX + eaves }
            if rect.maxX + eaves > bounds.maxX { rect.origin.x = bounds.maxX - eaves - rect.width }
            layout.chalets[index].base = rect
        }
        // Pulling the outermost houses back inside can push them into a
        // neighbour again. A granary that ends up in a house is left out.
        layout.chalets = layout.chalets.enumerated().filter { index, chalet in
            guard chalet.kind == .barn else { return true }
            let mine = chalet.base.insetBy(dx: -chalet.base.width * 0.25, dy: 0)
            return !layout.chalets.enumerated().contains { other, house in
                other != index && house.depth == chalet.depth && house.kind != .barn
                    && house.base.insetBy(dx: -house.base.width * 0.36, dy: 0).intersects(mine)
            }
        }.map { $0.element }
        // A door must never sit behind a nearer house: it would be drawn over
        // that house's wall. Houses whose door is hidden slide sideways to
        // the nearest free spot along their road.
        func hidden(_ index: Int) -> Bool {
            let chalet = layout.chalets[index]
            let area = doorArea(chalet)
            return layout.chalets.contains { $0.depth > chalet.depth && covers($0, area) }
                || AdventLayout.frameTreesCover(area, in: bounds)
        }
        func clearOfNeighbours(_ index: Int, _ base: CGRect) -> Bool {
            let eaves = base.width * 0.36
            guard base.minX - eaves >= bounds.minX, base.maxX + eaves <= bounds.maxX else { return false }
            return !layout.chalets.indices.contains { other in
                other != index && layout.chalets[other].depth == layout.chalets[index].depth
                    && layout.chalets[other].base.insetBy(dx: -layout.chalets[other].base.width * 0.22, dy: 0)
                        .intersects(base.insetBy(dx: -base.width * 0.22, dy: 0))
            }
        }
        for _ in 0..<3 {
            for index in layout.chalets.indices where layout.chalets[index].day != nil && hidden(index) {
                let original = layout.chalets[index].base
                let road = layout.roads[layout.chalets[index].depth]
                var placed = false
                for k in 1...60 where !placed {
                    for sign: CGFloat in [1, -1] where !placed {
                        var moved = original
                        moved.origin.x += sign * CGFloat(k) * original.width * 0.15
                        // Stay on the road surface.
                        if let ground = AdventVillage.roadPoint(road, at: moved.midX) {
                            moved.origin.y = ground.y + road.width * 0.35
                        }
                        layout.chalets[index].base = moved
                        if clearOfNeighbours(index, moved) && !hidden(index) { placed = true }
                    }
                }
                if !placed { layout.chalets[index].base = original }
            }
        }
        // Still hidden: try moving the nearer house out of the way instead.
        for index in layout.chalets.indices where layout.chalets[index].day != nil && hidden(index) {
            let area = AdventLayout.doorArea(layout.chalets[index])
            for blocker in layout.chalets.indices
            where layout.chalets[blocker].depth > layout.chalets[index].depth && AdventLayout.covers(layout.chalets[blocker], area) {
                let original = layout.chalets[blocker].base
                let road = layout.roads[layout.chalets[blocker].depth]
                var placed = false
                for k in 1...60 where !placed {
                    for sign: CGFloat in [1, -1] where !placed {
                        var moved = original
                        moved.origin.x += sign * CGFloat(k) * original.width * 0.08
                        if let ground = AdventVillage.roadPoint(road, at: moved.midX) { moved.origin.y = ground.y + road.width * 0.35 }
                        layout.chalets[blocker].base = moved
                        let othersFine = !layout.chalets.indices.contains { $0 != index && layout.chalets[$0].day != nil && hidden($0) }
                        if clearOfNeighbours(blocker, moved) && !AdventLayout.covers(layout.chalets[blocker], area) && othersFine {
                            placed = true
                        }
                    }
                }
                if !placed { layout.chalets[blocker].base = original }
            }
        }
        // Still hidden: hand the number to a house that has no door yet and
        // whose doorway is in the clear.
        for index in layout.chalets.indices where layout.chalets[index].day != nil && hidden(index) {
            if let spare = layout.chalets.indices.first(where: {
                layout.chalets[$0].day == nil && layout.chalets[$0].kind == .chalet && !hidden($0)
            }) {
                layout.chalets[spare].day = layout.chalets[index].day
                layout.chalets[index].day = nil
            }
        }
        // Last resort: move the door along the front of its own house, away
        // from whatever stands in front of it.
        for index in layout.chalets.indices where layout.chalets[index].day != nil
            && layout.chalets[index].kind == .chalet && hidden(index) {
            let w = layout.chalets[index].base.width
            for step in 1...6 {
                var found = false
                for sign: CGFloat in [1, -1] {
                    layout.chalets[index].doorShift = sign * CGFloat(step) * w * 0.06
                    if !hidden(index) { found = true; break }
                }
                if found { break }
                if step == 6 { layout.chalets[index].doorShift = 0 }
            }
        }
        // Houses moved since: check the granaries once more.
        layout.chalets = layout.chalets.enumerated().filter { index, chalet in
            guard chalet.kind == .barn else { return true }
            let mine = chalet.base.insetBy(dx: -chalet.base.width * 0.25, dy: 0)
            return !layout.chalets.enumerated().contains { other, house in
                other != index && house.depth == chalet.depth && house.kind != .barn
                    && house.base.insetBy(dx: -house.base.width * 0.36, dy: 0).intersects(mine)
            }
        }.map { $0.element }
        // Street lights stand between the houses, never behind one: a post
        // poking out under a chalet reads as a house on stilts.
        for roadIndex in layout.roads.indices {
            let spans = layout.chalets.filter { $0.depth == roadIndex }.map {
                ($0.base.minX - $0.base.width * 0.42, $0.base.maxX + $0.base.width * 0.42)
            }.sorted { $0.0 < $1.0 }
            let road = layout.roads[roadIndex]
            func surface(_ x: CGFloat) -> CGFloat {
                let points = road.points
                guard let first = points.first else { return 0 }
                if x <= first.x { return first.y }
                for index in 1..<points.count where x <= points[index].x {
                    let a = points[index - 1], b = points[index]
                    return a.y + (b.y - a.y) * (x - a.x) / max(0.001, b.x - a.x)
                }
                return points[points.count - 1].y
            }
            // Two lamps pushed into the same gap would stand as a double post,
            // so each one takes the free side of its house.
            let spacing = max(14, road.width * 2.2)
            var placed: [CGFloat] = []
            func free(_ x: CGFloat) -> Bool { !placed.contains { abs($0 - x) < spacing } }
            for lampIndex in layout.roads[roadIndex].lamps.indices {
                var lamp = layout.roads[roadIndex].lamps[lampIndex]
                var x = lamp.x
                if let span = spans.first(where: { x > $0.0 && x < $0.1 }) {
                    let near = (x - span.0 < span.1 - x) ? span.0 : span.1
                    let far = near == span.0 ? span.1 : span.0
                    x = free(near) ? near : far
                }
                if !free(x) { x += spacing }
                // A lantern must not stand in front of a door further back.
                let doorAreas = layout.chalets.filter { $0.day != nil && $0.depth <= roadIndex }.map { AdventLayout.doorArea($0) }
                func blocksDoor(_ x: CGFloat) -> Bool {
                    let probe = AdventLayout.lanternArea(CGPoint(x: x, y: surface(x) - road.width * 0.55), road: road)
                    return doorAreas.contains { $0.intersects(probe) }
                }
                var shift: CGFloat = 0
                while blocksDoor(x + shift) && abs(shift) < bounds.width * 0.1 {
                    shift = shift <= 0 ? -shift + road.width * 0.6 : -shift
                }
                x += shift
                x = min(bounds.maxX - 6, max(bounds.minX + 6, x))
                placed.append(x)
                lamp.x = x
                lamp.y = surface(x) - road.width * 0.55
                layout.roads[roadIndex].lamps[lampIndex] = lamp
            }
        }
        // Final check against everything that can stand in front of a door —
        // nearer houses, the big firs, the village tree and lanterns — until
        // every door is clear: shift the door along its house, else hand the
        // number to a house whose doorway is free.
        func blocked(_ index: Int) -> Bool {
            let chalet = layout.chalets[index]
            let area = AdventLayout.doorArea(chalet)
            if layout.chalets.contains(where: { $0.depth > chalet.depth && AdventLayout.covers($0, area) }) { return true }
            if AdventLayout.frameTreesCover(area, in: bounds) { return true }
            for (roadIndex, road) in layout.roads.enumerated() where roadIndex >= chalet.depth {
                if road.lamps.contains(where: { AdventLayout.lanternArea($0, road: road).intersects(area) }) { return true }
            }
            return false
        }
        for _ in 0..<4 {
            var changed = false
            for index in layout.chalets.indices where layout.chalets[index].day != nil && blocked(index) {
                changed = true
                if layout.chalets[index].kind == .chalet {
                    let w = layout.chalets[index].base.width
                    var fixed = false
                    for step in 1...6 where !fixed {
                        for sign: CGFloat in [1, -1] where !fixed {
                            layout.chalets[index].doorShift = sign * CGFloat(step) * w * 0.06
                            fixed = !blocked(index)
                        }
                    }
                    if fixed { continue }
                    layout.chalets[index].doorShift = 0
                }
                if let spare = layout.chalets.indices.first(where: {
                    layout.chalets[$0].day == nil && layout.chalets[$0].kind == .chalet && !blocked($0)
                }) {
                    layout.chalets[spare].day = layout.chalets[index].day
                    layout.chalets[index].day = nil
                }
            }
            if !changed { break }
        }
        for chalet in layout.chalets {
            guard let day = chalet.day else { continue }
            if chalet.kind == .church {
                // Christmas Eve opens the church portal itself.
                let w = chalet.base.width, h = chalet.base.height
                layout.doors.append(AdventDoor(day: day, rect: CGRect(x: chalet.base.midX - w * 0.15, y: chalet.base.minY,
                                                                      width: w * 0.30, height: h * 0.30),
                                               depth: chalet.depth))
                continue
            }
            let size = CGSize(width: min(22, chalet.base.width * 0.30),
                              height: min(26, chalet.base.height * 0.58))
            let rect = CGRect(x: chalet.base.midX + chalet.doorShift - size.width / 2,
                              y: chalet.base.minY + chalet.base.height * 0.06,
                              width: size.width, height: size.height)
            layout.doors.append(AdventDoor(day: day, rect: rect, depth: chalet.depth))
        }
        layout.doors.sort { $0.day < $1.day }

        // Each row of firs stands just behind its road, so far trees sit high
        // and small, near trees low and large.
        let roadHeights: [CGFloat] = [0.345, 0.225, 0.135]
        for index in 0..<64 {
            let depth = index % 3
            let x = bounds.minX + w * hash(index, 60)
            let y = bounds.minY + h * (roadHeights[depth] + 0.018 + hash(index, 61) * 0.055)
            layout.firs.append((x: x, y: y, size: unit * (0.38 + CGFloat(depth) * 0.42 + hash(index, 62) * 0.32),
                                depth: depth))
        }
        // A tree line on the lower slopes of each range: dense at the bottom,
        // thinning out as it climbs, gone above the snow line.
        // Two ski runs snake down the middle range from just under a summit.
        // The near range in front hides their lower ends.
        if layout.ridges.count == 3 {
            let middle = layout.ridges[1]
            for (index, start) in [CGFloat(0.36), CGFloat(0.66)].enumerated() {
                // Start under the highest point near the planned spot.
                var bestX = bounds.minX + w * start
                var bestY = -CGFloat.infinity
                for probe in 0...20 {
                    let x = bounds.minX + w * (start - 0.06 + 0.006 * CGFloat(probe))
                    let y = AdventLayout.height(of: middle, at: x)
                    if y > bestY { bestY = y; bestX = x }
                }
                var run: [CGPoint] = []
                let samples = 40
                for step in 0...samples {
                    let t = CGFloat(step) / CGFloat(samples)
                    let swing = sin(t * .pi * 3.2 + CGFloat(index)) * w * 0.035 * (0.4 + t)
                    let x = bestX + swing + w * 0.05 * t * (index == 0 ? -1 : 1)
                    let top = AdventLayout.height(of: middle, at: x) - h * 0.012
                    let y = min(top, bestY - h * 0.012 - (bestY - bounds.minY - h * 0.40) * t)
                    run.append(CGPoint(x: x, y: y))
                }
                layout.pistes.append(run)
            }
        }
        // Forest grows in groves on the lower slopes, not as single trees
        // sprinkled over the snowfield: a few dense stands per range, thinning
        // toward their edges and stopping well below the crest.
        for (index, ridge) in layout.ridges.enumerated() {
            let groves = 9 - index
            for grove in 0..<groves {
                let centre = bounds.minX + w * (CGFloat(grove) + 0.2 + hash(grove, 90 + index * 7) * 0.6)
                    / CGFloat(groves)
                let spread = w * (0.035 + hash(grove, 91 + index * 7) * 0.035)
                let trees = 9 + Int(hash(grove, 92 + index * 7) * 9)
                for tree in 0..<trees {
                    let offset = (hash(grove * 41 + tree, 93 + index) - 0.5) * 2
                    let x = centre + offset * spread
                    let surface = AdventLayout.height(of: ridge, at: x)
                    let edge = abs(offset)
                    // Trees climb higher in the middle of the grove.
                    let climb = hash(grove * 43 + tree, 94 + index) * (1 - edge * 0.7)
                    let y = surface - h * (0.045 + (1 - climb) * 0.05)
                    guard y > bounds.minY + h * 0.17 else { continue }
                    layout.treeLine.append((x: x, y: y,
                                            size: unit * (0.30 + (1 - climb) * 0.30) * (1.05 - CGFloat(index) * 0.12),
                                            ridge: index))
                }
            }
            layout.treeLine.sort { $0.y > $1.y }
        }
        // The runs are cut through the forest.
        let clearance = h * 0.022
        // A copy of the runs: reading layout inside its own removeAll is an
        // overlapping access and traps.
        let runs = layout.pistes
        layout.treeLine.removeAll { tree in
            tree.ridge == 1 && runs.contains { run in
                run.contains { abs($0.x - tree.x) < clearance && abs($0.y - tree.y) < clearance * 1.6 }
            }
        }
        // Glints on the snowfields.
        for index in 0..<120 {
            let x = bounds.minX + w * hash(index, 300)
            let y = bounds.minY + h * (0.05 + hash(index, 301) * 0.58)
            layout.sparkles.append((CGPoint(x: x, y: y), 0.6 + hash(index, 302) * 1.1))
        }
        // The skating pond lies in front of the village, below the near road:
        // further back the near houses would hide it completely.
        layout.lake = CGRect(x: bounds.minX + w * 0.63, y: bounds.minY + h * 0.035,
                             width: w * 0.23, height: h * 0.062)
        layout.treeSize = unit * 2.6
        layout.tree = CGPoint(x: bounds.minX + w * 0.42, y: bounds.minY + h * 0.135)
        // The combined silhouette of all mountains, sampled across the width.
        func top(of polygon: [CGPoint], at x: CGFloat) -> CGFloat? {
            var best: CGFloat?
            for index in polygon.indices {
                let a = polygon[index], b = polygon[(index + 1) % polygon.count]
                guard (a.x <= x && b.x >= x) || (b.x <= x && a.x >= x), a.x != b.x else { continue }
                let y = a.y + (b.y - a.y) * (x - a.x) / (b.x - a.x)
                best = max(best ?? y, y)
            }
            return best
        }
        let samples = 160
        for step in 0...samples {
            let x = bounds.minX + w * CGFloat(step) / CGFloat(samples)
            var y = bounds.minY
            for ridge in layout.skyline + layout.ridges { y = max(y, AdventLayout.height(of: ridge, at: x)) }
            if let horn = top(of: layout.matterhorn, at: x) { y = max(y, horn) }
            layout.horizon.append(CGPoint(x: x, y: y))
        }
        return layout
    }

    /// Height of a ridge line at a given x, by walking its points.
    static func height(of ridge: Ridge, at x: CGFloat) -> CGFloat {
        guard let first = ridge.points.first else { return 0 }
        if x <= first.x { return first.y }
        for index in 1..<ridge.points.count {
            let a = ridge.points[index - 1], b = ridge.points[index]
            if x <= b.x {
                let span = max(0.0001, b.x - a.x)
                return a.y + (b.y - a.y) * (x - a.x) / span
            }
        }
        return ridge.points[ridge.points.count - 1].y
    }

    /// How many street lights are burning at this point in Advent.
    func litLamps(warmth: CGFloat) -> Int {
        let total = roads.reduce(0) { $0 + $1.lamps.count }
        return Int((CGFloat(total) * warmth).rounded())
    }
}

// MARK: - Painting

enum AdventPaint {
    static func color(_ rgb: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(srgbRed: CGFloat((rgb >> 16) & 255) / 255,
                green: CGFloat((rgb >> 8) & 255) / 255, blue: CGFloat(rgb & 255) / 255, alpha: alpha)
    }

    static func box(_ ctx: CGContext, _ rect: CGRect, _ radius: CGFloat, _ fill: UInt32, alpha: CGFloat = 1) {
        ctx.setFillColor(color(fill, alpha))
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        ctx.fillPath()
    }

    static func oval(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat,
                     _ fill: UInt32, alpha: CGFloat = 1) {
        ctx.setFillColor(color(fill, alpha))
        ctx.fillEllipse(in: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h))
    }

    static func stroke(_ ctx: CGContext, _ points: [CGPoint], _ fill: UInt32, _ width: CGFloat,
                       alpha: CGFloat = 1) {
        guard let first = points.first else { return }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(width)
        ctx.setStrokeColor(color(fill, alpha))
        ctx.beginPath()
        ctx.move(to: first)
        ctx.addLines(between: points)
        ctx.strokePath()
    }

    static func star(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat,
                     _ fill: UInt32, alpha: CGFloat = 1) {
        ctx.setFillColor(color(fill, alpha))
        ctx.beginPath()
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4
            let r = index.isMultiple(of: 2) ? radius : radius * 0.28
            let point = CGPoint(x: x + cos(angle) * r * 0.80, y: y + sin(angle) * r)
            if index == 0 { ctx.move(to: point) } else { ctx.addLine(to: point) }
        }
        ctx.closePath()
        ctx.fillPath()
    }

    /// Light lying on the snow: a glow squashed flat, bright in the middle
    /// and fading out to nothing, so it reads as light and not as a disc.
    static func pool(_ ctx: CGContext, at point: CGPoint, width: CGFloat, flat: CGFloat = 0.28,
                     _ fill: UInt32, _ alpha: CGFloat) {
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y)
        ctx.scaleBy(x: 1, y: flat)
        glow(ctx, at: .zero, radius: width / 2, fill, alpha)
        ctx.restoreGState()
    }

    /// A headlamp's beam: a soft cone from the lamp down to where it lights
    /// the ground, brightest at the lamp.
    static func beam(_ ctx: CGContext, from lamp: CGPoint, to ground: CGPoint, spread: CGFloat,
                     _ fill: UInt32, _ alpha: CGFloat) {
        guard alpha > 0.004 else { return }
        let cone = CGMutablePath()
        cone.move(to: CGPoint(x: lamp.x, y: lamp.y + spread * 0.04))
        cone.addLine(to: CGPoint(x: ground.x, y: ground.y + spread * 0.18))
        cone.addLine(to: CGPoint(x: ground.x, y: ground.y - spread * 0.12))
        cone.addLine(to: CGPoint(x: lamp.x, y: lamp.y - spread * 0.04))
        cone.closeSubpath()
        ctx.saveGState()
        ctx.addPath(cone)
        ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [color(fill, alpha), color(fill, 0)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: lamp, end: ground, options: [])
        ctx.restoreGState()
    }

    /// Set while a frame is drawn on the main thread; every `glow` in it is
    /// then stamped instead of worked out as a gradient.
    private static var liveDepth = 0
    static func live(_ body: () -> Void) {
        guard Thread.isMainThread else { body(); return }
        liveDepth += 1
        defer { liveDepth -= 1 }
        body()
    }

    /// The same soft glow as `glow`, `stretch` times as wide as high, for
    /// things drawn in every frame. macOS draws these windows on the
    /// graphics chip and works out each radial gradient afresh: the
    /// hundreds of lights, lamps and smoke puffs in a frame kept it busy
    /// and the snow below 40 frames a second. Like the snowflakes, each
    /// glow is instead a stamp made once at exactly its size in pixels, in
    /// steps of half a point; a stamp that had to be scaled or converted
    /// cost the processor dearly.
    static func glowStamp(_ ctx: CGContext, at point: CGPoint, radius: CGFloat, _ fill: UInt32, _ alpha: CGFloat,
                          stretch: CGFloat = 1) {
        guard alpha > 0.004, radius > 0.5 else { return }
        let m = ctx.ctm
        let sx = abs(m.a) * stretch, sy = abs(m.d)
        // Turned, mirrored into a skew or huge: the gradient itself.
        guard abs(m.b) < 0.0001, abs(m.c) < 0.0001, sx > 0.05, sy > 0.05,
              radius * 2 * max(sx, sy) <= 480,
              let stamp = glowStamp(fill, steps: max(2, Int((radius * 2).rounded())), sx: sx, sy: sy) else {
            ctx.saveGState()
            ctx.translateBy(x: point.x, y: point.y)
            ctx.scaleBy(x: stretch, y: 1)
            plainGlow(ctx, at: .zero, radius: radius, fill, alpha)
            ctx.restoreGState()
            return
        }
        let size = CGSize(width: CGFloat(stamp.width) / abs(m.a), height: CGFloat(stamp.height) / sy)
        ctx.saveGState()
        ctx.setAlpha(min(1, alpha))
        ctx.draw(stamp, in: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                   width: size.width, height: size.height))
        ctx.restoreGState()
    }

    /// Any soft light drawn in every frame (a headlamp's pool, a blinking
    /// beacon, sparkles), as a stamp made once at its size in pixels. A
    /// single gradient drawn live made the screen's renderer wait for the
    /// graphics chip in every frame. `paint` draws into a `size` canvas.
    static func stamp(_ ctx: CGContext, _ rect: CGRect, key: String, alpha: CGFloat = 1,
                      paint: (CGContext, CGSize) -> Void) {
        guard alpha > 0.004, rect.width > 0.1, rect.height > 0.1 else { return }
        let m = ctx.ctm
        let sx = abs(m.a), sy = abs(m.d)
        guard abs(m.b) < 0.0001, abs(m.c) < 0.0001, sx > 0.05, sy > 0.05 else {
            ctx.saveGState(); ctx.setAlpha(min(1, alpha)); ctx.translateBy(x: rect.minX, y: rect.minY)
            paint(ctx, rect.size); ctx.restoreGState()
            return
        }
        let width = max(1, Int((rect.width * sx).rounded(.up))), height = max(1, Int((rect.height * sy).rounded(.up)))
        let name = StampKey(name: key, a: Int32(width), b: Int32(height), c: 0, d: 0)
        glowStampLock.lock()
        var image = glowStamps[name]
        if image == nil, let canvas = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            canvas.scaleBy(x: CGFloat(width) / rect.width, y: CGFloat(height) / rect.height)
            paint(canvas, rect.size)
            image = canvas.makeImage()
            if glowStamps.count > 900 { glowStamps.removeAll() }
            glowStamps[name] = image
        }
        glowStampLock.unlock()
        guard let image else { return }
        ctx.saveGState()
        ctx.setAlpha(min(1, alpha))
        ctx.draw(image, in: CGRect(x: rect.minX, y: rect.minY, width: CGFloat(width) / sx, height: CGFloat(height) / sy))
        ctx.restoreGState()
    }

    /// What tells two stamps apart. Plain numbers: a text key built for
    /// each of the hundreds of glows in a frame cost more than the glow.
    private struct StampKey: Hashable {
        var name: String = ""
        var a: Int32, b: Int32, c: Int32, d: Int32
    }
    private static var glowStamps: [StampKey: CGImage] = [:]
    private static let glowStampLock = NSLock()

    static func glowStamp(_ fill: UInt32, steps: Int, sx: CGFloat, sy: CGFloat) -> CGImage? {
        glowStampLock.lock()
        defer { glowStampLock.unlock() }
        let key = StampKey(a: Int32(bitPattern: fill), b: Int32(steps),
                           c: Int32((sx * 100).rounded()), d: Int32((sy * 100).rounded()))
        if let stamp = glowStamps[key] { return stamp }
        // Colours follow the daylight and some lights breathe: keep the
        // cache from growing all day.
        if glowStamps.count > 900 { glowStamps.removeAll() }
        let radius = CGFloat(steps) / 2
        let width = max(1, Int((radius * 2 * sx).rounded(.up))), height = max(1, Int((radius * 2 * sy).rounded(.up)))
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
        ctx.scaleBy(x: sx, y: sy)
        plainGlow(ctx, at: .zero, radius: radius, fill, 1)
        guard let stamp = ctx.makeImage() else { return nil }
        glowStamps[key] = stamp
        return stamp
    }

    private static var gradients: [UInt32: CGGradient] = [:]
    private static let gradientLock = NSLock()

    /// The glow as a true gradient, from the colour at `alpha` to nothing.
    private static func plainGlow(_ ctx: CGContext, at point: CGPoint, radius: CGFloat, _ fill: UInt32, _ alpha: CGFloat) {
        guard alpha > 0.004, radius > 0.5 else { return }
        // One gradient per colour at full strength, faded with the alpha;
        // a new gradient object for every call had to be prepared anew.
        gradientLock.lock()
        let gradient: CGGradient
        if let known = gradients[fill] {
            gradient = known
        } else {
            gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [color(fill, 1), color(fill, 0)] as CFArray, locations: [0, 1])!
            if gradients.count > 400 { gradients.removeAll() }
            gradients[fill] = gradient
        }
        gradientLock.unlock()
        ctx.saveGState()
        ctx.setAlpha(min(1, alpha))
        ctx.drawRadialGradient(gradient, startCenter: point, startRadius: 0,
                               endCenter: point, endRadius: radius, options: [])
        ctx.restoreGState()
    }

    static func glow(_ ctx: CGContext, at point: CGPoint, radius: CGFloat, _ fill: UInt32, _ alpha: CGFloat) {
        if liveDepth > 0, Thread.isMainThread {
            glowStamp(ctx, at: point, radius: radius, fill, alpha)
        } else {
            plainGlow(ctx, at: point, radius: radius, fill, alpha)
        }
    }

    static func fir(_ ctx: CGContext, x: CGFloat, y: CGFloat, size: CGFloat, fill: UInt32, snow: UInt32) {
        if size > 60 { bigFir(ctx, x: x, y: y, size: size, fill: fill, snow: snow); return }
        let seed = Int(abs(x * 17 + y * 5))
        func n(_ i: Int) -> CGFloat { AdventLayout.noise(seed + i * 29, 708) }
        box(ctx, CGRect(x: x - size * 0.045, y: y, width: size * 0.09, height: size * 0.26), 1, 0x3a3038)
        // Tiers of drooping boughs: concave flanks, a ragged hem of hanging
        // tips, the right half in shade, snow lying in lumps on top.
        let tiers = size > 14 ? 5 : 3
        let dark = AdventVillage.blend(fill, 0x000000, 0.28)
        let light = AdventVillage.blend(fill, 0xffffff, 0.16)
        for tier in 0..<tiers {
            let f = CGFloat(tier) / CGFloat(tiers)
            let base = y + size * (0.12 + 0.70 * f)
            let width = size * (0.36 - 0.27 * f) * (0.92 + n(tier) * 0.16)
            let rise = size * (0.36 - 0.12 * f)
            let tip = CGPoint(x: x + (n(tier + 9) - 0.5) * size * 0.02, y: base + rise)
            let bough = CGMutablePath()
            bough.move(to: CGPoint(x: x - width, y: base))
            bough.addQuadCurve(to: tip, control: CGPoint(x: x - width * 0.30, y: base + rise * 0.35))
            bough.addQuadCurve(to: CGPoint(x: x + width, y: base), control: CGPoint(x: x + width * 0.30, y: base + rise * 0.35))
            let teeth = size > 14 ? 5 : 3
            for tooth in stride(from: teeth, through: 0, by: -1) {
                let t = CGFloat(tooth) / CGFloat(teeth)
                let hx = x + width * (t * 2 - 1)
                let droop = tooth % 2 == 0 ? 0 : size * (0.025 + n(tier * 7 + tooth) * 0.02)
                bough.addLine(to: CGPoint(x: hx, y: base - droop))
            }
            bough.closeSubpath()
            ctx.setFillColor(color(fill))
            ctx.addPath(bough)
            ctx.fillPath()
            if size > 9 {
                ctx.saveGState()
                ctx.addPath(bough)
                ctx.clip()
                ctx.setFillColor(color(dark, 0.55))
                ctx.fill(CGRect(x: x + size * 0.01, y: base - size * 0.1, width: width + size * 0.1, height: rise + size * 0.2))
                ctx.setFillColor(color(light, 0.5))
                ctx.fill(CGRect(x: x - width - size * 0.05, y: base - size * 0.1, width: width * 0.35, height: rise + size * 0.2))
                ctx.restoreGState()
            }
            if size > 12 {
                // Snow in lumps along the top of the tier, scalloped below.
                let cap = CGMutablePath()
                let low = base + rise * 0.18
                cap.move(to: CGPoint(x: x - width * 0.78, y: low))
                cap.addQuadCurve(to: CGPoint(x: tip.x, y: tip.y - rise * 0.06), control: CGPoint(x: x - width * 0.30, y: base + rise * 0.55))
                cap.addQuadCurve(to: CGPoint(x: x + width * 0.70, y: low + rise * 0.05), control: CGPoint(x: x + width * 0.28, y: base + rise * 0.55))
                let scallops = 3
                for k in stride(from: scallops, through: 1, by: -1) {
                    let t = (CGFloat(k) - 1) / CGFloat(scallops)
                    let ex = x - width * 0.78 + (width * 1.48) * t
                    let mx = ex + width * 1.48 / CGFloat(scallops) * 0.5
                    cap.addQuadCurve(to: CGPoint(x: ex, y: low + (k == 1 ? 0 : rise * 0.04)),
                                     control: CGPoint(x: mx, y: low - rise * (0.10 + n(tier * 5 + k) * 0.08)))
                }
                cap.closeSubpath()
                ctx.setFillColor(color(snow, 0.93))
                ctx.addPath(cap)
                ctx.fillPath()
            } else if size > 7 {
                stroke(ctx, [CGPoint(x: x - width * 0.45, y: base + rise * 0.30), CGPoint(x: tip.x, y: tip.y - rise * 0.15),
                             CGPoint(x: x + width * 0.35, y: base + rise * 0.32)], snow, max(0.6, size * 0.035), alpha: 0.7)
            }
        }
    }
}

extension AdventPaint {
    /// A large fir seen up close: many tiers of drooping boughs with ragged
    /// tips, snow lying in lumps on top of each, light catching the left edge.
    static func bigFir(_ ctx: CGContext, x: CGFloat, y: CGFloat, size: CGFloat, fill: UInt32, snow: UInt32) {
        let seed = Int(abs(x * 13 + y * 7))
        func n(_ i: Int) -> CGFloat { AdventLayout.noise(seed + i * 31, 707) }
        // Trunk sunk into a little snow mound.
        box(ctx, CGRect(x: x - size * 0.035, y: y, width: size * 0.07, height: size * 0.22), size * 0.01,
            AdventVillage.blend(0x3a3038, fill, 0.3))
        let tiers = 7
        let top = y + size * 1.02
        let bottom = y + size * 0.12
        for tier in 0..<tiers {
            let t = CGFloat(tier) / CGFloat(tiers - 1)
            let base = bottom + (top - bottom - size * 0.18) * t * 0.92
            let width = size * (0.40 - 0.31 * t) * (0.94 + n(tier) * 0.12)
            let rise = size * (0.30 - 0.08 * t)
            let peak = CGPoint(x: x + (n(tier + 50) - 0.5) * size * 0.01, y: base + rise)
            let tone = AdventVillage.blend(fill, 0x000000, 0.18 * (1 - t))
            // Bough: concave flanks up to the tier's peak, a ragged hem of
            // hanging branch tips below.
            let bough = CGMutablePath()
            let left = CGPoint(x: x - width, y: base - size * 0.02)
            let right = CGPoint(x: x + width, y: base - size * 0.02)
            bough.move(to: left)
            bough.addQuadCurve(to: peak, control: CGPoint(x: x - width * 0.30, y: base + rise * 0.42))
            bough.addQuadCurve(to: right, control: CGPoint(x: x + width * 0.30, y: base + rise * 0.42))
            let tips = 6 + Int(width / size * 10)
            for tip in stride(from: tips, through: 0, by: -1) {
                let u = CGFloat(tip) / CGFloat(tips)
                let along = x - width + width * 2 * u
                let sag = size * (0.035 + n(tier * 19 + tip) * 0.03) * (1 - abs(u - 0.5) * 0.8)
                bough.addLine(to: CGPoint(x: along, y: base - sag))
                if tip > 0 {
                    bough.addLine(to: CGPoint(x: along - width / CGFloat(tips), y: base - sag * 0.25))
                }
            }
            bough.closeSubpath()
            ctx.setFillColor(color(tone))
            ctx.addPath(bough)
            ctx.fillPath()
            // Light from the left grazes the outer edge of each bough.
            ctx.saveGState()
            ctx.addPath(bough)
            ctx.clip()
            let lit = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                 colors: [color(AdventVillage.blend(tone, 0x8fb0b8, 0.35)), color(tone, 0)] as CFArray,
                                 locations: [0, 1])!
            ctx.drawLinearGradient(lit, start: CGPoint(x: x - width, y: 0), end: CGPoint(x: x - width * 0.2, y: 0), options: [])
            // The far side turns away into shade.
            let shadeSide = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                       colors: [color(0x0c1418, 0), color(0x0c1418, 0.38)] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(shadeSide, start: CGPoint(x: x + width * 0.05, y: 0), end: CGPoint(x: x + width, y: 0), options: [])
            ctx.restoreGState()
            // Snow: each tier shows only a band between its own hem and the
            // next tier above. The snow fills the upper part of that band and
            // hangs down in lumps, leaving dark boughs showing below.
            let spacing = (top - bottom - size * 0.18) * 0.92 / CGFloat(tiers - 1)
            let lumps = CGMutablePath()
            let reach = width * (0.90 + n(tier + 90) * 0.06)
            lumps.move(to: CGPoint(x: x - reach, y: base + size * 0.006))
            lumps.addQuadCurve(to: CGPoint(x: peak.x, y: peak.y - rise * 0.02),
                               control: CGPoint(x: x - reach * 0.30, y: base + rise * 0.45))
            lumps.addQuadCurve(to: CGPoint(x: x + reach, y: base + size * 0.006),
                               control: CGPoint(x: x + reach * 0.30, y: base + rise * 0.45))
            let bumps = 6
            for bump in stride(from: bumps, through: 1, by: -1) {
                let next = x - reach + reach * 2 * (CGFloat(bump) - 1) / CGFloat(bumps)
                let along = x - reach + reach * 2 * (CGFloat(bump) - 0.5) / CGFloat(bumps)
                let middle = 1 - CGFloat(abs(Double((along - x) / reach)))
                // The snow line sits half-way up the visible band, a little lower
                // near the trunk where the boughs are flatter.
                let line = base + size * 0.006 + spacing * (0.30 + middle * 0.30)
                let hang = spacing * (0.10 + n(tier * 23 + bump) * 0.25)
                lumps.addQuadCurve(to: CGPoint(x: next, y: line), control: CGPoint(x: along, y: line - hang))
            }
            lumps.closeSubpath()
            ctx.saveGState()
            ctx.addPath(lumps)
            ctx.clip()
            let drift = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                   colors: [color(multiply(snow, 0xb7c6dc)), color(snow)] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(drift, start: CGPoint(x: 0, y: base - size * 0.01), end: CGPoint(x: 0, y: base + rise * 0.5),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.restoreGState()
        }
    }

    static func multiply(_ a: UInt32, _ b: UInt32) -> UInt32 { AdventVillage.multiply(a, b) }
}

/// The valley behind the work windows. Everything here is distance: the snow in
/// front, on the window edges and along the bottom of the screen, is untouched.
enum AdventVillage {
    /// The still parts, rendered once and reused until a door is opened.
    static func backdrop(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky,
                         scale: CGFloat) -> CGImage? {
        let bounds = layout.bounds
        let pixelsWide = Int((bounds.width * scale).rounded())
        let pixelsHigh = Int((bounds.height * scale).rounded())
        guard pixelsWide > 0, pixelsHigh > 0,
              let ctx = CGContext(data: nil, width: pixelsWide, height: pixelsHigh, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
        drawSky(layout, season: season, sky: sky, in: ctx)
        drawMountains(layout, sky: sky, scale: scale, pixels: (pixelsWide, pixelsHigh), in: ctx)
        drawValleyFloor(layout, sky: sky, in: ctx)
        drawFirs(layout, depth: 0, sky: sky, in: ctx)
        drawRoad(layout, index: 0, season: season, sky: sky, in: ctx)
        drawFirs(layout, depth: 1, sky: sky, in: ctx)
        drawRoad(layout, index: 1, season: season, sky: sky, in: ctx)
        drawFirs(layout, depth: 2, sky: sky, in: ctx)
        // The near road's fence and lanterns stand in front of the people on
        // it, so they live in the front layer; only the surface goes here.
        drawRoad(layout, index: 2, season: season, sky: sky, part: 1, in: ctx)
        drawTracks(layout, skip: season.has(.pond) ? layout.lake : nil, sky: sky, in: ctx)
        if season.has(.pond) { drawLake(layout, sky: sky, aurora: season.has(.aurora), in: ctx) }
        drawForegroundField(layout, season: season, sky: sky, in: ctx)
        // Far before near; on its road the church goes first so the houses
        // in front of the nave overlap it, and the fountain stands with it.
        let order = layout.chalets.sorted {
            if $0.depth != $1.depth { return $0.depth < $1.depth }
            return ($0.kind == .church ? 0 : 1) < ($1.kind == .church ? 0 : 1)
        }
        for chalet in order {
            drawChalet(chalet, layout: layout, season: season, sky: sky, in: ctx)
            if chalet.kind == .church { drawFountain(layout, sky: sky, in: ctx) }
        }
        drawGarlands(layout, season: season, sky: sky, roads: [0, 1], in: ctx)
        drawSparkle(layout, sky: sky, in: ctx)
        drawHaze(layout, sky: sky, in: ctx)
        // The doors are always there, even in November: closed and numbered,
        // waiting for December. Without them the valley is not a calendar.
        do {
            // The door numbers are AppKit text, which draws into the current
            // graphics context, so this bitmap has to be made current.
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
            for door in layout.doors where !isAnimated(door, season: season) {
                drawDoor(door, season: season, time: 0, pointer: nil, dusk: sky.lampStrength, in: ctx)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        guard let flat = ctx.makeImage() else { return nil }
        return polish(flat, scale: scale, night: sky.lampStrength)
    }

    /// The ranges are painted at full daylight into their own layer and then
    /// lit by the sky: white at noon, cool and dim under the moon. The sky
    /// behind them is left alone.
    private static func drawMountains(_ layout: AdventLayout, sky: AdventSky, scale: CGFloat,
                                      pixels: (Int, Int), in ctx: CGContext) {
        let bounds = layout.bounds
        guard let layer = CGContext(data: nil, width: pixels.0, height: pixels.1, bitsPerComponent: 8,
                                    bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
        layer.scaleBy(x: scale, y: scale)
        layer.translateBy(x: -bounds.minX, y: -bounds.minY)
        drawSkyline(layout, sky: sky, in: layer)
        drawMatterhorn(layout, sky: sky, in: layer)
        drawGlacier(layout, sky: sky, in: layer)
        drawRidges(layout, sky: sky, in: layer)
        guard let painted = layer.makeImage() else { return }
        let light = sky.mountainLight
        if light != 0xffffff {
            layer.saveGState()
            layer.setBlendMode(.multiply)
            layer.setFillColor(AdventPaint.color(light))
            layer.fill(bounds)
            layer.setBlendMode(.destinationIn)
            layer.draw(painted, in: bounds)
            layer.restoreGState()
        }
        // Alpenglow comes after the cool evening light, so the tops burn
        // warm against the blue shadow that already fills everything below.
        let glow = sky.alpenglowStrength
        if glow > 0.02, layout.matterhorn.count > layout.matterhornSummit {
            let top = layout.matterhorn[layout.matterhornSummit].y + bounds.height * 0.01
            let foot = top - bounds.height * 0.24
            let warm = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(sky.alpenglow, 0.55 * glow),
                                           AdventPaint.color(sky.alpenglow, 0.28 * glow),
                                           AdventPaint.color(sky.alpenglow, 0)] as CFArray,
                                  locations: [0, 0.4, 1])!
            layer.saveGState()
            layer.setBlendMode(.sourceAtop)
            layer.setAlpha(0.6)
            layer.drawLinearGradient(warm, start: CGPoint(x: 0, y: top), end: CGPoint(x: 0, y: foot),
                                     options: [.drawsBeforeStartLocation])
            layer.restoreGState()
            // And a luminous pass: the same warm light screened on, masked
            // to the mountains, so snow and rock start to shine.
            if let shine = CGContext(data: nil, width: pixels.0, height: pixels.1, bitsPerComponent: 8,
                                     bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
                shine.scaleBy(x: scale, y: scale)
                shine.translateBy(x: -bounds.minX, y: -bounds.minY)
                let rose = blend(sky.alpenglow, 0xff7f86, 0.25)
                let burn = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: [AdventPaint.color(rose, 0.95 * glow),
                                               AdventPaint.color(rose, 0.42 * glow),
                                               AdventPaint.color(rose, 0)] as CFArray,
                                      locations: [0, 0.35, 1])!
                shine.drawLinearGradient(burn, start: CGPoint(x: 0, y: top), end: CGPoint(x: 0, y: foot),
                                         options: [.drawsBeforeStartLocation])
                shine.setBlendMode(.destinationIn)
                shine.draw(painted, in: bounds)
                if let glowImage = shine.makeImage() {
                    layer.saveGState()
                    layer.setBlendMode(.screen)
                    layer.draw(glowImage, in: bounds)
                    layer.restoreGState()
                }
            }
        }
        guard let lit = layer.makeImage() else { return }
        ctx.draw(lit, in: bounds)
    }

    /// Things that stand in front of the people on the near road (its fence
    /// and lanterns, the strings of lights between them, the big firs at the
    /// screen edges) and the village tree, which people pass on both sides.
    /// Each is a still image, rendered once per change like the backdrop.
    /// A layer cut down to the part of the screen it actually covers, and
    /// where that part sits.
    struct Cut { let image: CGImage; let rect: CGRect }
    private static var frontCache: (key: String, front: Cut, tree: Cut, middle: Cut)?

    private static let frontLock = NSLock()

    /// `allowStale`: in the running app the layers of the last minute are
    /// kept up while the new ones are painted on a background thread.
    static func frontLayers(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky,
                            scale: CGFloat, allowStale: Bool = true) -> (front: Cut, tree: Cut, middle: Cut)? {
        let key = "\(layout.bounds)|\(season.opened.sorted())|\(season.today ?? 0)|\(sky.stamp)|\(scale)"
        frontLock.lock()
        let cached = frontCache
        frontLock.unlock()
        if let cache = cached, cache.key == key { return (cache.front, cache.tree, cache.middle) }
        if allowStale, Thread.isMainThread, NSApp?.isRunning == true, let cache = cached,
           cache.key.hasPrefix("\(layout.bounds)|") {
            return (cache.front, cache.tree, cache.middle)
        }
        let bounds = layout.bounds
        // Each layer is drawn over the whole screen every frame, but most of
        // it is transparent (the village tree is a small spot): cut it down
        // to the rectangle that holds anything at all, once, when it is made.
        func layer(_ paint: (CGContext) -> Void) -> Cut? {
            let wide = Int((bounds.width * scale).rounded()), high = Int((bounds.height * scale).rounded())
            guard wide > 0, high > 0,
                  let ctx = CGContext(data: nil, width: wide, height: high, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -bounds.minX, y: -bounds.minY)
            paint(ctx)
            guard let image = ctx.makeImage() else { return nil }
            var top = high, bottom = -1, left = wide, right = -1
            if let data = ctx.data {
                let row = ctx.bytesPerRow / 4
                let pixels = data.bindMemory(to: UInt32.self, capacity: row * high)
                // Alpha is the last byte; on this little-endian Mac that is
                // the top byte of each 32-bit pixel.
                for y in 0..<high {
                    let start = y * row
                    var first = -1, last = -1
                    var x = 0
                    while x < wide {
                        if pixels[start + x] >> 24 != 0 { first = x; break }
                        x += 1
                    }
                    guard first >= 0 else { continue }
                    x = wide - 1
                    while x >= first {
                        if pixels[start + x] >> 24 != 0 { last = x; break }
                        x -= 1
                    }
                    top = min(top, y); bottom = y
                    left = min(left, first); right = max(right, last)
                }
            }
            guard bottom >= top, right >= left else {
                return Cut(image: image, rect: .zero)
            }
            let pixelRect = CGRect(x: left, y: top, width: right - left + 1, height: bottom - top + 1)
            guard let part = image.cropping(to: pixelRect) else { return Cut(image: image, rect: bounds) }
            // Rows of the bitmap run from the top of the screen down.
            let rect = CGRect(x: bounds.minX + CGFloat(left) / scale,
                              y: bounds.maxY - CGFloat(bottom + 1) / scale,
                              width: CGFloat(right - left + 1) / scale,
                              height: CGFloat(bottom - top + 1) / scale)
            return Cut(image: part, rect: rect)
        }
        guard let front = layer({ ctx in
            drawRoad(layout, index: 2, season: season, sky: sky, part: 2, in: ctx)
            drawGarlands(layout, season: season, sky: sky, roads: [2], in: ctx)
            drawFrameTrees(layout, sky: sky, in: ctx)
        }), let tree = layer({ ctx in drawTreeBody(layout, sky: sky, in: ctx) }),
              // Everything that stands in front of people on the middle road:
              // its own fence, lanterns and lights, the firs and houses of the
              // near road with their doors. People there walk behind all that.
              let middle = layer({ ctx in
                  drawRoad(layout, index: 1, season: season, sky: sky, part: 2, in: ctx)
                  drawGarlands(layout, season: season, sky: sky, roads: [1], in: ctx)
                  drawFirs(layout, depth: 2, sky: sky, in: ctx)
                  drawRoad(layout, index: 2, season: season, sky: sky, part: 1, in: ctx)
                  for chalet in layout.chalets where chalet.depth == 2 {
                      drawChalet(chalet, layout: layout, season: season, sky: sky, in: ctx)
                  }
                  NSGraphicsContext.saveGraphicsState()
                  NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
                  for door in layout.doors where door.depth == 2 && !isAnimated(door, season: season) {
                      drawDoor(door, season: season, time: 0, pointer: nil, dusk: sky.lampStrength, in: ctx)
                  }
                  NSGraphicsContext.restoreGraphicsState()
              }) else { return nil }
        frontLock.lock()
        frontCache = (key, front, tree, middle)
        frontLock.unlock()
        return (front, tree, middle)
    }

    private static let finishing = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                                                       .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

    /// Photographic finish on the still backdrop: lights and bright snow bloom,
    /// a fine grain breaks up the flat vector fills, and a soft vignette
    /// gathers the eye toward the middle. Rendered once per minute, not per frame.
    static func polish(_ image: CGImage, scale: CGFloat, night: CGFloat) -> CGImage {
        let source = CIImage(cgImage: image)
        let extent = source.extent
        var output = source
        if let bloom = CIFilter(name: "CIBloom") {
            bloom.setValue(output, forKey: kCIInputImageKey)
            bloom.setValue(5 * scale, forKey: kCIInputRadiusKey)
            // By day the snow would bloom into fog; the glow belongs to the lights.
            bloom.setValue(0.07 + 0.24 * night * night, forKey: kCIInputIntensityKey)
            if let result = bloom.outputImage?.cropped(to: extent) { output = result }
        }
        if let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?.cropped(to: extent) {
            let grain = noise.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputGVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputBVector": CIVector(x: 0.33, y: 0.33, z: 0.33, w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.045),
                "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 0)])
            output = grain.applyingFilter("CISourceOverCompositing",
                                          parameters: [kCIInputBackgroundImageKey: output]).cropped(to: extent)
        }
        output = vignette(output, extent: extent)
        return finishing.createCGImage(output, from: extent) ?? image
    }

    /// The soft darkening toward the edges, the same on every monitor. Core
    /// Image's own vignette is round, so a wide or ultrawide screen would go
    /// black at its sides; it is made at a laptop's proportions instead and
    /// stretched across the real width.
    static func vignette(_ image: CIImage, extent: CGRect) -> CIImage {
        let reference: CGFloat = 1.54
        let aspect = extent.width / max(1, extent.height)
        let parameters: [String: Any] = [kCIInputIntensityKey: 0.42, kCIInputRadiusKey: 1.7]
        guard aspect > reference * 1.02 else { return image.applyingFilter("CIVignette", parameters: parameters) }
        let base = CGRect(x: 0, y: 0, width: (extent.height * reference).rounded(), height: extent.height)
        let mask = CIImage(color: .white).cropped(to: base)
            .applyingFilter("CIVignette", parameters: parameters)
            .transformed(by: CGAffineTransform(scaleX: extent.width / base.width, y: 1)
                .concatenating(CGAffineTransform(translationX: extent.minX, y: extent.minY)))
            .cropped(to: extent)
        return image.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: mask])
            .cropped(to: extent)
    }

    /// Everything that moves, drawn on top of the backdrop each frame.
    static func drawLive(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky, time: CGFloat,
                         pointer: CGPoint?, in ctx: CGContext) {
        if season.has(.aurora), sky.starlight > 0.3 { drawAurora(layout, time: time, in: ctx) }
        if sky.starlight > 0.2 { drawTwinkle(layout, sky: sky, time: time, in: ctx) }
        drawBanner(layout, time: time, sky: sky, in: ctx)
        if season.has(.bells) { drawChurchBells(layout, sky: sky, in: ctx) }
        if season.has(.balloon) { drawBalloon(layout, sky: sky, time: time, in: ctx) }
        if season.has(.market) { drawMarketStall(layout, sky: sky, time: time, in: ctx) }
        if season.has(.choir) { drawChoir(layout, sky: sky, time: time, in: ctx) }
        drawSmoke(layout, season: season, sky: sky, in: ctx, time: time)
        drawGondolaCabins(layout, season: season, sky: sky, time: time, in: ctx)
        if season.has(.star) { drawChurchStar(layout, time: time, in: ctx) }
        if season.has(.finale), sky.starlight > 0.5 { drawShootingStar(layout, time: time, in: ctx) }
        // Only doors that move are drawn every frame: today's, which pulses,
        // and open ones with a candle flickering inside. The rest are baked
        // into the backdrop.
        drawLife(layout, season: season, sky: sky, time: time, in: ctx)
        drawSkiers(layout, season: season, sky: sky, time: time, in: ctx)
        if season.has(.bonfire) { drawBonfire(layout, sky: sky, time: time, in: ctx) }
        if season.has(.crib) { drawCrib(layout, sky: sky, time: time, in: ctx) }
    }

    // MARK: Door gifts drawn live

    /// Where on the square the little scenes stand, measured from the church.
    private static func squareUnit(_ layout: AdventLayout) -> (church: CGRect, w: CGFloat)? {
        guard let church = layout.chalets.first(where: { $0.kind == .church }) else { return nil }
        return (church.base, church.base.width * 0.9)
    }

    /// Door 14: a mulled-wine stall beside the fountain, striped awning,
    /// blinking lights, a steaming pot and two people at the counter.
    private static func drawMarketStall(_ layout: AdventLayout, sky: AdventSky, time: CGFloat, in ctx: CGContext) {
        guard let (church, w) = squareUnit(layout) else { return }
        let foot = CGPoint(x: church.maxX + w * 1.95, y: church.minY)
        let S = w * 1.25
        let wood = blend(0x8a5a36, sky.horizon, 0.12), woodDark = blend(wood, 0x000000, 0.3)
        let snow = multiply(0xf2f6fa, sky.valleyLight)
        AdventPaint.pool(ctx, at: foot, width: S * 1.6, flat: 0.2, 0x2a3442, 0.22 + 0.2 * sky.daylight)
        if sky.lampStrength > 0.3 { AdventPaint.pool(ctx, at: foot, width: S * 2.2, flat: 0.22, 0xffcf86, 0.35 * sky.lampStrength) }
        // Back wall and side posts.
        AdventPaint.box(ctx, CGRect(x: foot.x - S * 0.5, y: foot.y + S * 0.30, width: S, height: S * 0.42), S * 0.02, woodDark)
        for side: CGFloat in [-1, 1] {
            AdventPaint.box(ctx, CGRect(x: foot.x + side * S * 0.47 - S * 0.03, y: foot.y, width: S * 0.06, height: S * 0.86), S * 0.01, wood)
        }
        // Inside: a warm lamp, a pot on the stove with steam, mugs on a shelf.
        AdventPaint.glow(ctx, at: CGPoint(x: foot.x, y: foot.y + S * 0.55), radius: S * 0.5, 0xffd890, 0.45 + 0.3 * sky.lampStrength)
        AdventPaint.box(ctx, CGRect(x: foot.x - S * 0.12, y: foot.y + S * 0.36, width: S * 0.24, height: S * 0.12), S * 0.03, 0x3a3f48)
        for k in 0..<3 {
            let age = (time * 0.5 + CGFloat(k) / 3).truncatingRemainder(dividingBy: 1)
            let x = foot.x + sin(age * 6 + CGFloat(k)) * S * 0.05
            AdventPaint.oval(ctx, x, foot.y + S * (0.52 + age * 0.55), S * (0.08 + age * 0.12), S * (0.06 + age * 0.09),
                             multiply(0xf4f6f8, sky.valleyLight), alpha: 0.55 * (1 - age))
        }
        for k in 0..<4 {
            let x = foot.x - S * 0.38 + CGFloat(k) * S * 0.07
            AdventPaint.box(ctx, CGRect(x: x, y: foot.y + S * 0.58, width: S * 0.05, height: S * 0.06), S * 0.01, [0xc8322b, 0xf4efe6, 0x2f6b45, 0xc8322b][k])
        }
        // Counter with a garland and two steaming mugs.
        AdventPaint.box(ctx, CGRect(x: foot.x - S * 0.52, y: foot.y, width: S * 1.04, height: S * 0.32), S * 0.02, wood)
        AdventPaint.box(ctx, CGRect(x: foot.x - S * 0.54, y: foot.y + S * 0.30, width: S * 1.08, height: S * 0.05), S * 0.01, woodDark)
        AdventPaint.box(ctx, CGRect(x: foot.x - S * 0.52, y: foot.y + S * 0.24, width: S * 1.04, height: S * 0.05), S * 0.02, 0x2f6b45)
        for k in 0..<5 { AdventPaint.oval(ctx, foot.x - S * 0.42 + CGFloat(k) * S * 0.21, foot.y + S * 0.26, S * 0.05, S * 0.05, 0xc8322b) }
        for side: CGFloat in [-0.28, 0.22] {
            AdventPaint.box(ctx, CGRect(x: foot.x + side * S, y: foot.y + S * 0.35, width: S * 0.06, height: S * 0.07), S * 0.01, 0xc8322b)
        }
        // Striped awning with a scalloped edge.
        let roofY = foot.y + S * 0.86
        let awning = CGMutablePath()
        awning.move(to: CGPoint(x: foot.x - S * 0.62, y: roofY - S * 0.10))
        awning.addLine(to: CGPoint(x: foot.x - S * 0.50, y: roofY + S * 0.24))
        awning.addLine(to: CGPoint(x: foot.x + S * 0.50, y: roofY + S * 0.24))
        awning.addLine(to: CGPoint(x: foot.x + S * 0.62, y: roofY - S * 0.10))
        awning.closeSubpath()
        ctx.saveGState(); ctx.addPath(awning); ctx.clip()
        for k in 0..<10 {
            AdventPaint.box(ctx, CGRect(x: foot.x - S * 0.62 + CGFloat(k) * S * 0.124, y: roofY - S * 0.2, width: S * 0.124, height: S * 0.5), 0,
                            k % 2 == 0 ? multiply(0xc8322b, blend(sky.valleyLight, 0xffffff, 0.4)) : multiply(0xf6f1e6, sky.valleyLight))
        }
        ctx.restoreGState()
        for k in 0..<5 {
            let x = foot.x - S * 0.62 + (CGFloat(k) + 0.5) * S * 0.248
            AdventPaint.oval(ctx, x, roofY - S * 0.10, S * 0.25, S * 0.10, k % 2 == 0 ? 0xc8322b : 0xf6f1e6)
        }
        AdventPaint.box(ctx, CGRect(x: foot.x - S * 0.52, y: roofY + S * 0.22, width: S * 1.04, height: S * 0.06), S * 0.03, snow)
        // Lights along the edge.
        let tints: [UInt32] = [0xffd25a, 0xff5a4a, 0x6ad07a, 0x6aa8ff]
        for k in 0..<8 {
            let on = (Int(time * 2.5) + k) % 3 != 0
            let x = foot.x - S * 0.55 + CGFloat(k) * S * 0.157
            let y = roofY - S * 0.18
            if on { AdventPaint.glow(ctx, at: CGPoint(x: x, y: y), radius: S * 0.07, tints[k % 4], 0.5 + 0.3 * sky.lampStrength) }
            AdventPaint.oval(ctx, x, y, S * 0.035, S * 0.035, on ? tints[k % 4] : blend(tints[k % 4], 0x000000, 0.5))
        }
        // Two people at the counter.
        drawWalker(at: CGPoint(x: foot.x - S * 0.32, y: foot.y - S * 0.12), height: S * 0.62, dir: 1, time: 0, coat: 0x2f5f8a,
                   lantern: false, sky: sky, in: ctx)
        drawWalker(at: CGPoint(x: foot.x + S * 0.30, y: foot.y - S * 0.10), height: S * 0.58, dir: -1, time: 0, coat: 0x7a4a2e,
                   lantern: false, sky: sky, in: ctx)
    }

    /// Door 16: the crib in the field in front of the village, an open
    /// stable under snow with the manger glowing, Mary and Joseph, and a
    /// star over the roof. Out in the open, so nothing stands in front of it.
    static func cribFoot(_ layout: AdventLayout) -> CGPoint {
        CGPoint(x: layout.bounds.minX + layout.bounds.width * 0.455, y: layout.bounds.minY + layout.bounds.height * 0.05)
    }

    private static func drawCrib(_ layout: AdventLayout, sky: AdventSky, time: CGFloat, in ctx: CGContext) {
        let foot = cribFoot(layout)
        let S = layout.bounds.height * 0.085
        let wood = blend(0x7a5236, sky.horizon, 0.12), woodDark = blend(wood, 0x000000, 0.35)
        let snow = multiply(0xf2f6fa, sky.valleyLight)
        AdventPaint.pool(ctx, at: foot, width: S * 1.5, flat: 0.2, 0x2a3442, 0.22 + 0.2 * sky.daylight)
        // Back wall of planks, two posts, a pitched roof with snow.
        AdventPaint.box(ctx, CGRect(x: foot.x - S * 0.48, y: foot.y, width: S * 0.96, height: S * 0.62), S * 0.01, woodDark)
        for k in 1..<6 {
            let x = foot.x - S * 0.48 + CGFloat(k) * S * 0.16
            AdventPaint.stroke(ctx, [CGPoint(x: x, y: foot.y), CGPoint(x: x, y: foot.y + S * 0.62)], blend(woodDark, 0x000000, 0.3), max(0.3, S * 0.01))
        }
        for side: CGFloat in [-1, 1] {
            AdventPaint.box(ctx, CGRect(x: foot.x + side * S * 0.46 - S * 0.04, y: foot.y, width: S * 0.08, height: S * 0.66), S * 0.01, wood)
        }
        let roof = CGMutablePath()
        roof.move(to: CGPoint(x: foot.x - S * 0.62, y: foot.y + S * 0.62))
        roof.addLine(to: CGPoint(x: foot.x, y: foot.y + S * 0.98))
        roof.addLine(to: CGPoint(x: foot.x + S * 0.62, y: foot.y + S * 0.62))
        roof.addLine(to: CGPoint(x: foot.x + S * 0.62, y: foot.y + S * 0.56))
        roof.addLine(to: CGPoint(x: foot.x, y: foot.y + S * 0.90))
        roof.addLine(to: CGPoint(x: foot.x - S * 0.62, y: foot.y + S * 0.56))
        roof.closeSubpath()
        ctx.setFillColor(AdventPaint.color(wood)); ctx.addPath(roof); ctx.fillPath()
        AdventPaint.stroke(ctx, [CGPoint(x: foot.x - S * 0.64, y: foot.y + S * 0.65), CGPoint(x: foot.x, y: foot.y + S * 1.02),
                                 CGPoint(x: foot.x + S * 0.64, y: foot.y + S * 0.65)], snow, max(1, S * 0.06))
        // The manger with straw and the light of the child.
        let manger = CGPoint(x: foot.x, y: foot.y + S * 0.10)
        AdventPaint.glow(ctx, at: CGPoint(x: manger.x, y: manger.y + S * 0.12), radius: S * 0.55, 0xffe2a0, 0.55 + 0.3 * sky.lampStrength)
        AdventPaint.box(ctx, CGRect(x: manger.x - S * 0.16, y: manger.y, width: S * 0.32, height: S * 0.10), S * 0.02, wood)
        AdventPaint.oval(ctx, manger.x, manger.y + S * 0.11, S * 0.30, S * 0.07, 0xe8c46a)
        AdventPaint.oval(ctx, manger.x, manger.y + S * 0.14, S * 0.12, S * 0.07, 0xfff4dc)
        // Mary in blue and Joseph in brown, either side.
        drawWalker(at: CGPoint(x: foot.x - S * 0.30, y: foot.y), height: S * 0.52, dir: 1, time: 0, coat: 0x2f5fa8,
                   lantern: false, sky: sky, shadow: false, in: ctx)
        drawWalker(at: CGPoint(x: foot.x + S * 0.30, y: foot.y), height: S * 0.58, dir: -1, time: 0, coat: 0x7a4a2e,
                   lantern: false, sky: sky, shadow: false, in: ctx)
        // The star over the stable.
        let star = CGPoint(x: foot.x, y: foot.y + S * 1.30)
        let twinkle = 0.85 + 0.15 * sin(time * 2.3)
        AdventPaint.glow(ctx, at: star, radius: S * 0.5, 0xffd79b, 0.45 * twinkle)
        AdventPaint.star(ctx, star.x, star.y, S * 0.14 * twinkle, 0xffcd83)
        AdventPaint.stroke(ctx, [CGPoint(x: star.x - S * 0.05, y: star.y - S * 0.02), CGPoint(x: star.x - S * 0.32, y: star.y + S * 0.10)],
                           0xffe6a8, max(0.5, S * 0.025), alpha: 0.7)
    }

    /// Door 19: children singing in front of the church, song books open,
    /// notes rising into the air.
    private static func drawChoir(_ layout: AdventLayout, sky: AdventSky, time: CGFloat, in ctx: CGContext) {
        guard let (church, w) = squareUnit(layout) else { return }
        let left = church.minX - w * 0.72
        let y = church.minY - w * 0.12
        let coats: [UInt32] = [0xc8322b, 0x2f6fb0, 0x3f8a5a, 0xe8b440]
        for k in 0..<4 {
            let x = left + CGFloat(k) * w * 0.20
            let bob = sin(time * 3 + CGFloat(k)) * w * 0.01
            drawWalker(at: CGPoint(x: x, y: y + bob), height: w * (0.48 + CGFloat(k % 2) * 0.06), dir: 1, time: 0, coat: coats[k],
                       lantern: false, sky: sky, in: ctx)
            AdventPaint.box(ctx, CGRect(x: x + w * 0.02, y: y + w * 0.22 + bob, width: w * 0.09, height: w * 0.06), w * 0.01, 0xf6f1e6)
        }
        for k in 0..<6 {
            let age = (time * 0.35 + CGFloat(k) / 6).truncatingRemainder(dividingBy: 1)
            let x = left + w * 0.3 + sin(age * 5 + CGFloat(k) * 2) * w * 0.4
            let ny = y + w * (0.6 + age * 1.2)
            let alpha = min(1, age * 5) * (1 - age)
            let tone: UInt32 = sky.lampStrength > 0.4 ? 0xfff2c4 : 0x2a2430
            AdventPaint.oval(ctx, x, ny, w * 0.08, w * 0.06, tone, alpha: alpha)
            AdventPaint.stroke(ctx, [CGPoint(x: x + w * 0.035, y: ny), CGPoint(x: x + w * 0.035, y: ny + w * 0.16)], tone, max(0.5, w * 0.018), alpha: alpha)
            if k % 2 == 0 {
                AdventPaint.stroke(ctx, [CGPoint(x: x + w * 0.035, y: ny + w * 0.16), CGPoint(x: x + w * 0.10, y: ny + w * 0.11)], tone, max(0.5, w * 0.018), alpha: alpha)
            }
        }
    }

    /// Door 18: a hot-air balloon drifting slowly across the sky above the
    /// valley, red and gold stripes, a basket, now and then a burst of flame.
    /// Set when door 18 is opened, so the balloon comes into view at once.
    static var balloonCue: CGFloat?

    private static func drawBalloon(_ layout: AdventLayout, sky: AdventSky, time: CGFloat, in ctx: CGContext) {
        let bounds = layout.bounds
        let start: CGFloat = balloonCue == nil ? 0 : 0.15
        var drift = ((time - (balloonCue ?? 0)) * 0.0045 + start).truncatingRemainder(dividingBy: 1)
        if drift < 0 { drift += 1 }
        let x = bounds.minX - bounds.width * 0.08 + drift * bounds.width * 1.16
        let y = bounds.minY + bounds.height * (0.74 + 0.02 * sin(time * 0.4))
        let r = bounds.height * 0.034
        let light = blend(sky.mountainLight, 0xffffff, 0.35)
        let envelope = CGRect(x: x - r, y: y - r * 0.6, width: r * 2, height: r * 2.3)
        ctx.saveGState()
        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: x - r * 0.42, y: y - r * 0.95))
        shape.addCurve(to: CGPoint(x: x, y: envelope.maxY), control1: CGPoint(x: x - r * 1.35, y: y - r * 0.1), control2: CGPoint(x: x - r * 1.05, y: envelope.maxY))
        shape.addCurve(to: CGPoint(x: x + r * 0.42, y: y - r * 0.95), control1: CGPoint(x: x + r * 1.05, y: envelope.maxY), control2: CGPoint(x: x + r * 1.35, y: y - r * 0.1))
        shape.closeSubpath()
        ctx.addPath(shape); ctx.clip()
        let stripes: [UInt32] = [0xc8322b, 0xe8b440, 0xc8322b, 0xf6f1e6, 0xc8322b, 0xe8b440, 0xc8322b]
        for (k, tone) in stripes.enumerated() {
            AdventPaint.box(ctx, CGRect(x: x - r * 1.4 + CGFloat(k) * r * 0.4, y: envelope.minY - r, width: r * 0.4, height: r * 4), 0,
                            multiply(tone, light))
        }
        // Rounded shading: light from the upper left.
        let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [AdventPaint.color(0xffffff, 0.25), AdventPaint.color(0x000000, 0.25)] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(shade, startCenter: CGPoint(x: x - r * 0.4, y: y + r * 0.8), startRadius: 0,
                               endCenter: CGPoint(x: x, y: y + r * 0.3), endRadius: r * 1.6, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
        // Ropes and the wicker basket.
        let basket = CGRect(x: x - r * 0.24, y: y - r * 1.45, width: r * 0.48, height: r * 0.32)
        for side: CGFloat in [-1, 1] {
            AdventPaint.stroke(ctx, [CGPoint(x: x + side * r * 0.40, y: y - r * 0.95), CGPoint(x: x + side * r * 0.22, y: basket.maxY)],
                               0x4a3a2e, max(0.4, r * 0.03))
        }
        AdventPaint.box(ctx, basket, r * 0.05, multiply(0x8a5a32, light))
        AdventPaint.box(ctx, CGRect(x: basket.minX, y: basket.maxY - r * 0.06, width: basket.width, height: r * 0.06), r * 0.02, multiply(0x5a3a22, light))
        // The burner: a short flame every few seconds.
        let burn = max(0, sin(time * 0.9)) > 0.92
        if burn || sky.lampStrength > 0.5 {
            AdventPaint.glow(ctx, at: CGPoint(x: x, y: y - r * 0.9), radius: r * 0.5, 0xffb340, burn ? 0.8 : 0.35)
            AdventPaint.oval(ctx, x, y - r * 0.82, r * 0.12, r * 0.24, 0xffd070)
        }
    }

    /// Door 22: a bonfire in the field, crossed logs, leaping flames, sparks
    /// flying up, and two children warming their hands.
    private static func drawBonfire(_ layout: AdventLayout, sky: AdventSky, time: CGFloat, in ctx: CGContext) {
        let bounds = layout.bounds
        let foot = CGPoint(x: bounds.minX + bounds.width * 0.30, y: bounds.minY + bounds.height * 0.052)
        let u = bounds.height * 0.032
        AdventPaint.pool(ctx, at: foot, width: u * 7, flat: 0.25, 0xffb060, 0.30 + 0.35 * sky.lampStrength)
        AdventPaint.oval(ctx, foot.x, foot.y, u * 1.6, u * 0.36, blend(0x3a3f48, sky.horizon, 0.2))
        // Stones round the fire.
        for k in 0..<7 {
            let a = CGFloat(k) / 7 * .pi * 2
            AdventPaint.oval(ctx, foot.x + cos(a) * u * 0.8, foot.y + sin(a) * u * 0.18, u * 0.28, u * 0.16, multiply(0x8a8f96, sky.valleyLight))
        }
        // Crossed logs.
        for side: CGFloat in [-1, 1] {
            AdventPaint.stroke(ctx, [CGPoint(x: foot.x - side * u * 0.6, y: foot.y), CGPoint(x: foot.x + side * u * 0.15, y: foot.y + u * 0.55)],
                               0x5a3a22, max(1, u * 0.16))
        }
        // Flames: three tongues swaying, each with a hot core.
        for k in 0..<3 {
            let sway = sin(time * 7 + CGFloat(k) * 2.1) * u * 0.10
            let tall = u * (1.0 + 0.25 * sin(time * 9 + CGFloat(k)) - abs(CGFloat(k) - 1) * 0.3)
            let base = CGPoint(x: foot.x + (CGFloat(k) - 1) * u * 0.28, y: foot.y + u * 0.15)
            let flame = CGMutablePath()
            flame.move(to: CGPoint(x: base.x - u * 0.22, y: base.y))
            flame.addQuadCurve(to: CGPoint(x: base.x + sway, y: base.y + tall), control: CGPoint(x: base.x - u * 0.25, y: base.y + tall * 0.6))
            flame.addQuadCurve(to: CGPoint(x: base.x + u * 0.22, y: base.y), control: CGPoint(x: base.x + u * 0.25, y: base.y + tall * 0.6))
            flame.closeSubpath()
            ctx.setFillColor(AdventPaint.color(0xff8a2a)); ctx.addPath(flame); ctx.fillPath()
            AdventPaint.oval(ctx, base.x + sway * 0.4, base.y + tall * 0.3, u * 0.18, tall * 0.45, 0xffd070)
        }
        AdventPaint.glow(ctx, at: CGPoint(x: foot.x, y: foot.y + u * 0.6), radius: u * 2.2, 0xffa040, 0.45 + 0.3 * sky.lampStrength)
        // Sparks flying up.
        for k in 0..<10 {
            let age = (time * 0.6 + CGFloat(k) / 10).truncatingRemainder(dividingBy: 1)
            let sx = foot.x + sin(age * 7 + CGFloat(k) * 1.9) * u * 0.6
            let sy = foot.y + u * (0.8 + age * 2.6)
            AdventPaint.oval(ctx, sx, sy, u * 0.07, u * 0.07, 0xffd070, alpha: 1 - age)
        }
        // Two children warming their hands.
        drawWalker(at: CGPoint(x: foot.x - u * 1.6, y: foot.y - u * 0.1), height: u * 1.5, dir: 1, time: 0, coat: 0x2f6fb0,
                   lantern: false, sky: sky, in: ctx)
        drawWalker(at: CGPoint(x: foot.x + u * 1.7, y: foot.y - u * 0.05), height: u * 1.4, dir: -1, time: 0, coat: 0xc8322b,
                   lantern: false, sky: sky, in: ctx)
    }

    /// Where each gift appears, for the trail of light that leads the eye
    /// from the opened door to it.
    static func giftFocus(_ gift: AdventGift, layout: AdventLayout) -> CGPoint {
        let b = layout.bounds
        let church = layout.chalets.first(where: { $0.kind == .church })?.base ?? CGRect(x: b.midX, y: b.midY, width: 40, height: 40)
        let w = church.width * 0.9
        let near = layout.roads.count == 3 ? layout.roads[2] : nil
        func onNearRoad(_ fx: CGFloat) -> CGPoint {
            let x = b.minX + b.width * fx
            if let near, let g = roadPoint(near, at: x) { return CGPoint(x: x, y: g.y + near.width * 0.6) }
            return CGPoint(x: x, y: b.minY + b.height * 0.2)
        }
        switch gift {
        case .horseSleigh, .tractor: return onNearRoad(0.08)
        case .sledgeChild: return onNearRoad(0.5)
        case .lanterns, .garland:
            if let lamp = near?.lamps.dropFirst((near?.lamps.count ?? 0) / 2).first { return CGPoint(x: lamp.x, y: lamp.y + (near?.width ?? 10) * 2) }
            return onNearRoad(0.5)
        case .smoke, .starsInWindows:
            if let house = layout.chalets.filter({ $0.depth == 2 }).sorted(by: { abs($0.base.midX - b.midX) < abs($1.base.midX - b.midX) }).first {
                return CGPoint(x: house.base.midX, y: house.base.maxY + house.roof * (gift == .smoke ? 1.4 : 0.2))
            }
            return CGPoint(x: b.midX, y: b.midY)
        case .bells, .star: return CGPoint(x: church.midX, y: church.maxY + (gift == .star ? church.height * 1.3 : -church.height * 0.1))
        case .pond: return CGPoint(x: layout.lake.midX, y: layout.lake.midY)
        case .tree: return CGPoint(x: layout.tree.x, y: layout.tree.y + layout.treeSize * 0.6)
        case .snowmanFamily: return CGPoint(x: b.minX + b.width * 0.62, y: b.minY + b.height * 0.07)
        case .cableCar, .torchRun:
            if let run = layout.pistes.first { return along(run, 0.5) }
            return CGPoint(x: b.midX, y: b.minY + b.height * 0.5)
        case .market: return CGPoint(x: church.maxX + w * 1.95, y: church.minY + w * 0.8)
        case .crib: return CGPoint(x: cribFoot(layout).x, y: cribFoot(layout).y + b.height * 0.06)
        case .choir: return CGPoint(x: church.minX - w * 0.42, y: church.minY + w * 0.4)
        case .balloon: return CGPoint(x: b.minX + b.width * 0.11, y: b.minY + b.height * 0.75)
        case .bonfire: return CGPoint(x: b.minX + b.width * 0.30, y: b.minY + b.height * 0.07)
        case .flurry, .aurora, .rudolph, .sleigh: return CGPoint(x: b.midX, y: b.minY + b.height * 0.82)
        case .finale, .warmth: return CGPoint(x: b.midX, y: b.midY)
        }
    }

    /// The brighter stars scintillate: each flares up now and then at its
    /// own pace, as stars do in cold, clear mountain air. Only stars above
    /// the mountains and clear of clouds, since the backdrop under them is
    /// already finished.
    private static func drawTwinkle(_ layout: AdventLayout, sky: AdventSky, time: CGFloat, in ctx: CGContext) {
        let bounds = layout.bounds
        let skyline = layout.horizon
        guard skyline.count > 1 else { return }
        func horizon(at x: CGFloat) -> CGFloat {
            let position = (x - skyline[0].x) / max(0.001, skyline[skyline.count - 1].x - skyline[0].x) * CGFloat(skyline.count - 1)
            let left = max(0, min(skyline.count - 2, Int(position)))
            let f = max(0, min(1, position - CGFloat(left)))
            return skyline[left].y + (skyline[left + 1].y - skyline[left].y) * f
        }
        for (number, star) in layout.stars.enumerated() where star.size > 1.6 {
            let p = star.point
            guard p.y > horizon(at: p.x) + star.size * 3 else { continue }
            if layout.clouds.contains(where: { abs(p.x - $0.center.x) < $0.width * 0.6 && abs(p.y - $0.center.y) < $0.height * 0.9 }) {
                continue
            }
            let height = (p.y - bounds.minY) / bounds.height
            let fade = min(1, max(0, (height - 0.42) / 0.3))
            let speed = 1.1 + AdventLayout.noise(number, 770) * 2.4
            let phase = AdventLayout.noise(number, 771) * 6.28
            let wave = sin(time * speed + phase) * 0.6 + sin(time * speed * 2.7 + phase * 1.3) * 0.4
            let alpha = max(0, wave) * 0.55 * sky.starlight * fade
            guard alpha > 0.02 else { continue }
            let hue = AdventLayout.noise(number, 762)
            let tint: UInt32 = hue < 0.15 ? 0xffe2b8 : (hue < 0.45 ? 0xcfe0ff : 0xf4f8ff)
            AdventPaint.glow(ctx, at: p, radius: star.size * 2.6, tint, alpha * 0.55)
            AdventPaint.oval(ctx, p.x, p.y, star.size * 0.85, star.size * 0.85, 0xffffff, alpha: alpha)
        }
    }

    /// A point a fraction of the way down a run, measured along its length.
    static func along(_ run: [CGPoint], _ t: CGFloat) -> CGPoint {
        guard run.count > 1 else { return run.first ?? .zero }
        let position = min(max(t, 0), 1) * CGFloat(run.count - 1)
        let index = min(run.count - 2, Int(position))
        let f = position - CGFloat(index)
        return CGPoint(x: run[index].x + (run[index + 1].x - run[index].x) * f,
                       y: run[index].y + (run[index + 1].y - run[index].y) * f)
    }

    /// Skiers carving down the runs by day; on Advent evenings a torchlight
    /// descent winds down the first run. Nothing shows where the near range
    /// stands in front of the slope.
    private static func drawSkiers(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky,
                                   time: CGFloat, in ctx: CGContext) {
        guard layout.ridges.count == 3, !layout.pistes.isEmpty else { return }
        let near = layout.ridges[2]
        let size = layout.bounds.height * 0.013
        func visible(_ p: CGPoint) -> Bool { p.y > AdventLayout.height(of: near, at: p.x) + size * 0.3 }
        if season.has(.torchRun) {
            // Door 20: a line of skiers with torches winding down the left
            // run. After dark only the flames show; by day the skiers too.
            let run = layout.pistes[0]
            let dark = sky.lampStrength > 0.55
            for torch in 0..<18 {
                let t = (time * 0.004 + CGFloat(torch) * 0.022).truncatingRemainder(dividingBy: 1)
                let p = along(run, t)
                guard visible(p) else { continue }
                let flicker = 0.8 + 0.2 * sin(time * 11 + CGFloat(torch) * 1.7)
                if !dark {
                    // A small skier in a red jacket holding the torch up.
                    AdventPaint.stroke(ctx, [CGPoint(x: p.x - size * 0.35, y: p.y - size * 0.55), CGPoint(x: p.x + size * 0.35, y: p.y - size * 0.62)],
                                       0x23262e, max(0.4, size * 0.08))
                    AdventPaint.stroke(ctx, [CGPoint(x: p.x, y: p.y - size * 0.55), CGPoint(x: p.x, y: p.y - size * 0.05)],
                                       0xc8322b, max(0.6, size * 0.2))
                    AdventPaint.oval(ctx, p.x, p.y + size * 0.05, size * 0.2, size * 0.2, 0xf0c7a4)
                }
                AdventPaint.glow(ctx, at: CGPoint(x: p.x + size * 0.15, y: p.y + size * 0.35), radius: size * (dark ? 0.9 : 0.7), 0xffb05a,
                                 (dark ? 0.32 * sky.lampStrength : 0.45) * flicker)
                AdventPaint.oval(ctx, p.x + size * 0.15, p.y + size * 0.42, size * 0.22, size * 0.32, 0xffd070)
            }
            if dark { return }
        }
        // Skiers come down by day and in the evening too; after dark each
        // wears a small headlamp.
        let night = sky.lampStrength > 0.3
        let jackets: [UInt32] = [0xc8322b, 0x2f6fb0, 0xe8b440, 0x3f8a5a]
        // The runs start right beside the top stations. A skier whose skis
        // are farther up the slope than the hall's floor is behind it and
        // hidden by the hall; one below it passes in front.
        let unit = layout.bounds.height * 0.02
        let halls = gondolas(layout).map { way -> CGRect in
            let wide = unit * 1.1
            return CGRect(x: way.top.x - wide * 0.62, y: way.top.y - unit * 0.06, width: wide * 1.24, height: unit * 0.98)
        }
        for skier in 0..<4 {
            let run = layout.pistes[skier % layout.pistes.count]
            let speed = 0.028 + AdventLayout.noise(skier, 660) * 0.010
            // Spread out along the run so nobody skis on top of anybody else.
            let cycle = (time * speed + CGFloat(skier / 2) * 0.47 + AdventLayout.noise(skier, 661) * 0.1)
                .truncatingRemainder(dividingBy: 1)
            // They push off just below the top station, not out of its roof,
            // and fade in over the first few metres.
            let t = 0.06 + cycle * 0.94
            let p = along(run, t)
            guard visible(p) else { continue }
            ctx.saveGState()
            defer { ctx.restoreGState() }
            ctx.setAlpha(min(1, cycle / 0.03))
            if let hall = halls.first(where: { p.y > $0.minY + unit * 0.06 && abs(p.x - $0.midX) < $0.width }) {
                let outside = CGMutablePath()
                outside.addRect(layout.bounds)
                outside.addRect(hall)
                ctx.addPath(outside)
                ctx.clip(using: .evenOdd)
            }
            let ahead = along(run, min(1, t + 0.01))
            let dir: CGFloat = ahead.x >= p.x ? 1 : -1
            // The skis follow the track, so they swing round with every turn.
            let heading = CGPoint(x: ahead.x - p.x, y: ahead.y - p.y)
            let flat = max(0.001, hypot(heading.x, heading.y * 0.35))
            let along2 = CGPoint(x: heading.x / flat, y: heading.y * 0.35 / flat)
            // A skier in a crouch: skis along the track, knees bent forward,
            // a bright jacket leaning down the hill, arms out with poles,
            // a knitted hat and goggles.
            // A faint shadow on the piste under the skis, by day.
            if sky.daylight > 0.2 {
                AdventPaint.pool(ctx, at: CGPoint(x: p.x, y: p.y - size * 0.04), width: size * 1.4, flat: 0.26,
                                 0x2a3442, 0.24 * sky.daylight)
            }
            let ski = size * 0.55
            AdventPaint.stroke(ctx, [CGPoint(x: p.x - along2.x * ski * 0.9, y: p.y - along2.y * ski * 0.9),
                                     CGPoint(x: p.x + along2.x * ski, y: p.y + along2.y * ski)], 0x23262e, max(0.5, size * 0.08))
            AdventPaint.stroke(ctx, [CGPoint(x: p.x + along2.x * ski * 0.9, y: p.y + along2.y * ski * 0.9),
                                     CGPoint(x: p.x + along2.x * ski * 1.05, y: p.y + along2.y * ski + size * 0.08)], 0x23262e, max(0.5, size * 0.07))
            let knee = CGPoint(x: p.x + dir * size * 0.16, y: p.y + size * 0.26)
            let hip = CGPoint(x: p.x - dir * size * 0.06, y: p.y + size * 0.44)
            AdventPaint.stroke(ctx, [CGPoint(x: p.x, y: p.y + size * 0.04), knee, hip], 0x2b2f3a, max(0.6, size * 0.15))
            let shoulder = CGPoint(x: p.x + dir * size * 0.12, y: p.y + size * 0.80)
            AdventPaint.stroke(ctx, [hip, shoulder], jackets[skier], max(0.8, size * 0.26))
            let hand = CGPoint(x: shoulder.x + dir * size * 0.30, y: shoulder.y - size * 0.22)
            AdventPaint.stroke(ctx, [shoulder, hand], blend(jackets[skier], 0x000000, 0.15), max(0.5, size * 0.1))
            AdventPaint.stroke(ctx, [hand, CGPoint(x: hand.x + dir * size * 0.12, y: p.y + size * 0.02)], 0x55606e, max(0.4, size * 0.04))
            let back = CGPoint(x: shoulder.x - dir * size * 0.22, y: shoulder.y - size * 0.25)
            AdventPaint.stroke(ctx, [shoulder, back], blend(jackets[skier], 0x000000, 0.25), max(0.5, size * 0.09))
            AdventPaint.stroke(ctx, [back, CGPoint(x: back.x - dir * size * 0.18, y: p.y + size * 0.04)], 0x55606e, max(0.4, size * 0.04))
            let head = CGPoint(x: shoulder.x + dir * size * 0.08, y: shoulder.y + size * 0.20)
            AdventPaint.oval(ctx, head.x, head.y, size * 0.22, size * 0.22, 0xf0c7a4)
            AdventPaint.oval(ctx, head.x, head.y + size * 0.07, size * 0.23, size * 0.14, jackets[(skier + 1) % 4])
            AdventPaint.oval(ctx, head.x - dir * size * 0.02, head.y + size * 0.17, size * 0.08, size * 0.08, 0xf6f1e6)
            AdventPaint.box(ctx, CGRect(x: head.x + (dir > 0 ? 0 : -size * 0.13), y: head.y - size * 0.02, width: size * 0.13, height: size * 0.06),
                            size * 0.02, 0x2a3a5a)
            if night {
                let lamp = CGPoint(x: head.x + dir * size * 0.1, y: head.y + size * 0.04)
                AdventPaint.glow(ctx, at: lamp, radius: size * 0.9, 0xfff1c8, 0.55 * sky.lampStrength)
                AdventPaint.oval(ctx, lamp.x, lamp.y, size * 0.08, size * 0.08, 0xffffff)
                // A pool of light on the snow ahead.
                AdventPaint.pool(ctx, at: CGPoint(x: p.x + along2.x * size * 0.9, y: p.y + along2.y * size * 0.9),
                                 width: size * 1.6, flat: 0.35, 0xffe6b0, 0.40 * sky.lampStrength)
            }
            // A puff of powder thrown up behind.
            AdventPaint.glow(ctx, at: CGPoint(x: p.x - dir * size * 0.7, y: p.y + size * 0.1), radius: size * 0.6, 0xffffff, night ? 0.2 : 0.5)
        }
    }

    static func isAnimated(_ door: AdventDoor, season: AdventSeason) -> Bool {
        season.canOpen(door.day) || (season.isOpen(door.day) && ((door.day * 5) % 8 == 1 || door.day == 24))
    }

    // MARK: Life in the valley

    /// The point on a road at a given x, following its curve.
    static func roadPoint(_ road: AdventLayout.Road, at x: CGFloat) -> CGPoint? {
        let points = road.points
        guard let first = points.first, let last = points.last, x >= first.x, x <= last.x else { return nil }
        for index in 1..<points.count where points[index].x >= x {
            let a = points[index - 1], b = points[index]
            let t = (x - a.x) / max(0.001, b.x - a.x)
            return CGPoint(x: x, y: a.y + (b.y - a.y) * t)
        }
        return last
    }

    /// Villagers out on the roads, a child with a sledge and now and then a
    /// horse sleigh. They live on the near road, where nothing stands in front
    /// of them; on the middle road they disappear behind the near houses.
    /// The near road takes turns: seventy seconds for the horse sleigh, then
    /// seventy for the tractor with the Christmas trees, each crossing the
    /// whole screen. `t` runs from 0 to 1 along a crossing.
    static let roadPeriod: CGFloat = 140, roadCrossing: CGFloat = 70
    /// Shifts the round so a sleigh can set off the moment its door opens.
    static var roadShift: CGFloat = 0

    static func roadTraffic(season: AdventSeason, time: CGFloat)
        -> (sleigh: (t: CGFloat, dir: CGFloat)?, tractor: (t: CGFloat, dir: CGFloat)?) {
        let local = time - roadShift
        var cycle = local.truncatingRemainder(dividingBy: roadPeriod)
        if cycle < 0 { cycle += roadPeriod }
        let round = Int((local - cycle) / roadPeriod)
        let even = round % 2 == 0
        if cycle < roadCrossing {
            guard season.has(.horseSleigh) else { return (nil, nil) }
            return ((cycle / roadCrossing, even ? 1 : -1), nil)
        }
        guard season.has(.tractor) else { return (nil, nil) }
        return (nil, ((cycle - roadCrossing) / (roadPeriod - roadCrossing), even ? -1 : 1))
    }

    /// Door 1 has just been opened: if the road is waiting for the sleigh,
    /// it sets off now instead of whenever its turn would come round. If the
    /// tractor is on its way, the sleigh follows as soon as it has passed.
    static func cueHorseSleigh(at time: CGFloat) {
        var cycle = (time - roadShift).truncatingRemainder(dividingBy: roadPeriod)
        if cycle < 0 { cycle += roadPeriod }
        if cycle < roadCrossing { roadShift += cycle }
    }

    private static func drawLife(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky,
                                 time: CGFloat, in ctx: CGContext) {
        guard layout.roads.count == 3 else { return }
        let bounds = layout.bounds
        let span = bounds.width + 160
        let nightLamp = sky.lampStrength > 0.5
        func position(_ index: Int, speed: CGFloat, salt: Int) -> (x: CGFloat, dir: CGFloat) {
            let dir: CGFloat = AdventLayout.noise(index, salt) > 0.5 ? 1 : -1
            let start = AdventLayout.noise(index, salt + 1) * span
            let travelled = (start + time * speed).truncatingRemainder(dividingBy: span)
            let x = dir > 0 ? bounds.minX - 80 + travelled : bounds.maxX + 80 - travelled
            return (x, dir)
        }
        let coats: [UInt32] = [0xb23a32, 0x2f5f8a, 0x3f7a4e, 0x7a4a2e, 0x5b3f78, 0xc77a2a]
        let near = layout.roads[2], middle = layout.roads[1]
        // Middle road: small figures, hidden where a near house stands in front.
        for index in 0..<3 {
            let (x, dir) = position(index, speed: 4 + AdventLayout.noise(index, 610) * 3, salt: 600)
            guard let ground = roadPoint(middle, at: x) else { continue }
            let height = middle.width * 0.95
            let foot = CGPoint(x: x, y: ground.y - middle.width * 0.1)
            drawWalker(at: foot, height: height, dir: dir, time: time + CGFloat(index) * 0.7,
                       coat: coats[(index + 3) % coats.count], lantern: nightLamp && index == 1, sky: sky, in: ctx)
        }
        let scale = max(1, abs(ctx.ctm.a))
        let layers = frontLayers(layout, season: season, sky: sky, scale: scale)
        if let middleFront = layers?.middle, !middleFront.rect.isEmpty { ctx.draw(middleFront.image, in: middleFront.rect) }
        // Doors that move are drawn now: above the middle layer (no door is
        // ever behind a nearer house) and below the people on the near road.
        for door in layout.doors where isAnimated(door, season: season) {
            drawDoor(door, season: season, time: time, pointer: nil, dusk: sky.lampStrength, in: ctx)
        }
        // Everything on the near road and the pond is collected first and
        // then drawn from back to front, so people pass in front of each
        // other instead of melting into one another. Each has its own lane.
        var figures: [(depth: CGFloat, draw: () -> Void)] = []
        let lanes: [CGFloat] = [-0.12, 0.10, -0.36, 0.20, -0.24, 0.0]
        // Near road: villagers, more of them as Advent goes on.
        let walkers = 3 + min(3, season.openedCount / 6)
        for index in 0..<walkers {
            // Spread out along the road, each at their own pace, so they meet
            // and pass now and then instead of walking glued together.
            let dir: CGFloat = index % 2 == 0 ? 1 : -1
            let start = (CGFloat(index) / CGFloat(walkers) + AdventLayout.noise(index, 631) * 0.08) * span
            let travelled = (start + time * (6 + CGFloat(index) * 1.4)).truncatingRemainder(dividingBy: span)
            let x = dir > 0 ? bounds.minX - 80 + travelled : bounds.maxX + 80 - travelled
            guard let ground = roadPoint(near, at: x) else { continue }
            let foot = CGPoint(x: x, y: ground.y + lanes[index % lanes.count] * near.width)
            figures.append((foot.y, {
                drawWalker(at: foot, height: near.width * 0.72, dir: dir,
                           time: time + CGFloat(index) * 1.3, coat: coats[index % coats.count],
                           lantern: nightLamp && index % 2 == 0, sky: sky, in: ctx)
            }))
        }
        // A child pulling a sledge, on the near edge of the road: door 4.
        if season.has(.sledgeChild) {
            let (x, dir) = position(0, speed: 9, salt: 650)
            if let ground = roadPoint(near, at: x) {
                let foot = CGPoint(x: x, y: ground.y - near.width * 0.42)
                let unit = near.width
                figures.append((foot.y, {
                    let sledge = CGPoint(x: x - dir * unit * 0.85, y: foot.y)
                    AdventPaint.stroke(ctx, [CGPoint(x: x - dir * unit * 0.05, y: foot.y + unit * 0.24),
                                             CGPoint(x: sledge.x + dir * unit * 0.22, y: sledge.y + unit * 0.08)],
                                       0x6a4a33, max(0.5, unit * 0.025))
                    // Runners curling up at the front, slats on top.
                    AdventPaint.stroke(ctx, [CGPoint(x: sledge.x - unit * 0.24, y: sledge.y),
                                             CGPoint(x: sledge.x + unit * 0.2, y: sledge.y),
                                             CGPoint(x: sledge.x + unit * 0.26, y: sledge.y + unit * 0.06)].map {
                                                 CGPoint(x: sledge.x + ($0.x - sledge.x) * dir, y: $0.y) },
                                       0x7a4a2e, max(0.6, unit * 0.035))
                    AdventPaint.box(ctx, CGRect(x: sledge.x - unit * 0.22, y: sledge.y + unit * 0.06, width: unit * 0.42,
                                                height: unit * 0.06), unit * 0.02, 0xb07a48)
                    drawWalker(at: foot, height: unit * 0.5, dir: dir, time: time * 1.4, coat: 0xd9493a,
                               lantern: false, sky: sky, in: ctx)
                }))
            }
        }
        // The horse sleigh keeps to the far side of the road. It belongs to
        // door 1: before that its half of the round stays empty.
        let road = roadTraffic(season: season, time: time)
        if let sleigh = road.sleigh {
            let t = sleigh.t, dir = sleigh.dir
            let x = dir > 0 ? bounds.minX - 120 + (bounds.width + 240) * t : bounds.maxX + 120 - (bounds.width + 240) * t
            if let ground = roadPoint(near, at: x) {
                let at = CGPoint(x: x, y: ground.y + near.width * 0.30)
                figures.append((at.y, {
                    drawHorseSleigh(at: at, unit: near.width, dir: dir, time: time, sky: sky, in: ctx)
                }))
            }
        }
        if let tractor = road.tractor {
            // In between, the farmer brings the Christmas trees down from the
            // forest: a red tractor with a trailer full of firs, fairy lights
            // blinking along it, coming the other way.
            let t = tractor.t, dir = tractor.dir
            let x = dir > 0 ? bounds.minX - 160 + (bounds.width + 320) * t : bounds.maxX + 160 - (bounds.width + 320) * t
            if let ground = roadPoint(near, at: x) {
                let at = CGPoint(x: x, y: ground.y + near.width * 0.30)
                figures.append((at.y, {
                    drawTreeTractor(at: at, unit: near.width, dir: dir, time: time, sky: sky, in: ctx)
                }))
            }
        }
        // The village tree stands on the near road: people pass in front of
        // it and behind it, so it is sorted in with them.
        figures.append((layout.tree.y, {
            if let tree = layers?.tree, !tree.rect.isEmpty { ctx.draw(tree.image, in: tree.rect) }
            drawTree(layout, season: season, time: time, in: ctx)
        }))
        for figure in figures.sorted(by: { $0.depth > $1.depth }) { figure.draw() }
        // Fence, lanterns and the big edge firs stand in front of everyone.
        if let front = layers?.front, !front.rect.isEmpty { ctx.draw(front.image, in: front.rect) }
        figures.removeAll()
        // Skaters on the pond once it has frozen over: one pace, one
        // direction, a third of a lap apart, so they never collide. The pond
        // lies in front of the road and its fence.
        if season.has(.pond) {
            let lake = layout.lake
            let colours: [UInt32] = [0xd9493a, 0x2f6fb0, 0x8a4fb3]
            for skater in 0..<3 {
                let angle = time * 0.3 + CGFloat(skater) * 2.094
                let rx = lake.width * (0.30 - CGFloat(skater) * 0.04)
                let ry = lake.height * (0.24 - CGFloat(skater) * 0.02)
                let foot = CGPoint(x: lake.midX + cos(angle) * rx, y: lake.midY - lake.height * 0.08 + sin(angle) * ry)
                let dir: CGFloat = -sin(angle) >= 0 ? 1 : -1
                let height = near.width * (skater == 2 ? 0.5 : 0.68)
                figures.append((foot.y, {
                    // Skating, not walking: a long glide held on one leg, a
                    // quick change of feet, the body leaning into the push.
                    let push = sin(time * 0.9 + CGFloat(skater) * 1.7)
                    let glide = max(-0.999, min(0.999, push * 1.8))
                    let pose = asin(glide) / 5.2
                    // The skater mirrored in the smooth ice: upside down under
                    // the blades, squashed, faint, kept on the ice. Drawn as
                    // one group so overlapping parts do not show darker.
                    ctx.saveGState()
                    ctx.addEllipse(in: lake)
                    ctx.clip()
                    ctx.setAlpha(0.22)
                    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                    ctx.translateBy(x: foot.x, y: foot.y - height * 0.02)
                    ctx.scaleBy(x: 1, y: -0.55)
                    ctx.rotate(by: -dir * 0.14)
                    ctx.translateBy(x: -foot.x, y: -foot.y)
                    drawWalker(at: foot, height: height, dir: dir, time: pose,
                               coat: colours[skater], lantern: false, sky: sky, shadow: false, in: ctx)
                    ctx.endTransparencyLayer()
                    ctx.restoreGState()
                    ctx.saveGState()
                    ctx.translateBy(x: foot.x, y: foot.y)
                    ctx.rotate(by: -dir * 0.14)
                    ctx.translateBy(x: -foot.x, y: -foot.y)
                    drawWalker(at: foot, height: height, dir: dir, time: pose,
                               coat: colours[skater], lantern: false, sky: sky, in: ctx)
                    // A blade under each boot.
                    for side: CGFloat in [-1, 1] {
                        let toe = foot.x + glide * side * height * 0.12
                        AdventPaint.stroke(ctx, [CGPoint(x: toe - dir * height * 0.06, y: foot.y - height * 0.018),
                                                 CGPoint(x: toe + dir * height * 0.10, y: foot.y - height * 0.018)],
                                           0xd5dde6, max(0.5, height * 0.022))
                    }
                    ctx.restoreGState()
                }))
            }
        }
        for figure in figures.sorted(by: { $0.depth > $1.depth }) { figure.draw() }
    }

    /// Previews draw single figures large to check them.
    static func debugWalker(at foot: CGPoint, height: CGFloat, dir: CGFloat, time: CGFloat, coat: UInt32, lantern: Bool,
                            sky: AdventSky, in ctx: CGContext) {
        drawWalker(at: foot, height: height, dir: dir, time: time, coat: coat, lantern: lantern, sky: sky, in: ctx)
    }
    static func debugShootingStar(_ layout: AdventLayout, time: CGFloat, in ctx: CGContext) {
        drawShootingStar(layout, time: time, in: ctx)
    }
    static func debugSleigh(at ground: CGPoint, unit: CGFloat, dir: CGFloat, time: CGFloat, sky: AdventSky, in ctx: CGContext) {
        drawHorseSleigh(at: ground, unit: unit, dir: dir, time: time, sky: sky, in: ctx)
    }

    private static func drawWalker(at foot: CGPoint, height: CGFloat, dir: CGFloat, time: CGFloat,
                                   coat: UInt32, lantern: Bool, sky: AdventSky, shadow: Bool = true, in ctx: CGContext) {
        let u = height
        // A soft contact shadow on the snow under the boots, so the figure
        // stands on the ground instead of floating over it: clear by day,
        // only a breath of it at night.
        if shadow {
            AdventPaint.pool(ctx, at: CGPoint(x: foot.x, y: foot.y + u * 0.006), width: u * 0.56, flat: 0.24,
                             0x2a3442, 0.18 + 0.34 * sky.daylight)
        }
        let stride = sin(time * 5.2)
        let bob = abs(cos(time * 5.2)) * u * 0.02
        let hip = CGPoint(x: foot.x, y: foot.y + u * 0.36 + bob)
        let trousers: UInt32 = 0x2f3440
        let coatTone = blend(coat, sky.horizon, 0.12)
        let coatDark = blend(coatTone, 0x000000, 0.28)
        let skin: UInt32 = 0xf0c7a4
        // Legs swing in opposite phase: knee bent on the leg coming forward,
        // boots with a little heel.
        // The leg moving forward is the swing leg: it lifts its boot most as
        // it passes under the body and bends its knee forward; the leg on
        // the ground stays straight. At full stride both boots are down.
        let pace = cos(time * 5.2)
        for side: CGFloat in [-1, 1] {
            let swing = stride * side * u * 0.12
            let swingPhase = max(0, dir * side * pace)
            let lift = swingPhase * u * 0.06
            // The lifted boot trails behind the knee, toe pointing down a little.
            let toe = CGPoint(x: foot.x + swing - dir * u * 0.04 * swingPhase, y: foot.y + lift)
            let knee = CGPoint(x: (hip.x + toe.x) / 2 + dir * u * 0.065 * swingPhase,
                               y: (hip.y + toe.y) / 2 + u * 0.01)
            let tone = side < 0 ? blend(trousers, 0x000000, 0.3) : trousers
            // The trouser leg ends inside the boot, not below it.
            AdventPaint.stroke(ctx, [hip, knee, CGPoint(x: toe.x, y: toe.y + u * 0.05)], tone, max(0.7, u * 0.085))
            let boot = CGMutablePath()
            boot.move(to: CGPoint(x: toe.x - dir * u * 0.05, y: toe.y - u * 0.01))
            boot.addLine(to: CGPoint(x: toe.x + dir * u * 0.08, y: toe.y - u * 0.01))
            boot.addQuadCurve(to: CGPoint(x: toe.x + dir * u * 0.02, y: toe.y + u * 0.055),
                              control: CGPoint(x: toe.x + dir * u * 0.08, y: toe.y + u * 0.04))
            boot.addLine(to: CGPoint(x: toe.x - dir * u * 0.05, y: toe.y + u * 0.05))
            boot.closeSubpath()
            ctx.setFillColor(AdventPaint.color(0x2a211d))
            ctx.addPath(boot)
            ctx.fillPath()
            if u > 18 {
                // A lighter rubber sole and a dusting of snow on the toe cap.
                AdventPaint.stroke(ctx, [CGPoint(x: toe.x - dir * u * 0.05, y: toe.y - u * 0.004),
                                         CGPoint(x: toe.x + dir * u * 0.08, y: toe.y - u * 0.004)], 0x5a4c44, max(0.5, u * 0.014))
                AdventPaint.oval(ctx, toe.x + dir * u * 0.045, toe.y + u * 0.032, u * 0.04, u * 0.016, 0xeef4f8, alpha: 0.85)
            }
        }
        // The arm on the far side swings behind the coat.
        let shoulder = CGPoint(x: foot.x + dir * u * 0.02, y: foot.y + u * 0.69 + bob)
        let farHand = CGPoint(x: shoulder.x + stride * u * 0.11 - dir * u * 0.02, y: foot.y + u * 0.45 + bob)
        AdventPaint.stroke(ctx, [CGPoint(x: shoulder.x - dir * u * 0.03, y: shoulder.y), farHand], coatDark, max(0.6, u * 0.075))
        AdventPaint.oval(ctx, farHand.x, farHand.y, u * 0.06, u * 0.06, blend(coat, 0x1a1a1a, 0.5))
        // Coat, slightly flared, with a shaded back half, a hem band and buttons.
        let coatPath = CGMutablePath()
        coatPath.move(to: CGPoint(x: foot.x - u * 0.15, y: foot.y + u * 0.30 + bob))
        coatPath.addLine(to: CGPoint(x: foot.x - u * 0.105, y: foot.y + u * 0.72 + bob))
        coatPath.addQuadCurve(to: CGPoint(x: foot.x + u * 0.105, y: foot.y + u * 0.72 + bob),
                              control: CGPoint(x: foot.x, y: foot.y + u * 0.78 + bob))
        coatPath.addLine(to: CGPoint(x: foot.x + u * 0.15, y: foot.y + u * 0.30 + bob))
        coatPath.closeSubpath()
        ctx.setFillColor(AdventPaint.color(coatTone))
        ctx.addPath(coatPath)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(coatPath)
        ctx.clip()
        ctx.setFillColor(AdventPaint.color(coatDark, 0.55))
        ctx.fill(CGRect(x: dir > 0 ? foot.x - u * 0.2 : foot.x + u * 0.04, y: foot.y, width: u * 0.16, height: u))
        AdventPaint.box(ctx, CGRect(x: foot.x - u * 0.2, y: foot.y + u * 0.30 + bob, width: u * 0.4, height: u * 0.045),
                        0, blend(coatTone, 0xffffff, 0.35))
        ctx.restoreGState()
        if u > 18 {
            // A pocket with its flap on the near side of the coat.
            let pocket = CGRect(x: foot.x - dir * u * 0.04 - u * 0.04, y: foot.y + u * 0.40 + bob, width: u * 0.08, height: u * 0.06)
            AdventPaint.box(ctx, pocket, u * 0.01, blend(coatTone, 0x000000, 0.10))
            AdventPaint.box(ctx, CGRect(x: pocket.minX - u * 0.005, y: pocket.maxY - u * 0.018, width: pocket.width + u * 0.01, height: u * 0.02),
                            u * 0.006, coatDark)
            for button in 0..<3 {
                AdventPaint.oval(ctx, foot.x + dir * u * 0.045, foot.y + u * (0.42 + CGFloat(button) * 0.09) + bob,
                                 u * 0.025, u * 0.025, blend(coatDark, 0x000000, 0.3))
            }
        }
        // Scarf round the neck, its tail lifting a little behind in the wind.
        let scarves: [UInt32] = [0xf2e6c8, 0xd9a43a, 0xc23b32, 0x3f6f9a, 0xf2e6c8]
        let scarf = scarves[Int((coat % 97)) % scarves.count]
        AdventPaint.box(ctx, CGRect(x: foot.x - u * 0.11, y: foot.y + u * 0.705 + bob, width: u * 0.22, height: u * 0.07),
                        u * 0.03, scarf)
        let flutter = 0.02 * sin(time * 7)
        AdventPaint.stroke(ctx, [CGPoint(x: foot.x - dir * u * 0.08, y: foot.y + u * 0.72 + bob),
                                 CGPoint(x: foot.x - dir * u * 0.12, y: foot.y + u * (0.67 + flutter) + bob)],
                           scarf, max(0.5, u * 0.035))
        // Head with a hint of a face: cheek, eye, nose in profile.
        let head = CGPoint(x: foot.x + dir * u * 0.02, y: foot.y + u * 0.855 + bob)
        let hairs: [UInt32] = [0x5a3a24, 0x2c211c, 0xb98a52, 0x8a4b2a]
        let hair = hairs[Int(coat % 89) % hairs.count]
        AdventPaint.oval(ctx, head.x - dir * u * 0.045, head.y - u * 0.01, u * 0.13, u * 0.15, hair)
        AdventPaint.oval(ctx, head.x, head.y, u * 0.18, u * 0.19, skin)
        if u > 18 {
            AdventPaint.oval(ctx, head.x + dir * u * 0.04, head.y - u * 0.045, u * 0.05, u * 0.032, 0xe8958a, alpha: 0.7)
            AdventPaint.oval(ctx, head.x + dir * u * 0.045, head.y - u * 0.012, u * 0.018, u * 0.022, 0x2a211d)
            AdventPaint.oval(ctx, head.x + dir * u * 0.09, head.y - u * 0.005, u * 0.03, u * 0.025, blend(skin, 0xc98a6a, 0.5))
        }
        // Knitted hat: a cuff band, the crown and the bobble.
        let hatTone = blend(coat, 0xffffff, 0.18)
        let hat = CGMutablePath()
        hat.addArc(center: CGPoint(x: head.x, y: head.y + u * 0.025), radius: u * 0.098, startAngle: 0, endAngle: .pi,
                   clockwise: false)
        hat.closeSubpath()
        ctx.setFillColor(AdventPaint.color(hatTone))
        ctx.addPath(hat)
        ctx.fillPath()
        AdventPaint.box(ctx, CGRect(x: head.x - u * 0.105, y: head.y + u * 0.01, width: u * 0.21, height: u * 0.035),
                        u * 0.015, blend(hatTone, 0xffffff, 0.35))
        if u > 18 {
            // Knitted: ribs on the cuff and a stripe round the crown.
            ctx.setStrokeColor(AdventPaint.color(hatTone, 0.55))
            ctx.setLineWidth(max(0.3, u * 0.006))
            for rib in 0..<8 {
                let x = head.x - u * 0.095 + u * 0.19 * CGFloat(rib) / 7
                ctx.move(to: CGPoint(x: x, y: head.y + u * 0.013))
                ctx.addLine(to: CGPoint(x: x, y: head.y + u * 0.042))
            }
            ctx.strokePath()
            ctx.saveGState()
            ctx.addPath(hat)
            ctx.clip()
            ctx.setFillColor(AdventPaint.color(scarf, 0.85))
            ctx.fill(CGRect(x: head.x - u * 0.11, y: head.y + u * 0.075, width: u * 0.22, height: u * 0.016))
            ctx.restoreGState()
        }
        AdventPaint.oval(ctx, head.x - dir * u * 0.01, head.y + u * 0.135, u * 0.065, u * 0.065, 0xf6f1e6)
        if u > 18 {
            AdventPaint.oval(ctx, head.x - dir * u * 0.018, head.y + u * 0.127, u * 0.035, u * 0.03, 0xd8d0c0, alpha: 0.7)
        }
        // Near arm swinging against the legs, a mitten at the end; it may
        // carry a lantern.
        let hand = CGPoint(x: shoulder.x - stride * u * 0.12 + dir * u * 0.04, y: foot.y + u * 0.44 + bob)
        let elbow = CGPoint(x: (shoulder.x + hand.x) / 2 - dir * u * 0.015, y: (shoulder.y + hand.y) / 2)
        AdventPaint.stroke(ctx, [shoulder, elbow, hand], blend(coatTone, 0x000000, 0.12), max(0.6, u * 0.08))
        AdventPaint.oval(ctx, hand.x, hand.y, u * 0.065, u * 0.065, blend(coat, 0xffffff, 0.3))
        if u > 18 {
            AdventPaint.oval(ctx, hand.x + dir * u * 0.03, hand.y + u * 0.018, u * 0.026, u * 0.032, blend(coat, 0xffffff, 0.22))
        }
        if lantern {
            // A small hand lantern on a wire bail, swinging a little with
            // each step; its light falls on the snow ahead of the feet.
            let swing = sin(time * 5.2) * 0.18
            let lamp = CGPoint(x: hand.x + dir * u * 0.01 + sin(swing) * u * 0.12, y: hand.y - u * 0.12 * cos(swing))
            let light = sky.lampStrength
            ctx.saveGState()
            ctx.translateBy(x: lamp.x, y: foot.y + u * 0.01)
            ctx.scaleBy(x: 1, y: 0.28)
            AdventPaint.glow(ctx, at: .zero, radius: u * 0.55, 0xffc87a, 0.45 * light)
            ctx.restoreGState()
            AdventPaint.glow(ctx, at: lamp, radius: u * 0.42, 0xffc87a, 0.4 * light)
            ctx.setStrokeColor(AdventPaint.color(0x2a2420))
            ctx.setLineWidth(max(0.4, u * 0.012))
            ctx.beginPath()
            ctx.addArc(center: CGPoint(x: lamp.x, y: lamp.y + u * 0.055), radius: u * 0.04, startAngle: 0, endAngle: .pi, clockwise: false)
            ctx.strokePath()
            AdventPaint.stroke(ctx, [hand, CGPoint(x: lamp.x, y: lamp.y + u * 0.095)], 0x2a2420, max(0.4, u * 0.012))
            // Body: base, glass between four posts, a little pointed roof.
            AdventPaint.box(ctx, CGRect(x: lamp.x - u * 0.04, y: lamp.y - u * 0.06, width: u * 0.08, height: u * 0.016), u * 0.006, 0x2a2420)
            AdventPaint.box(ctx, CGRect(x: lamp.x - u * 0.032, y: lamp.y - u * 0.046, width: u * 0.064, height: u * 0.075), u * 0.008,
                            light > 0.3 ? 0xffe2a8 : 0xc9d4dc)
            if light > 0.3 {
                AdventPaint.oval(ctx, lamp.x, lamp.y - u * 0.012, u * 0.022, u * 0.036, 0xffb24a)
                AdventPaint.oval(ctx, lamp.x, lamp.y - u * 0.016, u * 0.01, u * 0.018, 0xfff6e0)
            }
            for x in [lamp.x - u * 0.032, lamp.x + u * 0.032] {
                AdventPaint.stroke(ctx, [CGPoint(x: x, y: lamp.y - u * 0.046), CGPoint(x: x, y: lamp.y + u * 0.03)], 0x2a2420, max(0.3, u * 0.01))
            }
            ctx.setFillColor(AdventPaint.color(0x2a2420))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: lamp.x - u * 0.048, y: lamp.y + u * 0.028))
            ctx.addLine(to: CGPoint(x: lamp.x + u * 0.048, y: lamp.y + u * 0.028))
            ctx.addLine(to: CGPoint(x: lamp.x, y: lamp.y + u * 0.06))
            ctx.closePath()
            ctx.fillPath()
        }
    }

    /// A small red tractor pulling a trailer of Christmas trees, strung with
    /// blinking fairy lights; the driver wears a Santa hat. `ground` is the
    /// middle of the whole rig on the road, `dir` the way it drives.
    static func drawTreeTractor(at ground: CGPoint, unit: CGFloat, dir: CGFloat, time: CGFloat,
                                        sky: AdventSky, in ctx: CGContext) {
        let u = unit
        let light = sky.valleyLight
        let night = sky.lampStrength
        // dx runs from the back of the trailer (0) to the tractor's nose (2.4).
        func at(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: ground.x + dir * (dx - 1.2) * u, y: ground.y + dy * u) }
        func rect(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            let a = at(x0, y0), b = at(x1, y1)
            return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(b.x - a.x), height: abs(b.y - a.y))
        }
        let chug = sin(time * 18) * u * 0.008
        func wheel(_ dx: CGFloat, _ r: CGFloat, hub: UInt32) {
            let c = at(dx, r)
            AdventPaint.oval(ctx, c.x, c.y, r * 2 * u, r * 2 * u, 0x1d1f24)
            AdventPaint.oval(ctx, c.x, c.y, r * 1.2 * u, r * 1.2 * u, multiply(hub, light))
            // Spokes turn with the distance driven.
            let turn = -ground.x / (r * u)
            for k in 0..<3 {
                let a = turn + CGFloat(k) * .pi / 3
                AdventPaint.stroke(ctx, [CGPoint(x: c.x - cos(a) * r * 0.55 * u, y: c.y - sin(a) * r * 0.55 * u),
                                         CGPoint(x: c.x + cos(a) * r * 0.55 * u, y: c.y + sin(a) * r * 0.55 * u)],
                                   multiply(blend(hub, 0x000000, 0.35), light), max(0.4, u * 0.025))
            }
            // Tread blocks on the rim.
            for k in 0..<8 {
                let a = turn + CGFloat(k) * .pi / 4
                AdventPaint.oval(ctx, c.x + cos(a) * r * 0.92 * u, c.y + sin(a) * r * 0.92 * u, u * 0.035, u * 0.035, 0x2c2f36)
            }
        }
        // Ground shadow and a spray of snow thrown up behind the wheels.
        AdventPaint.oval(ctx, ground.x, ground.y + u * 0.01, u * 2.5, u * 0.12, 0x2a3442, alpha: 0.22)
        let spray: CGFloat = night > 0.5 ? 0.12 : 0.35
        AdventPaint.glow(ctx, at: at(-0.15, 0.08), radius: u * 0.3, 0xffffff, spray)
        AdventPaint.glow(ctx, at: at(1.32, 0.1), radius: u * 0.32, 0xffffff, spray)
        // Trailer: a plank box on two wheels, a drawbar to the tractor.
        let wood = multiply(0x8a5d3b, light), woodDark = multiply(0x5c3b25, light)
        AdventPaint.stroke(ctx, [at(1.1, 0.24), at(1.42, 0.24)], multiply(0x33363d, light), max(0.6, u * 0.04))
        // Firs standing on the trailer, snow on their shoulders.
        let firs: [(CGFloat, CGFloat, UInt32)] = [(0.22, 0.72, 0x1f4a3a), (0.55, 0.86, 0x24533f), (0.88, 0.70, 0x1c4436)]
        let snow = multiply(0xf1f6fa, light)
        for (dx, size, tone) in firs {
            let fill = multiply(tone, light)
            for tier in 0..<3 {
                let f = CGFloat(tier) / 3
                let baseY = 0.34 + size * 0.75 * f
                let half = size * (0.30 - 0.08 * f)
                let top = baseY + size * 0.40
                let tri = CGMutablePath()
                tri.move(to: at(dx - half, baseY)); tri.addLine(to: at(dx, top)); tri.addLine(to: at(dx + half, baseY))
                tri.closeSubpath()
                ctx.setFillColor(AdventPaint.color(fill)); ctx.addPath(tri); ctx.fillPath()
                let cap = CGMutablePath()
                cap.move(to: at(dx - half * 0.35, top - size * 0.14)); cap.addLine(to: at(dx, top))
                cap.addLine(to: at(dx + half * 0.35, top - size * 0.14)); cap.closeSubpath()
                ctx.setFillColor(AdventPaint.color(snow)); ctx.addPath(cap); ctx.fillPath()
            }
        }
        AdventPaint.box(ctx, rect(0, 0.2, 1.1, 0.46), u * 0.03, wood)
        for plank in 1..<3 {
            let y = 0.2 + 0.26 * CGFloat(plank) / 3
            AdventPaint.stroke(ctx, [at(0.02, y), at(1.08, y)], woodDark, max(0.4, u * 0.015))
        }
        AdventPaint.box(ctx, rect(0, 0.44, 1.1, 0.48), u * 0.02, snow)
        wheel(0.35, 0.13, hub: 0xb8302a)
        wheel(0.80, 0.13, hub: 0xb8302a)
        // Fairy lights swag along the trailer edge and over the trees.
        let colours: [UInt32] = [0xff5a4a, 0xffd25a, 0x5ad07a, 0x6aa8ff]
        var bulbs: [CGPoint] = []
        for k in 0...10 {
            let f = CGFloat(k) / 10
            let dx = 0.05 + f * 1.0
            let sag = 0.06 * sin(f * .pi * 3).magnitude
            bulbs.append(at(dx, 0.46 - sag + 0.02))
        }
        for k in 0...6 {
            let f = CGFloat(k) / 6
            bulbs.append(at(0.18 + f * 0.74, 0.92 + 0.22 * sin(f * .pi) - 0.05 * sin(f * .pi * 3).magnitude))
        }
        let step = Int(time * 2.5)
        for (k, bulb) in bulbs.enumerated() {
            let colour = colours[(k + step) % colours.count]
            let on = (k + step) % 3 != 0
            if on { AdventPaint.glow(ctx, at: bulb, radius: u * (0.07 + 0.06 * night), colour, 0.3 + 0.3 * night) }
            AdventPaint.oval(ctx, bulb.x, bulb.y, u * 0.045, u * 0.045, on ? blend(colour, 0xffffff, 0.35) : blend(colour, 0x000000, 0.5))
        }
        // Tractor: big back wheel, small front wheel, red bonnet and cab.
        let red = multiply(0xc22d26, light), redDark = multiply(0x8e1f1b, light), redLight = multiply(0xe2564a, light)
        AdventPaint.box(ctx, rect(1.42, 0.30 + chug / u, 1.84, 0.88 + chug / u), u * 0.04, red)
        AdventPaint.box(ctx, rect(1.50, 0.56 + chug / u, 1.78, 0.82 + chug / u), u * 0.03,
                        night > 0.3 ? 0xffd9a0 : multiply(0xbcd2e4, light))
        // The driver behind the glass in a Santa hat.
        let face = at(1.66, 0.66 + chug / u)
        AdventPaint.oval(ctx, face.x, face.y, u * 0.12, u * 0.12, 0xf0c7a4)
        let hat = CGMutablePath()
        hat.move(to: at(1.59, 0.71 + chug / u)); hat.addLine(to: at(1.60, 0.84 + chug / u)); hat.addLine(to: at(1.73, 0.71 + chug / u))
        hat.closeSubpath()
        ctx.setFillColor(AdventPaint.color(0xc8322b)); ctx.addPath(hat); ctx.fillPath()
        let brim = at(1.66, 0.71 + chug / u)
        AdventPaint.oval(ctx, brim.x, brim.y, u * 0.16, u * 0.04, 0xf6f1e6)
        let bobble = at(1.60, 0.84 + chug / u)
        AdventPaint.oval(ctx, bobble.x, bobble.y, u * 0.045, u * 0.045, 0xf6f1e6)
        AdventPaint.box(ctx, rect(1.38, 0.86 + chug / u, 1.88, 0.94 + chug / u), u * 0.03, redDark)
        AdventPaint.box(ctx, rect(1.40, 0.93 + chug / u, 1.86, 0.98 + chug / u), u * 0.025, snow)
        // Bonnet with a grille and a wreath on the side.
        AdventPaint.box(ctx, rect(1.80, 0.30 + chug / u, 2.40, 0.58 + chug / u), u * 0.06, red)
        AdventPaint.box(ctx, rect(1.84, 0.52 + chug / u, 2.36, 0.56 + chug / u), u * 0.02, redLight)
        for k in 0..<3 {
            let x = 1.98 + CGFloat(k) * 0.1
            AdventPaint.stroke(ctx, [at(x, 0.36 + chug / u), at(x, 0.48 + chug / u)], redDark, max(0.4, u * 0.02))
        }
        let wreath = at(1.63, 0.43 + chug / u)
        AdventPaint.oval(ctx, wreath.x, wreath.y, u * 0.17, u * 0.17, multiply(0x2f6b45, light))
        AdventPaint.oval(ctx, wreath.x, wreath.y, u * 0.08, u * 0.08, red)
        AdventPaint.oval(ctx, wreath.x, wreath.y - u * 0.07, u * 0.06, u * 0.04, 0xe8b440)
        // Mudguard over the big wheel, exhaust pipe with puffs.
        wheel(1.62, 0.27, hub: 0xe8b440)
        let guardPath = CGMutablePath()
        let g = at(1.62, 0.27)
        guardPath.addArc(center: g, radius: u * 0.31, startAngle: .pi * 0.05, endAngle: .pi * 0.95, clockwise: false)
        ctx.setStrokeColor(AdventPaint.color(redDark)); ctx.setLineWidth(max(0.8, u * 0.06)); ctx.addPath(guardPath); ctx.strokePath()
        wheel(2.22, 0.15, hub: 0xe8b440)
        AdventPaint.stroke(ctx, [at(2.12, 0.58 + chug / u), at(2.12, 0.82 + chug / u)], multiply(0x3a3d44, light), max(0.6, u * 0.045))
        for k in 0..<3 {
            let age = (time * 1.6 + CGFloat(k) / 3).truncatingRemainder(dividingBy: 1)
            let puff = at(2.12 - age * 0.45, 0.88 + age * 0.35)
            AdventPaint.oval(ctx, puff.x, puff.y, u * (0.08 + age * 0.14), u * (0.07 + age * 0.12),
                             multiply(0xa9b0ba, light), alpha: 0.55 * (1 - age))
        }
        // Headlamp with a beam on the snow after dark.
        let lamp = at(2.40, 0.48 + chug / u)
        AdventPaint.oval(ctx, lamp.x, lamp.y, u * 0.07, u * 0.07, night > 0.3 ? 0xfff6d8 : multiply(0xf2e8c8, light))
        if night > 0.3 {
            let pool = at(3.05, 0.04)
            AdventPaint.beam(ctx, from: lamp, to: pool, spread: u, 0xfff1c8, 0.30 * night)
            AdventPaint.pool(ctx, at: pool, width: u * 1.4, flat: 0.22, 0xffe6b0, 0.45 * night)
            AdventPaint.glow(ctx, at: lamp, radius: u * 0.22, 0xfff6d8, 0.7 * night)
        }
    }

    private static func drawHorseSleigh(at ground: CGPoint, unit: CGFloat, dir: CGFloat, time: CGFloat,
                                        sky: AdventSky, in ctx: CGContext) {
        let u = unit
        let trot = sin(time * 7)
        func px(_ dx: CGFloat) -> CGPoint { CGPoint(x: ground.x + dir * dx * u, y: 0) }
        func at(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: ground.x + dir * dx * u, y: ground.y + dy * u) }
        // One soft shadow on the snow under the whole rig, sleigh and horse.
        AdventPaint.pool(ctx, at: at(0.18, 0.01), width: u * 2.4, flat: 0.10, 0x2a3442, 0.18 + 0.32 * sky.daylight)
        let horse = blend(0x6b4a32, sky.horizon, 0.08)
        let horseDark = blend(horse, 0x000000, 0.35)
        let mane: UInt32 = 0x2a1c14
        let bodyY = 0.58 + abs(trot) * 0.02
        // Far legs first, darker.
        func leg(_ x: CGFloat, _ phase: CGFloat, _ tone: UInt32) {
            let top = at(x, bodyY - 0.06)
            let knee = at(x + 0.06 * trot * phase, 0.24 + max(0, trot * phase) * 0.05)
            let hoof = at(x + 0.11 * trot * phase - 0.02, max(0, trot * phase) * 0.07)
            AdventPaint.stroke(ctx, [top, knee], tone, max(1, u * 0.11))
            AdventPaint.stroke(ctx, [knee, hoof], tone, max(0.8, u * 0.07))
            AdventPaint.oval(ctx, hoof.x, hoof.y + u * 0.02, u * 0.09, u * 0.06, 0x1e1510)
            // A tuft of feathering above the hoof.
            AdventPaint.oval(ctx, hoof.x, hoof.y + u * 0.07, u * 0.08, u * 0.05, blend(tone, 0xffffff, 0.15))
        }
        leg(0.56, -1, horseDark); leg(0.98, 1, horseDark)
        // Tail: a full, tapering sweep from the rump.
        let swish = 0.03 * sin(time * 3)
        let tail = CGMutablePath()
        tail.move(to: at(0.38, bodyY + 0.08))
        tail.addQuadCurve(to: at(0.26 - swish, bodyY - 0.30), control: at(0.24, bodyY + 0.02))
        tail.addQuadCurve(to: at(0.38, bodyY - 0.02), control: at(0.34 - swish, bodyY - 0.18))
        tail.closeSubpath()
        ctx.setFillColor(AdventPaint.color(mane))
        ctx.addPath(tail)
        ctx.fillPath()
        // Body with a lit back, the near legs over it.
        let body = at(0.72, bodyY)
        AdventPaint.oval(ctx, body.x, body.y, u * 0.74, u * 0.36, horse)
        AdventPaint.oval(ctx, body.x - dir * u * 0.04, body.y + u * 0.09, u * 0.52, u * 0.12, blend(horse, 0xffffff, 0.14))
        AdventPaint.oval(ctx, at(0.48, bodyY + 0.02).x, body.y, u * 0.28, u * 0.32, blend(horse, 0x000000, 0.08))
        leg(0.46, 1, horse); leg(0.88, -1, horse)
        // Neck rising to the head, mane along its crest.
        let neck = CGMutablePath()
        neck.move(to: at(0.82, bodyY + 0.16))
        neck.addQuadCurve(to: at(1.00, bodyY + 0.46), control: at(0.88, bodyY + 0.38))
        neck.addLine(to: at(1.12, bodyY + 0.38))
        neck.addQuadCurve(to: at(1.06, bodyY - 0.06), control: at(1.12, bodyY + 0.10))
        neck.closeSubpath()
        ctx.setFillColor(AdventPaint.color(horse))
        ctx.addPath(neck)
        ctx.fillPath()
        AdventPaint.stroke(ctx, [at(0.83, bodyY + 0.20), at(0.90, bodyY + 0.36), at(1.00, bodyY + 0.48)], mane,
                           max(0.8, u * 0.06))
        // Head: long face, muzzle, ear, eye, a blaze down the nose.
        let headPath = CGMutablePath()
        headPath.move(to: at(0.98, bodyY + 0.46))
        headPath.addQuadCurve(to: at(1.30, bodyY + 0.26), control: at(1.14, bodyY + 0.50))
        headPath.addQuadCurve(to: at(1.27, bodyY + 0.17), control: at(1.34, bodyY + 0.19))
        headPath.addQuadCurve(to: at(1.08, bodyY + 0.30), control: at(1.16, bodyY + 0.20))
        headPath.closeSubpath()
        ctx.setFillColor(AdventPaint.color(horse))
        ctx.addPath(headPath)
        ctx.fillPath()
        AdventPaint.oval(ctx, at(1.26, bodyY + 0.2).x, at(0, bodyY + 0.2).y, u * 0.1, u * 0.09, blend(horse, 0x000000, 0.25))
        AdventPaint.stroke(ctx, [at(1.12, bodyY + 0.36), at(1.24, bodyY + 0.26)], 0xf2ece2, max(0.5, u * 0.03), alpha: 0.85)
        let ear = CGMutablePath()
        ear.move(to: at(0.99, bodyY + 0.46)); ear.addLine(to: at(1.01, bodyY + 0.58)); ear.addLine(to: at(1.06, bodyY + 0.47))
        ear.closeSubpath()
        ctx.setFillColor(AdventPaint.color(horseDark))
        ctx.addPath(ear)
        ctx.fillPath()
        let eye = at(1.10, bodyY + 0.40)
        AdventPaint.oval(ctx, eye.x, eye.y, u * 0.035, u * 0.035, 0x120c08)
        // Harness: red collar with brass bells, a bridle, reins back to the driver.
        AdventPaint.stroke(ctx, [at(0.94, bodyY + 0.24), at(0.98, bodyY - 0.05)], 0xb23a32, max(0.8, u * 0.08))
        for bell in 0..<3 {
            let b = at(0.95 + CGFloat(bell) * 0.01, bodyY + 0.16 - CGFloat(bell) * 0.09)
            AdventPaint.oval(ctx, b.x, b.y, u * 0.055, u * 0.055, 0xe8b440)
            AdventPaint.oval(ctx, b.x - u * 0.01, b.y + u * 0.012, u * 0.02, u * 0.02, 0xfff0b0)
        }
        AdventPaint.stroke(ctx, [at(1.08, bodyY + 0.36), at(1.22, bodyY + 0.24)], 0x3a2418, max(0.4, u * 0.02))
        if u > 30 {
            // A red and white plume on the bridle, a sprig of fir on the collar.
            let plume = at(1.02, bodyY + 0.50)
            let sway = sin(time * 7) * 0.02
            let tip = at(0.97 + sway, bodyY + 0.59)
            AdventPaint.oval(ctx, (plume.x + tip.x) / 2, (plume.y + tip.y) / 2, u * 0.07, u * 0.11, 0xc23b32)
            AdventPaint.oval(ctx, (plume.x + tip.x) / 2 + dir * u * 0.008, (plume.y + tip.y) / 2 + u * 0.01, u * 0.03, u * 0.07, 0xf6f1e6)
            for k in 0..<4 {
                let b = at(0.92 + CGFloat(k) * 0.02, bodyY + 0.22 - CGFloat(k) * 0.02)
                AdventPaint.oval(ctx, b.x, b.y, u * 0.06, u * 0.025, 0x2f5a3c)
            }
            AdventPaint.oval(ctx, at(0.95, bodyY + 0.2).x, at(0, bodyY + 0.2).y, u * 0.03, u * 0.03, 0xc23b32)
            // Breath steaming from the nostrils in the cold.
            let breath = (time * 0.7).truncatingRemainder(dividingBy: 1)
            AdventPaint.glow(ctx, at: at(1.36 + breath * 0.12, bodyY + 0.16 - breath * 0.02), radius: u * (0.05 + breath * 0.10),
                             0xffffff, 0.45 * (1 - breath))
        }
        AdventPaint.stroke(ctx, [at(0.70, bodyY + 0.16), at(0.78, bodyY - 0.10)], 0x3a2418, max(0.6, u * 0.045))
        // Shafts from the sleigh to the collar.
        AdventPaint.stroke(ctx, [at(0.05, 0.40), at(0.95, bodyY + 0.02)], 0x4a3222, max(0.5, u * 0.04))
        // The sleigh: a scrolled red body on curling runners.
        let sleigh = CGMutablePath()
        sleigh.move(to: at(-0.55, 0.14))
        sleigh.addLine(to: at(-0.62, 0.60))
        sleigh.addQuadCurve(to: at(-0.22, 0.42), control: at(-0.34, 0.66))
        sleigh.addQuadCurve(to: at(0.10, 0.46), control: at(0.0, 0.36))
        sleigh.addQuadCurve(to: at(0.16, 0.56), control: at(0.18, 0.50))
        sleigh.addQuadCurve(to: at(0.05, 0.14), control: at(0.14, 0.30))
        sleigh.closeSubpath()
        // Driver behind the dash, reins in hand.
        drawWalker(at: at(-0.3, 0.24), height: u * 0.62, dir: dir, time: 0, coat: 0x2f5f8a, lantern: false, sky: sky, shadow: false, in: ctx)
        AdventPaint.stroke(ctx, [at(-0.22, 0.52), at(0.4, bodyY + 0.12), at(1.1, bodyY + 0.30)], 0x3a2418,
                           max(0.4, u * 0.018), alpha: 0.9)
        ctx.setFillColor(AdventPaint.color(blend(0xa8302a, sky.horizon, 0.1)))
        ctx.addPath(sleigh)
        ctx.fillPath()
        ctx.saveGState()
        ctx.addPath(sleigh)
        ctx.clip()
        ctx.setFillColor(AdventPaint.color(0x5a1414, 0.35))
        ctx.fill(CGRect(x: min(at(-0.7, 0).x, at(0.2, 0).x), y: ground.y, width: u * 0.9, height: u * 0.22))
        ctx.restoreGState()
        // Gold scrollwork along the rim and a painted flower on the side.
        AdventPaint.stroke(ctx, [at(-0.62, 0.58), at(-0.34, 0.60), at(-0.22, 0.42), at(0.0, 0.40), at(0.12, 0.48)],
                           0xe8b440, max(0.5, u * 0.03))
        let flower = at(-0.25, 0.27)
        for petal in 0..<5 {
            let a = CGFloat(petal) / 5 * .pi * 2
            AdventPaint.oval(ctx, flower.x + cos(a) * u * 0.05, flower.y + sin(a) * u * 0.05, u * 0.05, u * 0.05, 0xf3e3b0)
        }
        AdventPaint.oval(ctx, flower.x, flower.y, u * 0.04, u * 0.04, 0xe8b440)
        if u > 30 {
            // Green tendrils round the flower and gold curls at both ends.
            for side: CGFloat in [-1, 1] {
                AdventPaint.stroke(ctx, [at(-0.25 + side * 0.07, 0.27), at(-0.25 + side * 0.15, 0.31), at(-0.25 + side * 0.20, 0.26)],
                                   0x4f7a45, max(0.4, u * 0.014))
                AdventPaint.oval(ctx, at(-0.25 + side * 0.15, 0.32).x, at(0, 0.32).y, u * 0.04, u * 0.022, 0x5e8a50)
            }
            for (cx, cy) in [(-0.56, 0.48), (0.10, 0.36)] {
                let c = at(CGFloat(cx), CGFloat(cy))
                ctx.setStrokeColor(AdventPaint.color(0xe8b440))
                ctx.setLineWidth(max(0.4, u * 0.018))
                ctx.beginPath()
                for step in 0...20 {
                    let t = CGFloat(step) / 20
                    let a = t * .pi * 3
                    let r = u * 0.05 * (1 - t * 0.8)
                    let point = CGPoint(x: c.x + dir * cos(a) * r, y: c.y + sin(a) * r)
                    if step == 0 { ctx.move(to: point) } else { ctx.addLine(to: point) }
                }
                ctx.strokePath()
            }
            AdventPaint.stroke(ctx, [at(-0.56, 0.20), at(0.04, 0.20)], 0xe8b440, max(0.4, u * 0.014), alpha: 0.8)
        }
        // A plaid blanket over the driver's knees, hanging over the side.
        let rug = CGMutablePath()
        rug.move(to: at(-0.42, 0.50))
        rug.addQuadCurve(to: at(-0.14, 0.43), control: at(-0.28, 0.54))
        rug.addLine(to: at(-0.12, 0.38))
        rug.addQuadCurve(to: at(-0.40, 0.40), control: at(-0.26, 0.36))
        rug.closeSubpath()
        ctx.setFillColor(AdventPaint.color(blend(0x2f5a3c, sky.horizon, 0.08)))
        ctx.addPath(rug)
        ctx.fillPath()
        if u > 30 {
            ctx.saveGState()
            ctx.addPath(rug)
            ctx.clip()
            for k in 0..<5 {
                let x = at(-0.40 + CGFloat(k) * 0.07, 0).x
                AdventPaint.stroke(ctx, [CGPoint(x: x, y: at(0, 0.28).y), CGPoint(x: x, y: at(0, 0.56).y)], 0xb23a32, u * 0.018, alpha: 0.8)
            }
            for k in 0..<3 {
                let y = at(0, 0.41 + CGFloat(k) * 0.045).y
                AdventPaint.stroke(ctx, [CGPoint(x: at(-0.45, 0).x, y: y), CGPoint(x: at(-0.08, 0).x, y: y)], 0xe8b440, u * 0.010, alpha: 0.7)
            }
            ctx.restoreGState()
            for k in 0..<7 {
                let x = at(-0.39 + CGFloat(k) * 0.04, 0).x
                let y = at(0, 0.39 - CGFloat(k) * 0.002).y
                AdventPaint.stroke(ctx, [CGPoint(x: x, y: y), CGPoint(x: x, y: y - u * 0.035)], 0x2f5a3c, max(0.4, u * 0.01))
            }
        }
        // Runners curling up at the front.
        let runner = CGMutablePath()
        runner.move(to: at(-0.66, 0.05))
        runner.addLine(to: at(0.12, 0.05))
        runner.addQuadCurve(to: at(0.22, 0.24), control: at(0.30, 0.06))
        runner.addQuadCurve(to: at(0.14, 0.18), control: at(0.16, 0.26))
        ctx.setStrokeColor(AdventPaint.color(0x2a2420))
        ctx.setLineWidth(max(0.6, u * 0.045))
        ctx.setLineCap(.round)
        ctx.addPath(runner)
        ctx.strokePath()
        for strut: CGFloat in [-0.45, -0.05] {
            AdventPaint.stroke(ctx, [at(strut, 0.05), at(strut, 0.15)], 0x2a2420, max(0.5, u * 0.035))
        }
        // Snow packed on the runners and thrown up behind them.
        AdventPaint.stroke(ctx, [at(-0.60, 0.075), at(0.08, 0.075)], 0xeef4f8, max(0.4, u * 0.014), alpha: 0.8)
        for puff in 0..<3 {
            let fly = (time * 0.9 + CGFloat(puff) * 0.33).truncatingRemainder(dividingBy: 1)
            AdventPaint.oval(ctx, at(-0.68 - fly * 0.25, 0.06 + fly * 0.08).x, at(0, 0.06 + fly * 0.08).y,
                             u * (0.06 + fly * 0.08), u * (0.04 + fly * 0.05), 0xffffff, alpha: 0.5 * (1 - fly))
        }
        // A lantern on a bracket at the back.
        let lampBase = at(-0.62, 0.60)
        let lamp = at(-0.70, 0.78)
        AdventPaint.stroke(ctx, [lampBase, at(-0.70, 0.70)], 0x2a2420, max(0.4, u * 0.025))
        if sky.lampStrength > 0.2 {
            AdventPaint.glow(ctx, at: lamp, radius: u * 1.1, 0xffc87a, 0.4 * sky.lampStrength)
        }
        AdventPaint.box(ctx, CGRect(x: lamp.x - u * 0.055, y: lamp.y - u * 0.07, width: u * 0.11, height: u * 0.14),
                        u * 0.02, 0x2a2420)
        AdventPaint.box(ctx, CGRect(x: lamp.x - u * 0.035, y: lamp.y - u * 0.05, width: u * 0.07, height: u * 0.1),
                        u * 0.015, sky.lampStrength > 0.2 ? 0xffe2a8 : 0xd8c9a0)
        _ = px
    }

    // MARK: Sky and mountains

    /// Mixes two colours given as 0xRRGGBB.
    /// Light falling on a surface: each channel scaled by the light's.
    static func multiply(_ a: UInt32, _ b: UInt32) -> UInt32 {
        func channel(_ shift: UInt32) -> UInt32 {
            ((a >> shift) & 0xff) * ((b >> shift) & 0xff) / 255
        }
        return (channel(16) << 16) | (channel(8) << 8) | channel(0)
    }

    static func blend(_ a: UInt32, _ b: UInt32, _ t: CGFloat) -> UInt32 {
        let t = min(1, max(0, t))
        func channel(_ shift: UInt32) -> UInt32 {
            let from = CGFloat((a >> shift) & 255), to = CGFloat((b >> shift) & 255)
            return UInt32(from + (to - from) * t) & 255
        }
        return (channel(16) << 16) | (channel(8) << 8) | channel(0)
    }

    private static func drawSky(_ layout: AdventLayout, season: AdventSeason,
                                sky: AdventSky, in ctx: CGContext) {
        let bounds = layout.bounds
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [
            AdventPaint.color(sky.zenith),
            AdventPaint.color(blend(sky.zenith, sky.horizon, 0.45)),
            AdventPaint.color(blend(sky.zenith, sky.horizon, 0.80)),
            AdventPaint.color(sky.horizon)
        ] as CFArray, locations: [0, 0.40, 0.72, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: bounds.maxY),
                               end: CGPoint(x: 0, y: bounds.minY + bounds.height * 0.30), options: [.drawsAfterEndLocation])
        // Dawn and dusk: the warm horizon colour lies low, behind the
        // mountains, so the sky above the ridges stayed night blue while the
        // peaks already glowed. A peach glow rises over the ridges on the side
        // of the sun, left in the morning, right in the evening, with a faint
        // warm wash across the whole low sky.
        if sky.alpenglowStrength > 0.05 {
            let evening = sky.sunElevation > -0.05 ? sky.sunAzimuth > 0.5 : sky.moonAzimuth < 0.5
            let warm = blend(0xffc995, 0xff9c7c, 1 - sky.daylight)
            let strength = sky.alpenglowStrength
            let wash = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(warm, 0.30 * strength), AdventPaint.color(warm, 0)] as CFArray,
                                  locations: [0, 1])!
            ctx.drawLinearGradient(wash, start: CGPoint(x: 0, y: bounds.minY + bounds.height * 0.55),
                                   end: CGPoint(x: 0, y: bounds.minY + bounds.height * 0.95), options: [.drawsBeforeStartLocation])
            ctx.saveGState()
            ctx.translateBy(x: bounds.minX + bounds.width * (evening ? 0.86 : 0.14), y: bounds.minY + bounds.height * 0.60)
            ctx.scaleBy(x: 1.7, y: 0.6)
            AdventPaint.glow(ctx, at: .zero, radius: bounds.width * 0.42, warm, 0.55 * strength)
            ctx.restoreGState()
        }

        if sky.starlight > 0.02 {
            // A faint band of the Milky Way across the high sky.
            ctx.saveGState()
            ctx.translateBy(x: bounds.minX + bounds.width * 0.55, y: bounds.minY + bounds.height * 0.86)
            ctx.rotate(by: -0.32)
            ctx.scaleBy(x: 5.5, y: 1)
            AdventPaint.glow(ctx, at: .zero, radius: bounds.height * 0.10, 0xb9c8e6, 0.10 * sky.starlight)
            ctx.restoreGState()
            for index in 0..<160 {
                let t = AdventLayout.noise(index, 760)
                let along = CGPoint(x: bounds.minX + bounds.width * (0.05 + t * 1.0),
                                    y: bounds.minY + bounds.height * (0.86 - (t - 0.5) * 0.33))
                let spread = (AdventLayout.noise(index, 761) - 0.5) * bounds.height * 0.10
                AdventPaint.oval(ctx, along.x, along.y + spread, 0.7, 0.7, 0xe6eefb, alpha: 0.35 * sky.starlight)
            }
            for (number, star) in layout.stars.enumerated() {
                // Stars thin out toward the horizon, as they do over a valley.
                let height = (star.point.y - bounds.minY) / bounds.height
                let fade = min(1, max(0, (height - 0.42) / 0.3))
                // Each its own colour: most white, some blue, a few warm.
                let hue = AdventLayout.noise(number, 762)
                let tint: UInt32 = hue < 0.15 ? 0xffe2b8 : (hue < 0.45 ? 0xcfe0ff : 0xf4f8ff)
                let alpha = (0.22 + star.size * 0.3) * sky.starlight * fade
                AdventPaint.oval(ctx, star.point.x, star.point.y, star.size, star.size, tint, alpha: alpha)
                if star.size > 2.0 {
                    // The brightest have a soft halo and four fine rays.
                    AdventPaint.glow(ctx, at: star.point, radius: star.size * 3, tint, 0.35 * alpha)
                    ctx.setStrokeColor(AdventPaint.color(tint, 0.45 * alpha))
                    ctx.setLineWidth(0.6)
                    ctx.move(to: CGPoint(x: star.point.x - star.size * 3, y: star.point.y))
                    ctx.addLine(to: CGPoint(x: star.point.x + star.size * 3, y: star.point.y))
                    ctx.move(to: CGPoint(x: star.point.x, y: star.point.y - star.size * 3))
                    ctx.addLine(to: CGPoint(x: star.point.x, y: star.point.y + star.size * 3))
                    ctx.strokePath()
                }
            }
        }

        drawClouds(layout, sky: sky, in: ctx)
        if let sun = sky.sunPoint(in: bounds) {
            // A winter sun is a blinding white core in a wide warm haze that
            // lifts the whole sky around it; low in the sky it turns golden.
            let radius = min(bounds.width, bounds.height) * 0.026
            let warm = blend(0xfff1d6, 0xffb26a, sky.alpenglowStrength)
            AdventPaint.glow(ctx, at: sun, radius: bounds.height * 0.55, blend(0xeaf3ff, warm, 0.25),
                             0.38 * sky.daylight)
            AdventPaint.glow(ctx, at: sun, radius: radius * 8, warm, 0.55)
            AdventPaint.glow(ctx, at: sun, radius: radius * 3, 0xffffff, 0.85)
            AdventPaint.oval(ctx, sun.x, sun.y, radius * 2, radius * 2, blend(0xfffdf6, warm, 0.25))
            // Faint glare streaks, as through cold air.
            ctx.saveGState()
            ctx.setLineCap(.round)
            for ray in 0..<6 {
                let angle = CGFloat(ray) * .pi / 3 + 0.26
                let length = radius * (ray % 2 == 0 ? 6.5 : 4.2)
                let tip = CGPoint(x: sun.x + cos(angle) * length, y: sun.y + sin(angle) * length)
                let tail = CGPoint(x: sun.x - cos(angle) * length, y: sun.y - sin(angle) * length)
                let streak = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                        colors: [AdventPaint.color(0xffffff, 0), AdventPaint.color(0xffffff, 0.35),
                                                 AdventPaint.color(0xffffff, 0)] as CFArray,
                                        locations: [0, 0.5, 1])!
                ctx.saveGState()
                ctx.setLineWidth(radius * 0.22)
                ctx.move(to: tail)
                ctx.addLine(to: tip)
                ctx.replacePathWithStrokedPath()
                ctx.clip()
                ctx.drawLinearGradient(streak, start: tail, end: tip, options: [])
                ctx.restoreGState()
            }
            ctx.restoreGState()
        }
        if let moon = sky.moonPoint(in: bounds) {
            let radius = min(bounds.width, bounds.height) * 0.024
            AdventPaint.glow(ctx, at: moon, radius: radius * 6.5, 0xdfe9ff, 0.26 * sky.starlight)
            // A faint ring of ice crystals round the winter moon.
            ctx.setStrokeColor(AdventPaint.color(0xdfe9ff, 0.045 * sky.starlight))
            ctx.setLineWidth(radius * 0.5)
            ctx.strokeEllipse(in: CGRect(x: moon.x - radius * 4.2, y: moon.y - radius * 4.2, width: radius * 8.4, height: radius * 8.4))
            let disc = CGRect(x: moon.x - radius, y: moon.y - radius, width: radius * 2, height: radius * 2)
            let face = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(0xfffbee), AdventPaint.color(0xf1ecdc), AdventPaint.color(0xd9d3c2)] as CFArray,
                                  locations: [0, 0.6, 1])!
            ctx.saveGState()
            ctx.addEllipse(in: disc)
            ctx.clip()
            ctx.drawRadialGradient(face, startCenter: CGPoint(x: moon.x - radius * 0.3, y: moon.y + radius * 0.3), startRadius: 0,
                                   endCenter: moon, endRadius: radius * 1.05, options: [.drawsAfterEndLocation])
            // The seas as the full moon shows them from the Alps: Oceanus
            // Procellarum wide on the left, Imbrium above it, Serenitatis
            // and Tranquillitatis right of the middle, Crisium near the
            // right edge, Nubium and Fecunditatis below. Each is a soft
            // blot with no edge, built from a few overlapping glows so its
            // outline is irregular, not a circle.
            let seas: [(x: CGFloat, y: CGFloat, size: CGFloat, dark: CGFloat)] = [
                (-0.50, 0.05, 0.34, 0.30), (-0.42, -0.18, 0.26, 0.26), (-0.30, 0.30, 0.22, 0.28),   // Procellarum
                (-0.22, 0.42, 0.24, 0.34), (-0.05, 0.50, 0.16, 0.30),                               // Imbrium
                (0.18, 0.36, 0.15, 0.36),                                                           // Serenitatis
                (0.30, 0.10, 0.19, 0.36), (0.20, -0.02, 0.12, 0.30),                                // Tranquillitatis
                (0.62, 0.24, 0.11, 0.40),                                                           // Crisium
                (0.50, -0.18, 0.13, 0.30), (0.33, -0.26, 0.08, 0.28),                               // Fecunditatis, Nectaris
                (-0.15, -0.38, 0.17, 0.26), (-0.32, -0.46, 0.12, 0.22)                              // Nubium, Humorum
            ]
            let sea = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                 colors: [AdventPaint.color(0x9e9888, 1), AdventPaint.color(0x9e9888, 0.8),
                                          AdventPaint.color(0x9e9888, 0)] as CFArray,
                                 locations: [0, 0.5, 1])!
            for blot in seas {
                let center = CGPoint(x: moon.x + radius * blot.x, y: moon.y + radius * blot.y)
                ctx.saveGState()
                ctx.setAlpha(blot.dark)
                ctx.drawRadialGradient(sea, startCenter: center, startRadius: 0,
                                       endCenter: center, endRadius: radius * blot.size, options: [])
                ctx.restoreGState()
            }
            // Tycho, the bright young crater low on the face, with its rays.
            let tycho = CGPoint(x: moon.x - radius * 0.10, y: moon.y - radius * 0.70)
            ctx.setStrokeColor(AdventPaint.color(0xffffff, 0.16))
            ctx.setLineWidth(max(0.4, radius * 0.035))
            for ray in 0..<9 {
                let angle = CGFloat(ray) * .pi * 2 / 9 + 0.3
                let length = radius * (0.35 + AdventLayout.noise(ray, 920) * 0.45)
                ctx.move(to: tycho)
                ctx.addLine(to: CGPoint(x: tycho.x + cos(angle) * length, y: tycho.y + sin(angle) * length))
            }
            ctx.strokePath()
            AdventPaint.glow(ctx, at: tycho, radius: radius * 0.12, 0xffffff, 0.7)
            ctx.restoreGState()
        }
    }

    /// Soft cloud banks: a lit crown and a shaded underside, tinted by the sky.
    private static func drawClouds(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let crown = blend(0xffffff, sky.alpenglow, sky.alpenglowStrength * 0.6)
        let belly = blend(blend(sky.zenith, 0x8f9fb8, 0.45), sky.alpenglow, sky.alpenglowStrength * 0.3)
        for cloud in layout.clouds {
            // Soft puffs, each a blurred blob: a lit crown over a shaded belly,
            // with no hard outline anywhere.
            let puffs = 7
            for puff in 0..<puffs {
                let t = (CGFloat(puff) + 0.5) / CGFloat(puffs)
                let lift = sin(t * .pi)
                let radius = cloud.height * (0.55 + lift * 0.95)
                let centre = CGPoint(x: cloud.center.x - cloud.width / 2 + cloud.width * t,
                                     y: cloud.center.y + radius * 0.15 * lift)
                ctx.saveGState()
                ctx.translateBy(x: centre.x, y: centre.y)
                ctx.scaleBy(x: 1.35, y: 0.8)
                AdventPaint.glow(ctx, at: CGPoint(x: 0, y: -radius * 0.25), radius: radius * 1.1, belly, 0.16)
                AdventPaint.glow(ctx, at: CGPoint(x: 0, y: radius * 0.15), radius: radius, crown, 0.30)
                ctx.restoreGState()
            }
        }
    }

    /// Rock and snow for one mountain body, with the warm light of a low sun on
    /// the faces that catch it.
    private static func paintMassif(_ ctx: CGContext, body: CGPath, sunlitSide: CGPath?,
                                    rock: UInt32, snow: UInt32, snowLine: CGFloat,
                                    top: CGFloat, sky: AdventSky, glow: CGFloat, textured: Bool = true) {
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        // Rock darkens toward the valley floor; a flat fill looks like paper.
        let box = body.boundingBox
        let stone = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [AdventPaint.color(blend(rock, 0x10172a, 0.45)),
                                        AdventPaint.color(rock),
                                        AdventPaint.color(blend(rock, 0xdbe6f2, 0.22))] as CFArray,
                               locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(stone, start: CGPoint(x: 0, y: box.minY),
                               end: CGPoint(x: 0, y: box.maxY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        // Snow lies above the snow line and thins out below it.
        let field = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [AdventPaint.color(snow, 0.97),
                                        AdventPaint.color(snow, 0.80),
                                        AdventPaint.color(snow, 0)] as CFArray,
                               locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(field, start: CGPoint(x: 0, y: top),
                               end: CGPoint(x: 0, y: snowLine), options: [.drawsBeforeStartLocation])
        if glow > 0.01 {
            // Alpenglow: the warm band that makes a Swiss postcard.
            let alpen = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                   colors: [AdventPaint.color(sky.alpenglow, 0.78 * glow),
                                            AdventPaint.color(sky.alpenglow, 0.22 * glow),
                                            AdventPaint.color(sky.alpenglow, 0)] as CFArray,
                                   locations: [0, 0.5, 1])!
            ctx.drawLinearGradient(alpen, start: CGPoint(x: 0, y: top),
                                   end: CGPoint(x: 0, y: snowLine + (top - snowLine) * 0.15),
                                   options: [.drawsBeforeStartLocation])
        }
        // Wind-blown drift lines across the snowfield.
        if textured {
        ctx.setStrokeColor(AdventPaint.color(0x9fb8cf, 0.22))
        ctx.setLineWidth(max(0.6, box.width * 0.0025))
        var drift = 0
        while drift < 6 {
            let level = top - (top - snowLine) * (0.12 + CGFloat(drift) * 0.15)
            ctx.move(to: CGPoint(x: box.minX, y: level))
            ctx.addQuadCurve(to: CGPoint(x: box.maxX, y: level - box.height * 0.012),
                             control: CGPoint(x: box.midX, y: level + box.height * 0.022))
            drift += 1
        }
        ctx.strokePath()
        // Faint strata across the rock: enough texture to stop it reading flat.
        ctx.setStrokeColor(AdventPaint.color(0x101a2c, 0.13))
        ctx.setLineWidth(max(0.6, box.width * 0.002))
        var band = 0
        while band < 7 {
            let level = box.minY + box.height * (0.08 + CGFloat(band) * 0.09)
            guard level < snowLine else { break }
            ctx.move(to: CGPoint(x: box.minX, y: level))
            ctx.addLine(to: CGPoint(x: box.maxX, y: level + box.height * 0.018))
            band += 1
        }
        ctx.strokePath()
        }
        if let sunlitSide {
            // One face in shadow gives the mass its volume.
            ctx.saveGState()
            ctx.addPath(sunlitSide)
            ctx.clip()
            let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                   colors: [AdventPaint.color(0x0f1a2e, 0.52),
                                            AdventPaint.color(0x0f1a2e, 0.18)] as CFArray,
                                   locations: [0, 1])!
            let side = sunlitSide.boundingBox
            ctx.drawLinearGradient(shade, start: CGPoint(x: side.minX, y: 0),
                                   end: CGPoint(x: side.maxX, y: 0),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }

    private static func drawMatterhorn(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let shape = layout.matterhorn
        guard shape.count > 3 else { return }
        let body = CGMutablePath()
        body.addLines(between: shape)
        body.closeSubpath()
        let box = body.boundingBox
        let summitIndex = layout.matterhornSummit
        let summit = shape[summitIndex]
        let glow = sky.alpenglowStrength
        func noise(_ n: Int, _ salt: Int) -> CGFloat { AdventLayout.noise(n, salt) }

        // Seen from Zermatt the horn shows two faces split by the Hörnli
        // ridge: the broad east face on the left takes the light, the north
        // face on the right stays in shadow all day. In winter both are
        // white, crossed by dark ribs of rock and the bands of its strata.
        let hornli = layout.matterhornRidge.count > 2 ? layout.matterhornRidge
            : [summit, CGPoint(x: summit.x - box.width * 0.3, y: box.minY)]
        let foot = hornli.last!
        let east = CGMutablePath()
        east.addLines(between: Array(shape[0...summitIndex]))
        for point in hornli.dropFirst() { east.addLine(to: point) }
        east.closeSubpath()
        let north = CGMutablePath()
        north.addLines(between: hornli)
        for point in shape[summitIndex...].reversed() where point.y < summit.y || point == shape.last! {
            north.addLine(to: point)
        }
        north.closeSubpath()

        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()

        // Rock first: warm grey where the light falls, blue-black in shadow.
        let darkRock = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(0x7c808e), AdventPaint.color(0xa1a4b0),
                                           AdventPaint.color(blend(0xc0c2cb, sky.alpenglow, glow * 0.3))] as CFArray,
                                  locations: [0, 0.6, 1])!
        ctx.drawLinearGradient(darkRock, start: CGPoint(x: 0, y: box.minY), end: CGPoint(x: 0, y: box.maxY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.saveGState()
        ctx.addPath(east)
        ctx.clip()
        let litRock = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                 colors: [AdventPaint.color(0x8e8d97),
                                          AdventPaint.color(blend(0xb2b0b9, sky.alpenglow, glow * 0.35)),
                                          AdventPaint.color(blend(0xcdcbd2, sky.alpenglow, glow * 0.6))] as CFArray,
                                 locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(litRock, start: CGPoint(x: 0, y: box.minY), end: CGPoint(x: 0, y: box.maxY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        // The face turns away from the light toward the ridge.
        let turn = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [AdventPaint.color(0x2c3346, 0), AdventPaint.color(0x2c3346, 0.16)] as CFArray,
                              locations: [0, 1])!
        ctx.drawLinearGradient(turn, start: CGPoint(x: box.minX + box.width * 0.18, y: 0),
                               end: CGPoint(x: summit.x - box.width * 0.02, y: 0), options: [])
        ctx.restoreGState()

        // Snow on rock: it lies on the ledges of the strata in ragged,
        // broken bands — thicker low down where the face eases off — and
        // runs down the couloirs, which all fan out from the summit.
        // The strata lie level in the mountain, so on the two faces of the
        // pyramid, seen from below, they fall away from the ridge on both
        // sides: a chevron with its point on the Hörnli ridge. Each face is
        // drawn in its own sheared space where the bands run straight.
        let ridgeSlope = (foot.x - summit.x) / min(-1, foot.y - summit.y)
        let ridgeOffset = summit.x - ridgeSlope * summit.y
        func ledges(in face: CGPath, snow: UInt32, coverage: CGFloat, salt: Int, side: CGFloat) {
            // On the broad east face the bands fall steeply to the left, as
            // in the photograph; on the north side they run flatter.
            let strata: CGFloat = side < 0 ? 0.55 : 0.22
            ctx.saveGState()
            ctx.addPath(face)
            ctx.clip()
            ctx.concatenate(CGAffineTransform(a: 1, b: -strata * side, c: 0, d: 1 + strata * side * ridgeSlope,
                                              tx: 0, ty: strata * side * ridgeOffset))
            // Rock is never one grey: big soft patches of lighter and darker
            // stone, then cracks running along the strata.
            for patch in 0..<26 {
                let centre = CGPoint(x: box.minX + box.width * noise(patch, salt + 40),
                                     y: box.minY + box.height * (0.1 + noise(patch, salt + 41) * 0.85))
                let light = patch % 3 == 0
                ctx.saveGState()
                ctx.translateBy(x: centre.x, y: centre.y)
                ctx.scaleBy(x: 1.8, y: 0.7)
                AdventPaint.glow(ctx, at: .zero, radius: box.width * (0.04 + noise(patch, salt + 42) * 0.07),
                                 light ? 0xaaa3ad : 0x1b2030, light ? 0.34 : 0.40)
                ctx.restoreGState()
            }
            ctx.setLineJoin(.miter)
            for crack in 0..<60 {
                var point = CGPoint(x: box.minX + box.width * noise(crack, salt + 50),
                                    y: box.minY + box.height * (0.12 + noise(crack, salt + 51) * 0.82))
                let path = CGMutablePath()
                path.move(to: point)
                for step in 0..<5 {
                    point = CGPoint(x: point.x + box.width * (0.012 + noise(crack * 9 + step, salt + 52) * 0.02),
                                    y: point.y + (noise(crack * 7 + step, salt + 53) - 0.45) * box.height * 0.012)
                    path.addLine(to: point)
                }
                ctx.setStrokeColor(AdventPaint.color(0x141824, 0.55))
                ctx.setLineWidth(max(0.6, box.width * 0.0028))
                ctx.addPath(path)
                ctx.strokePath()
                // The lit lip above each crack.
                ctx.saveGState()
                ctx.translateBy(x: 0, y: max(0.5, box.height * 0.003))
                ctx.setStrokeColor(AdventPaint.color(0xc2bcc6, 0.32))
                ctx.addPath(path)
                ctx.strokePath()
                ctx.restoreGState()
            }
            // Fine gullies down the fall line and powder caught on the rough
            // face, so the rock is not a flat sheet.
            ctx.setLineCap(.round)
            for streak in 0..<40 {
                let start = CGPoint(x: box.minX + box.width * noise(streak, salt + 20),
                                    y: box.minY + box.height * (0.15 + noise(streak, salt + 21) * 0.8))
                let dx = start.x - summit.x, dy = start.y - summit.y
                let norm = max(1, hypot(dx, dy))
                let length = box.height * (0.04 + noise(streak, salt + 22) * 0.10)
                let dark = streak % 3 != 0
                ctx.setStrokeColor(AdventPaint.color(dark ? 0x1e2333 : 0xc9d2de, dark ? 0.22 : 0.18))
                ctx.setLineWidth(max(0.4, box.width * (0.0015 + noise(streak, salt + 23) * 0.002)))
                ctx.move(to: start)
                ctx.addLine(to: CGPoint(x: start.x + dx / norm * length, y: start.y + dy / norm * length))
                ctx.strokePath()
            }
            // Powder lies in thin flecks along small steps, not as round dots.
            ctx.setStrokeColor(AdventPaint.color(snow, 0.45))
            for speck in 0..<120 {
                let point = CGPoint(x: box.minX + box.width * noise(speck, salt + 30),
                                    y: box.minY + box.height * noise(speck, salt + 31))
                let length = box.width * (0.006 + noise(speck, salt + 32) * 0.014)
                ctx.setLineWidth(max(0.4, box.width * 0.0022))
                ctx.move(to: point)
                ctx.addLine(to: CGPoint(x: point.x + length, y: point.y + length * 0.12))
                ctx.strokePath()
            }
            let bands = 58
            for band in 0..<bands {
                let height = CGFloat(band) / CGFloat(bands)
                let level = box.minY + box.height * (0.03 + height * 0.92 + (noise(band, salt) - 0.5) * 0.015)
                let keep = coverage * (1.08 - height * 0.45)
                var x = box.minX + box.width * noise(band, salt + 1) * 0.05
                var piece = 0
                let bandPath = CGMutablePath()
                var deepest: CGFloat = 0
                while x < box.maxX {
                    let length = box.width * (0.006 + noise(band * 17 + piece, salt + 2) * 0.034)
                    let gap = box.width * (0.003 + noise(band * 13 + piece, salt + 3) * 0.016)
                    defer { x += length + gap; piece += 1 }
                    guard noise(band * 29 + piece, salt + 6) < keep else { continue }
                    let thick = box.height * (0.003 + noise(band * 11 + piece, salt + 4) * 0.008)
                        * (1.3 - height * 0.6)
                    deepest = max(deepest, thick)
                    let dip: CGFloat = 0
                    let lift = (noise(band * 19 + piece, salt + 7) - 0.5) * thick * 0.6
                    bandPath.move(to: CGPoint(x: x, y: level + dip))
                    // A rounded cushion on top instead of a straight cut edge.
                    bandPath.addQuadCurve(to: CGPoint(x: x + length, y: level + dip + box.height * 0.002),
                                          control: CGPoint(x: x + length * 0.5, y: level + dip + lift + thick * 0.45))
                    // Ragged underside where the snow hangs off the ledge.
                    let teeth = 5
                    for tooth in stride(from: teeth, through: 1, by: -1) {
                        let t = (CGFloat(tooth) - 0.5) / CGFloat(teeth)
                        let depth = thick * (0.35 + noise(band * 7 + piece * 5 + tooth, salt + 5) * 1.1)
                        bandPath.addLine(to: CGPoint(x: x + length * t, y: level + dip - depth))
                    }
                    bandPath.closeSubpath()
                }
                guard !bandPath.isEmpty else { continue }
                // The ledge throws a soft shadow onto the rock below it.
                ctx.saveGState()
                ctx.translateBy(x: box.width * 0.003, y: -deepest * 0.35)
                ctx.setFillColor(AdventPaint.color(0x141a28, 0.30))
                ctx.addPath(bandPath)
                ctx.fillPath()
                ctx.restoreGState()
                // Lit on its upper cushion, cooler where it curls under.
                ctx.saveGState()
                ctx.addPath(bandPath)
                ctx.clip()
                let top = level + box.height * 0.014 + deepest * 0.45
                let shade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                       colors: [AdventPaint.color(multiply(snow, 0xa9b9d6)),
                                                AdventPaint.color(multiply(snow, 0xdde6f2)),
                                                AdventPaint.color(snow)] as CFArray,
                                       locations: [0, 0.55, 1])!
                ctx.drawLinearGradient(shade, start: CGPoint(x: 0, y: level - deepest * 1.4),
                                       end: CGPoint(x: 0, y: top),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
                ctx.restoreGState()
            }
            ctx.restoreGState()
        }
        func couloirs(in face: CGPath, snow: UInt32, count: Int, salt: Int) {
            ctx.saveGState()
            ctx.addPath(face)
            ctx.clip()
            ctx.setFillColor(AdventPaint.color(snow, 0.95))
            var made = 0
            var tries = 0
            while made < count, tries < count * 10 {
                tries += 1
                let start = CGPoint(x: box.minX + box.width * noise(tries, salt),
                                    y: box.minY + box.height * (0.35 + noise(tries, salt + 1) * 0.55))
                guard face.contains(start) else { continue }
                made += 1
                let dx = start.x - summit.x, dy = start.y - summit.y
                let norm = max(1, hypot(dx, dy))
                let dir = CGPoint(x: dx / norm, y: dy / norm)
                let length = box.height * (0.08 + noise(tries, salt + 2) * 0.18)
                let width = box.width * (0.004 + noise(tries, salt + 3) * 0.006)
                let steps = 7
                var left: [CGPoint] = [], right: [CGPoint] = []
                for k in 0...steps {
                    let t = CGFloat(k) / CGFloat(steps)
                    let wiggle = (noise(tries * 17 + k, salt + 4) - 0.5) * box.width * 0.010
                    let centre = CGPoint(x: start.x + dir.x * length * t + wiggle,
                                         y: start.y + dir.y * length * t)
                    // Narrow at the top, fanning where it spills onto a ledge.
                    let half = width * (0.35 + t * 0.9) * (0.7 + noise(tries * 23 + k, salt + 5) * 0.6)
                    left.append(CGPoint(x: centre.x - half * -dir.y, y: centre.y - half * dir.x))
                    right.append(CGPoint(x: centre.x + half * -dir.y, y: centre.y + half * dir.x))
                }
                let path = CGMutablePath()
                path.addLines(between: left)
                path.addLines(between: right.reversed())
                path.closeSubpath()
                ctx.addPath(path)
            }
            ctx.fillPath()
            ctx.restoreGState()
        }
        let litSnow = blend(0xf3f6fa, sky.alpenglow, glow * 0.7)
        let shadeSnow = blend(0xe2e7ef, sky.alpenglow, glow * 0.3)
        ledges(in: east, snow: litSnow, coverage: 0.85, salt: 520, side: -1)
        couloirs(in: east, snow: litSnow, count: 22, salt: 540)
        ledges(in: north, snow: shadeSnow, coverage: 0.9, salt: 560, side: 1)
        couloirs(in: north, snow: shadeSnow, count: 14, salt: 580)

        // Light and shade as in the photograph from Zermatt.
        func blob(_ points: [CGPoint]) -> CGPath {
            let path = CGMutablePath()
            guard points.count > 2 else { return path }
            func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
            path.move(to: mid(points[points.count - 1], points[0]))
            for index in 0..<points.count {
                path.addQuadCurve(to: mid(points[index], points[(index + 1) % points.count]), control: points[index])
            }
            path.closeSubpath()
            return path
        }
        let patches = layout.matterhornPatches
        if patches.count == 7 {
            // The snowfield under the north face and the glacier bands at the
            // foot: bright, a little bluer where they fall away, with crevasses.
            for (index, points) in patches.enumerated() where index >= 2 && index != 5 {
                let field = blob(points)
                let frame = field.boundingBox
                let white = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                       colors: [AdventPaint.color(blend(0xf7f9fc, sky.alpenglow, glow * 0.6)),
                                                AdventPaint.color(blend(0xd6dfec, sky.alpenglow, glow * 0.25))] as CFArray,
                                       locations: [0, 1])!
                ctx.saveGState()
                ctx.addPath(field)
                ctx.clip()
                // Snow plastered on steep rock lets the strata show through.
                if index == 6 { ctx.setAlpha(0.78) }
                ctx.drawLinearGradient(white, start: CGPoint(x: 0, y: frame.maxY), end: CGPoint(x: 0, y: frame.minY), options: [])
                ctx.setStrokeColor(AdventPaint.color(0x8d9bb3, 0.45))
                ctx.setLineWidth(max(0.5, box.width * 0.0018))
                for crack in 0..<7 {
                    let y = frame.minY + frame.height * (0.15 + CGFloat(crack) * 0.11)
                    let x0 = frame.minX + frame.width * noise(crack, 700 + index) * 0.4
                    ctx.move(to: CGPoint(x: x0, y: y))
                    ctx.addLine(to: CGPoint(x: x0 + frame.width * (0.2 + noise(crack, 710 + index) * 0.4), y: y - frame.height * 0.05))
                }
                ctx.strokePath()
                ctx.restoreGState()
            }
            // The gully beside the Hörnli rib lies in soft shade.
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: box.width * 0.012, color: AdventPaint.color(0x4c5366, 0.6))
            ctx.setFillColor(AdventPaint.color(blend(0x5f6577, sky.alpenglow, glow * 0.2), 0.42))
            ctx.addPath(blob(patches[5]))
            ctx.fillPath()
            ctx.restoreGState()
            // The deep blue shadow under the north-face skyline, soft-edged.
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: box.width * 0.018, color: AdventPaint.color(0x2f3850, 0.9))
            ctx.setFillColor(AdventPaint.color(blend(0x56607b, sky.alpenglow, glow * 0.15), 0.66))
            ctx.addPath(blob(patches[1]))
            ctx.fillPath()
            ctx.restoreGState()
            // The dark rock head of the summit, too steep for snow.
            ctx.saveGState()
            // Soft-edged: the rock head blends into the snowy face below it.
            let headTone = blend(0x8a7d74, sky.alpenglow, glow * 0.4)
            let head = blob(patches[0])
            let headBox = head.boundingBox
            ctx.addPath(head)
            ctx.clip()
            let fade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(headTone, 0.78), AdventPaint.color(headTone, 0.6),
                                           AdventPaint.color(headTone, 0)] as CFArray,
                                  locations: [0, 0.55, 1])!
            ctx.drawLinearGradient(fade, start: CGPoint(x: 0, y: headBox.maxY), end: CGPoint(x: 0, y: headBox.minY), options: [])
            ctx.restoreGState()
        }

        // Alpenglow: when the sun is low only the top of the horn still
        // catches it and burns orange-pink, fading down into the shadow that
        // already fills the valley. The lit east face burns brightest.
        if glow > 0.02 {
            let reach = box.height * 0.62
            let burn = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(sky.alpenglow, 0.80 * glow),
                                           AdventPaint.color(sky.alpenglow, 0.34 * glow),
                                           AdventPaint.color(sky.alpenglow, 0)] as CFArray,
                                  locations: [0, 0.45, 1])!
            ctx.saveGState()
            ctx.setBlendMode(.screen)
            ctx.addPath(east)
            ctx.clip()
            ctx.drawLinearGradient(burn, start: CGPoint(x: 0, y: summit.y), end: CGPoint(x: 0, y: summit.y - reach),
                                   options: [.drawsBeforeStartLocation])
            ctx.restoreGState()
            ctx.saveGState()
            ctx.setBlendMode(.screen)
            ctx.setAlpha(0.45)
            ctx.addPath(north)
            ctx.clip()
            ctx.drawLinearGradient(burn, start: CGPoint(x: 0, y: summit.y), end: CGPoint(x: 0, y: summit.y - reach * 0.7),
                                   options: [.drawsBeforeStartLocation])
            ctx.restoreGState()
        }

        // Below the steep horn the slope eases into a snowfield.
        let apron = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [AdventPaint.color(0xdfe6ef, 0.95), AdventPaint.color(0xdfe6ef, 0)] as CFArray,
                               locations: [0, 1])!
        ctx.drawLinearGradient(apron, start: CGPoint(x: 0, y: box.minY),
                               end: CGPoint(x: 0, y: box.minY + box.height * 0.16), options: [])

        // The Hörnli ridge: a bright snow crest with a dark drop behind it,
        // the sunlit strip along its left side catching the eye as in the
        // photograph.
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ctx.setStrokeColor(AdventPaint.color(blend(0xffffff, sky.alpenglow, glow * 0.6), 0.32))
        ctx.setLineWidth(max(2, box.width * 0.022))
        ctx.beginPath()
        ctx.addLines(between: hornli.map { CGPoint(x: $0.x - box.width * 0.010, y: $0.y) })
        ctx.strokePath()
        ctx.setStrokeColor(AdventPaint.color(0x2b3245, 0.28))
        ctx.setLineWidth(max(1, box.width * 0.008))
        ctx.beginPath()
        ctx.addLines(between: hornli.map { CGPoint(x: $0.x + box.width * 0.006, y: $0.y) })
        ctx.strokePath()
        ctx.setStrokeColor(AdventPaint.color(blend(0xf8fbff, sky.alpenglow, glow * 0.6), 0.7))
        ctx.setLineWidth(max(0.8, box.width * 0.004))
        ctx.beginPath()
        ctx.addLines(between: hornli)
        ctx.strokePath()

        // Snow lying on the flat Hörnli shoulder of the left skyline.
        if layout.matterhornShoulder.count > 1 {
            ctx.setStrokeColor(AdventPaint.color(blend(0xeef3f9, sky.alpenglow, glow * 0.5), 0.95))
            ctx.setLineWidth(max(1.4, box.height * 0.022))
            ctx.beginPath()
            ctx.addLines(between: layout.matterhornShoulder.map { CGPoint(x: $0.x, y: $0.y - box.height * 0.006) })
            ctx.strokePath()
        }

        // Shadow pooling at the foot, where the horn meets the glacier.
        let base = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [AdventPaint.color(0x2a3550, 0.35), AdventPaint.color(0x2a3550, 0)] as CFArray,
                              locations: [0, 1])!
        ctx.drawLinearGradient(base, start: CGPoint(x: 0, y: box.minY),
                               end: CGPoint(x: 0, y: box.minY + box.height * 0.22), options: [])
        ctx.restoreGState()

        // Snow along the short summit ridge to the Italian top, so the
        // crooked tip reads as one white crest.
        let crestEnd = shape[summitIndex...].firstIndex { $0.x > summit.x + box.width * 0.10 || $0.y < summit.y - box.height * 0.035 } ?? summitIndex
        if crestEnd > summitIndex + 1 {
            ctx.setStrokeColor(AdventPaint.color(blend(0xf4f7fb, sky.alpenglow, glow * 0.6), 0.95))
            ctx.setLineWidth(max(1, box.width * 0.005))
            ctx.beginPath()
            ctx.addLines(between: Array(shape[summitIndex..<crestEnd]).map { CGPoint(x: $0.x, y: $0.y - box.height * 0.003) })
            ctx.strokePath()
        }
    }

    /// The glacier tongue below the Matterhorn, with its crevasses.
    private static func drawGlacier(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let ice = layout.glacier
        guard !ice.isEmpty else { return }
        let tongue = CGMutablePath()
        tongue.move(to: CGPoint(x: ice.minX, y: ice.maxY))
        tongue.addCurve(to: CGPoint(x: ice.midX - ice.width * 0.06, y: ice.minY),
                        control1: CGPoint(x: ice.minX + ice.width * 0.10, y: ice.midY),
                        control2: CGPoint(x: ice.minX + ice.width * 0.30, y: ice.minY + ice.height * 0.12))
        tongue.addCurve(to: CGPoint(x: ice.maxX, y: ice.maxY),
                        control1: CGPoint(x: ice.maxX - ice.width * 0.22, y: ice.minY + ice.height * 0.10),
                        control2: CGPoint(x: ice.maxX - ice.width * 0.04, y: ice.midY))
        tongue.closeSubpath()
        ctx.saveGState()
        ctx.addPath(tongue)
        ctx.clip()
        let field = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                               colors: [AdventPaint.color(blend(0x9dc3dd, sky.horizon, 0.25)),
                                        AdventPaint.color(0xeef7fd)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(field, start: CGPoint(x: 0, y: ice.minY),
                               end: CGPoint(x: 0, y: ice.maxY), options: [.drawsBeforeStartLocation,
                                                                          .drawsAfterEndLocation])
        ctx.setStrokeColor(AdventPaint.color(0x5f93b8, 0.55))
        ctx.setLineWidth(max(0.7, ice.height * 0.035))
        for crevasse in 0..<6 {
            let t = (CGFloat(crevasse) + 0.6) / 6
            let y = ice.minY + ice.height * t
            ctx.move(to: CGPoint(x: ice.minX + ice.width * (0.10 + t * 0.12), y: y))
            ctx.addQuadCurve(to: CGPoint(x: ice.maxX - ice.width * (0.08 + t * 0.14), y: y + ice.height * 0.02),
                             control: CGPoint(x: ice.midX, y: y - ice.height * 0.05))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Forest climbing the lower slopes and stopping at the tree line.
    /// Groomed runs: a brighter band of packed snow with fine corduroy and a
    /// row of marker poles along the edge.
    private static func drawPistes(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let width = layout.bounds.height * 0.013
        for run in layout.pistes {
            AdventPaint.stroke(ctx, run, 0xc9d6e4, width * 1.25, alpha: 0.55)
            AdventPaint.stroke(ctx, run, 0xf7fafd, width)
            // Freshly groomed corduroy: fine furrows running along the run,
            // following every bend, as the piste machine leaves them.
            for lane in [-0.33, -0.11, 0.11, 0.33] as [CGFloat] {
                var furrow: [CGPoint] = []
                for (index, point) in run.enumerated() {
                    let before = run[max(0, index - 1)], after = run[min(run.count - 1, index + 1)]
                    let dx = after.x - before.x, dy = after.y - before.y
                    let length = max(0.001, hypot(dx, dy))
                    furrow.append(CGPoint(x: point.x - dy / length * width * lane, y: point.y + dx / length * width * lane))
                }
                AdventPaint.stroke(ctx, furrow, blend(0xc9d6e4, sky.horizon, 0.15), max(0.35, width * 0.05), alpha: 0.55)
            }
            // Marker poles stand at the edges of the run, never in it: each
            // set out square to the run's direction, left and right in turn.
            for (index, point) in run.enumerated() where index % 3 == 1 {
                let before = run[max(0, index - 1)], after = run[min(run.count - 1, index + 1)]
                let dx = after.x - before.x, dy = after.y - before.y
                let length = max(0.001, hypot(dx, dy))
                let side: CGFloat = (index / 3) % 2 == 0 ? 1 : -1
                let foot = CGPoint(x: point.x - dy / length * width * 0.78 * side, y: point.y + dx / length * width * 0.78 * side)
                AdventPaint.stroke(ctx, [foot, CGPoint(x: foot.x, y: foot.y + width * 0.6)],
                                   index % 6 == 1 ? 0xc23b32 : 0x2f3440, max(0.5, width * 0.08))
            }
        }
    }

    private static func drawTreeLine(_ layout: AdventLayout, ridge: Int, sky: AdventSky, in ctx: CGContext) {
        let base: UInt32 = [0x2f4a5c, 0x27404f, 0x203744][min(2, ridge)]
        let shade = blend(base, sky.horizon, 0.45 - CGFloat(ridge) * 0.12)
        for tree in layout.treeLine where tree.ridge == ridge {
            AdventPaint.fir(ctx, x: tree.x, y: tree.y, size: tree.size, fill: shade, snow: 0xdbe8f0)
        }
    }

    /// The same layered rock as on the Matterhorn, for every other peak:
    /// under each summit thin bands of rock and snow-covered ledges fall
    /// away to both sides, fading out down the flanks and to the sides.
    private static func drawStrata(_ ctx: CGContext, body: CGPath, points: [CGPoint], bounds: CGRect,
                                   sky: AdventSky, strength: CGFloat, salt: Int) {
        guard points.count > 4 else { return }
        var peaks: [CGPoint] = []
        for index in 1..<(points.count - 1) {
            let peak = points[index]
            let low = max(0, index - 4), high = min(points.count - 1, index + 4)
            guard (low...high).allSatisfy({ points[$0].y <= peak.y }) else { continue }
            let floor = (low...high).map { points[$0].y }.min() ?? peak.y
            guard peak.y - floor > bounds.height * 0.012 else { continue }
            if let last = peaks.last, abs(last.x - peak.x) < bounds.width * 0.03 { continue }
            peaks.append(peak)
        }
        let crack = blend(0x2a3142, sky.horizon, 0.3)
        let snow = blend(0xf4f8fc, sky.alpenglow, sky.alpenglowStrength * 0.4)
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        ctx.setLineCap(.round)
        func crest(_ x: CGFloat) -> CGFloat {
            guard let next = points.firstIndex(where: { $0.x >= x }), next > 0 else { return points.first?.y ?? 0 }
            let a = points[next - 1], b = points[next]
            let t = (x - a.x) / max(0.001, b.x - a.x)
            return a.y + (b.y - a.y) * t
        }
        for (number, peak) in peaks.enumerated() {
            let depth = bounds.height * 0.17
            let reach = bounds.width * 0.085
            // Ribs of bare rock running down from the crest, snow between
            // them, darker on the shaded side: the pattern of the Matterhorn.
            for side: CGFloat in [-1, 1] {
                let ribs = 4
                for rib in 0..<ribs {
                    let n = number * 37 + rib * 5 + (side < 0 ? 0 : 100)
                    let along = 0.06 + (CGFloat(rib) + AdventLayout.noise(n, salt + 20) * 0.6) / CGFloat(ribs) * 0.85
                    let top = CGPoint(x: peak.x + side * reach * along, y: 0)
                    let start = CGPoint(x: top.x, y: crest(top.x) - bounds.height * 0.002)
                    let length = depth * (0.35 + AdventLayout.noise(n, salt + 21) * 0.45) * (1 - along * 0.5)
                    let lean = side * (0.25 + AdventLayout.noise(n, salt + 22) * 0.35)
                    let width = reach * (0.05 + AdventLayout.noise(n, salt + 23) * 0.05)
                    var left: [CGPoint] = [], right: [CGPoint] = []
                    let steps = 6
                    for k in 0...steps {
                        let t = CGFloat(k) / CGFloat(steps)
                        let wobble = (AdventLayout.noise(n * 11 + k, salt + 24) - 0.5) * width * 0.9
                        let centre = CGPoint(x: start.x + lean * length * t + wobble, y: start.y - length * t)
                        let half = width * (1 - t * 0.85) * (0.6 + AdventLayout.noise(n * 13 + k, salt + 25) * 0.8)
                        left.append(CGPoint(x: centre.x - half, y: centre.y))
                        right.append(CGPoint(x: centre.x + half, y: centre.y))
                    }
                    let path = CGMutablePath()
                    path.addLines(between: left)
                    path.addLines(between: right.reversed())
                    path.closeSubpath()
                    let tone = side < 0 ? blend(crack, 0x9aa3b4, 0.45) : crack
                    ctx.setFillColor(AdventPaint.color(tone, (side < 0 ? 0.42 : 0.55) * strength))
                    ctx.addPath(path)
                    ctx.fillPath()
                }
            }
            for side: CGFloat in [-1, 1] {
                let slope: CGFloat = side < 0 ? 0.45 : 0.30
                ctx.saveGState()
                ctx.clip(to: CGRect(x: side < 0 ? peak.x - reach : peak.x, y: peak.y - depth, width: reach, height: depth))
                ctx.concatenate(CGAffineTransform(a: 1, b: -side * slope, c: 0, d: 1, tx: 0, ty: side * slope * peak.x))
                let step = bounds.height * 0.0085
                var level = peak.y + reach * slope
                var band = 0
                while level > peak.y - depth - reach * slope {
                    defer { level -= step * (0.7 + AdventLayout.noise(band, salt + number * 7) * 0.6); band += 1 }
                    var x = side < 0 ? peak.x - reach : peak.x
                    var piece = 0
                    while x < (side < 0 ? peak.x : peak.x + reach) {
                        let length = bounds.width * (0.004 + AdventLayout.noise(band * 17 + piece, salt + 1) * 0.014)
                        let gap = bounds.width * (0.002 + AdventLayout.noise(band * 13 + piece, salt + 2) * 0.010)
                        defer { x += length + gap; piece += 1 }
                        guard AdventLayout.noise(band * 29 + piece + number * 5, salt + 3) < 0.55 else { continue }
                        // Fade with the distance below the summit and out to the side.
                        let shifted = level - side * slope * (peak.x - (x + length / 2)) * -1
                        let down = max(0, min(1, (peak.y - shifted) / depth))
                        let across = min(1, abs(x + length / 2 - peak.x) / reach)
                        let alpha = strength * (1 - down) * (1 - across * 0.85)
                        guard alpha > 0.03 else { continue }
                        ctx.setStrokeColor(AdventPaint.color(crack, 0.32 * alpha))
                        ctx.setLineWidth(max(0.5, bounds.height * 0.0012))
                        ctx.move(to: CGPoint(x: x, y: level))
                        ctx.addLine(to: CGPoint(x: x + length, y: level))
                        ctx.strokePath()
                        ctx.setStrokeColor(AdventPaint.color(snow, 0.6 * alpha))
                        ctx.setLineWidth(max(0.5, bounds.height * 0.0016))
                        ctx.move(to: CGPoint(x: x + length * 0.08, y: level + bounds.height * 0.0016))
                        ctx.addLine(to: CGPoint(x: x + length * 0.92, y: level + bounds.height * 0.0016))
                        ctx.strokePath()
                    }
                }
                ctx.restoreGState()
            }
        }
        ctx.restoreGState()
    }

    private static func drawSkyline(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let bounds = layout.bounds
        for (index, ridge) in layout.skyline.enumerated() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
            path.addLines(between: ridge.points)
            path.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
            path.closeSubpath()
            let top = ridge.points.map(\.y).max() ?? bounds.maxY
            let base = ridge.points.first?.y ?? bounds.minY
            paintMassif(ctx, body: path, sunlitSide: nil,
                        rock: blend(ridge.fill, sky.horizon, 0.34),
                        snow: blend(0xf2f6fb, sky.horizon, 0.22),
                        snowLine: ridge.snowLine, top: top, sky: sky,
                        glow: sky.alpenglowStrength * 0.7, textured: false)
            drawStrata(ctx, body: path, points: ridge.points, bounds: bounds, sky: sky, strength: 0.55, salt: 900 + index * 11)
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            // Light from the left: each summit has a cool shadowed face on
            // its right, fading down into the glacier below.
            let points = ridge.points
            let shade = blend(0x3a5274, sky.horizon, 0.25)
            var peakIndex = 1
            while peakIndex + 1 < points.count {
                let peak = points[peakIndex]
                guard peak.y >= points[peakIndex - 1].y, peak.y > points[peakIndex + 1].y else { peakIndex += 1; continue }
                var valleyIndex = peakIndex + 1
                while valleyIndex < points.count - 1, points[valleyIndex + 1].y < points[valleyIndex].y { valleyIndex += 1 }
                let valley = points[valleyIndex]
                let rise = peak.y - valley.y
                let span = max(1, valley.x - peak.x)
                // The closing point at the screen edge is not a real valley: a
                // face down to it is a needle-thin wedge.
                guard rise > bounds.height * 0.004, valleyIndex < points.count - 1,
                      span > bounds.width * 0.025 else { peakIndex += 1; continue }
                let foot = max(base, peak.y - rise * 2.6 - bounds.height * 0.02)
                let face = CGMutablePath()
                face.move(to: peak)
                for along in (peakIndex + 1)...valleyIndex { face.addLine(to: points[along]) }
                face.addLine(to: CGPoint(x: valley.x - span * 0.15, y: foot))
                for k in stride(from: 5, through: 1, by: -1) {
                    let t = CGFloat(k) / 6
                    let jitter = (AdventLayout.noise(peakIndex * 17 + k + index * 5, 470) - 0.5) * span * 0.18
                    face.addLine(to: CGPoint(x: peak.x + span * 0.25 * t + jitter, y: peak.y + (foot - peak.y) * t))
                }
                face.closeSubpath()
                ctx.saveGState()
                ctx.addPath(face)
                ctx.clip()
                let fade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: [AdventPaint.color(shade, 0.34), AdventPaint.color(shade, 0.12),
                                               AdventPaint.color(shade, 0)] as CFArray, locations: [0, 0.5, 1])!
                ctx.drawLinearGradient(fade, start: CGPoint(x: 0, y: peak.y), end: CGPoint(x: 0, y: foot), options: [])
                ctx.restoreGState()
                peakIndex += 1
            }
            // Rock breaking through the snow: small irregular outcrops scattered
            // over the upper face, never in pairs at one height (those read as
            // eyes), each a ragged blot lit on its left.
            for crag in 0..<14 {
                let x = (points.dropFirst().first?.x ?? bounds.minX) + ((points.dropLast().last?.x ?? bounds.maxX)
                    - (points.dropFirst().first?.x ?? bounds.minX)) * AdventLayout.noise(crag, 494 + index)
                let crest = AdventLayout.height(of: ridge, at: x)
                guard crest - base > (top - base) * 0.45 else { continue }
                let y = crest - (crest - base) * (0.12 + AdventLayout.noise(crag, 495 + index) * 0.35)
                let size = bounds.height * (0.004 + AdventLayout.noise(crag, 496 + index) * 0.007)
                let blot = CGMutablePath()
                for k in 0..<7 {
                    let a = CGFloat(k) / 7 * .pi * 2
                    let r = size * (0.6 + AdventLayout.noise(crag * 13 + k, 497 + index) * 0.8)
                    let point = CGPoint(x: x + cos(a) * r * 1.3, y: y + sin(a) * r * (0.8 + 0.6 * max(0, -sin(a))))
                    if k == 0 { blot.move(to: point) } else { blot.addLine(to: point) }
                }
                blot.closeSubpath()
                // Layered rock like the Matterhorn's, not a stain: a shaded
                // body, a ledge line across it and snow lying on its top.
                ctx.saveGState()
                ctx.addPath(blot)
                ctx.clip()
                let rockLit = blend(0x7d8698, sky.horizon, 0.35)
                let rockDark = blend(0x4a5468, sky.horizon, 0.35)
                let body = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: [AdventPaint.color(rockLit, 0.5), AdventPaint.color(rockDark, 0.45)] as CFArray,
                                      locations: [0, 1])!
                ctx.drawLinearGradient(body, start: CGPoint(x: x - size * 1.3, y: 0), end: CGPoint(x: x + size * 1.3, y: 0), options: [])
                // Snow lies over the top of the rock and ends in a ragged edge.
                let cap = CGMutablePath()
                cap.move(to: CGPoint(x: x - size * 2, y: y + size * 2))
                cap.addLine(to: CGPoint(x: x + size * 2, y: y + size * 2))
                for k in stride(from: 8, through: 0, by: -1) {
                    let t = CGFloat(k) / 8
                    let wave = (AdventLayout.noise(crag * 11 + k, 498 + index) - 0.5) * size * 0.7
                    cap.addLine(to: CGPoint(x: x - size * 2 + size * 4 * t, y: y + size * 0.1 + wave - (t - 0.5) * size * 0.4))
                }
                cap.closeSubpath()
                ctx.setFillColor(AdventPaint.color(blend(0xf2f6fb, sky.horizon, 0.22), 0.92))
                ctx.addPath(cap)
                ctx.fillPath()
                ctx.restoreGState()
            }
            // Glaciers: soft curved flow lines on the lower snowfields.
            ctx.setStrokeColor(AdventPaint.color(blend(0x9fb6cc, sky.horizon, 0.3), 0.35))
            ctx.setLineWidth(max(0.5, bounds.height * 0.0015))
            let left = points.dropFirst().first?.x ?? bounds.minX
            let right = points.dropLast().last?.x ?? bounds.maxX
            for flow in 0..<4 {
                let y = base + (top - base) * (0.12 + CGFloat(flow) * 0.09)
                ctx.move(to: CGPoint(x: left + (right - left) * 0.12, y: y))
                ctx.addQuadCurve(to: CGPoint(x: right - (right - left) * 0.12, y: y - bounds.height * 0.004),
                                 control: CGPoint(x: (left + right) / 2, y: y - bounds.height * 0.018))
            }
            ctx.strokePath()
            // Distance: the air between us and the far massifs.
            let air = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                 colors: [AdventPaint.color(sky.horizon, 0.40), AdventPaint.color(sky.horizon, 0.08)] as CFArray,
                                 locations: [0, 1])!
            ctx.drawLinearGradient(air, start: CGPoint(x: 0, y: base), end: CGPoint(x: 0, y: top), options: [])
            ctx.restoreGState()
        }
    }

    /// The rocky ridge falling from the left in front of the Matterhorn, as
    /// in the photograph from Zermatt: broken bands of layered rock under
    /// its crest, snow lying on every ledge.
    private static func drawFrontRock(_ layout: AdventLayout, ridge: AdventLayout.Ridge, body: CGPath,
                                      sky: AdventSky, in ctx: CGContext) {
        let bounds = layout.bounds
        let start = bounds.minX + bounds.width * 0.055, end = bounds.minX + bounds.width * 0.27
        ctx.saveGState()
        ctx.addPath(body)
        ctx.clip()
        for band in 0..<11 {
            let drop = bounds.height * (0.008 + CGFloat(band) * 0.0068)
            let from = start + bounds.width * 0.006 * CGFloat(band)
            let to = end - bounds.width * 0.012 * CGFloat(band)
            guard to > from else { continue }
            var x = from + bounds.width * AdventLayout.noise(band, 865) * 0.01
            var piece = 0
            while x < to {
                let length = bounds.width * (0.005 + AdventLayout.noise(band * 19 + piece, 860) * 0.016)
                let gap = bounds.width * (0.002 + AdventLayout.noise(band * 23 + piece, 861) * 0.012)
                defer { x += length + gap; piece += 1 }
                guard AdventLayout.noise(band * 37 + piece, 866) < 0.8 else { continue }
                let x1 = min(to, x + length)
                let wobble = (AdventLayout.noise(band * 29 + piece, 863) - 0.5) * bounds.height * 0.006
                let tilt = (AdventLayout.noise(band * 31 + piece, 864) - 0.5) * bounds.height * 0.004
                let y0 = AdventLayout.height(of: ridge, at: x) - drop + wobble
                let y1 = AdventLayout.height(of: ridge, at: x1) - drop + wobble + tilt
                let thick = bounds.height * (0.0025 + AdventLayout.noise(band * 7 + piece, 862) * 0.0035)
                // A rock step: flat top under the snow, ragged underside.
                let rock = CGMutablePath()
                rock.move(to: CGPoint(x: x, y: y0))
                rock.addLine(to: CGPoint(x: x1, y: y1))
                let teeth = 4
                for tooth in stride(from: teeth, through: 0, by: -1) {
                    let t = CGFloat(tooth) / CGFloat(teeth)
                    let depth = thick * (0.6 + AdventLayout.noise(band * 11 + piece * 5 + tooth, 867) * 0.9)
                    rock.addLine(to: CGPoint(x: x + (x1 - x) * t, y: y0 + (y1 - y0) * t - depth))
                }
                rock.closeSubpath()
                let tone = blend(0x5d5652, 0x7c7571, AdventLayout.noise(band * 3 + piece, 868))
                ctx.setFillColor(AdventPaint.color(blend(tone, sky.horizon, 0.15), 0.55))
                ctx.addPath(rock)
                ctx.fillPath()
                // Snow on the ledge above the rock, a soft cushion.
                ctx.setStrokeColor(AdventPaint.color(0xf2f6fa, 0.9))
                ctx.setLineWidth(max(0.5, thick * 0.55))
                ctx.move(to: CGPoint(x: x + (x1 - x) * 0.04, y: y0 + thick * 0.2))
                ctx.addLine(to: CGPoint(x: x1 - (x1 - x) * 0.04, y: y1 + thick * 0.2))
                ctx.strokePath()
            }
        }
        ctx.restoreGState()
    }

    private static func drawRidges(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        for (index, ridge) in layout.ridges.enumerated() {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: layout.bounds.minX, y: layout.bounds.minY))
            path.addLines(between: ridge.points)
            path.addLine(to: CGPoint(x: layout.bounds.maxX, y: layout.bounds.minY))
            path.closeSubpath()
            let top = ridge.points.map(\.y).max() ?? layout.bounds.maxY
            let haze = CGFloat(index) * 0.18
            paintMassif(ctx, body: path, sunlitSide: nil,
                        rock: blend(ridge.fill, sky.horizon, haze * 0.5),
                        snow: blend(0xeef4fa, sky.horizon, haze * 0.4),
                        snowLine: ridge.snowLine, top: top, sky: sky,
                        glow: sky.alpenglowStrength * (1 - haze * 0.4), textured: false)
            drawStrata(ctx, body: path, points: ridge.points, bounds: layout.bounds, sky: sky,
                       strength: [0.75, 0.65, 0.55][min(2, index)], salt: 950 + index * 13)
            if index == 0 { drawFrontRock(layout, ridge: ridge, body: path, sky: sky, in: ctx) }
            // A shaded flank on every peak gives the ranges volume.
            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            // The light comes from the left, as on the Matterhorn: every peak
            // has a lit face and a shadowed face to the right. The shadow runs from the
            // crest down a broken spur to the gully, and fades out with depth
            // so no hard edge ever reaches the valley.
            let points = ridge.points
            let shadeTone = blend(0x1c2a46, sky.horizon, CGFloat(index) * 0.18)
            let rockTone = blend(0x3c4558, sky.horizon, CGFloat(index) * 0.22)
            var peakIndex = 1
            while peakIndex + 1 < points.count {
                let peak = points[peakIndex]
                guard peak.y >= points[peakIndex - 1].y, peak.y > points[peakIndex + 1].y else {
                    peakIndex += 1; continue
                }
                var valleyIndex = peakIndex + 1
                while valleyIndex < points.count - 1, points[valleyIndex + 1].y < points[valleyIndex].y {
                    valleyIndex += 1
                }
                let valley = points[valleyIndex]
                let span = max(1, valley.x - peak.x)
                let rise = peak.y - valley.y
                guard rise > layout.bounds.height * 0.006, valleyIndex < points.count - 1,
                      span > layout.bounds.width * 0.025 else { peakIndex += 1; continue }
                let depth = rise * 2.4 + layout.bounds.height * 0.05
                let base = peak.y - depth
                let face = CGMutablePath()
                face.move(to: peak)
                var along = peakIndex + 1
                while along <= valleyIndex { face.addLine(to: points[along]); along += 1 }
                // Down the gully below the saddle…
                face.addLine(to: CGPoint(x: valley.x - span * 0.10, y: valley.y - (valley.y - base) * 0.55))
                face.addLine(to: CGPoint(x: valley.x - span * 0.22, y: base))
                // …and back up the spur, broken into steps of rock.
                let spurFoot = CGPoint(x: peak.x + span * 0.30, y: base)
                let steps = 6
                for k in stride(from: steps - 1, through: 1, by: -1) {
                    let t = CGFloat(k) / CGFloat(steps)
                    let jitter = (AdventLayout.noise(peakIndex * 31 + k, 40 + index) - 0.5) * span * 0.16
                    face.addLine(to: CGPoint(x: peak.x + (spurFoot.x - peak.x) * t + jitter,
                                             y: peak.y + (base - peak.y) * t))
                }
                face.closeSubpath()
                ctx.saveGState()
                ctx.addPath(face)
                ctx.clip()
                let fade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                      colors: [AdventPaint.color(shadeTone, 0.30 - CGFloat(index) * 0.05),
                                               AdventPaint.color(shadeTone, 0.16 - CGFloat(index) * 0.03),
                                               AdventPaint.color(shadeTone, 0)] as CFArray,
                                      locations: [0, 0.45, 1])!
                ctx.drawLinearGradient(fade, start: CGPoint(x: 0, y: peak.y),
                                       end: CGPoint(x: 0, y: base), options: [])
                ctx.restoreGState()
                // The steep upper face cannot hold snow: bare rock just under
                // the crest, thick near the summit and thinning toward the saddle.
                let steepness = rise / span
                if steepness > 0.30, AdventLayout.noise(peakIndex * 13 + index, 7) > 0.25 {
                    let thick = rise * (0.22 + AdventLayout.noise(peakIndex, 8) * 0.22)
                    let reach = 0.45 + AdventLayout.noise(peakIndex, 9) * 0.30
                    let end = CGPoint(x: peak.x + span * reach, y: peak.y - rise * reach)
                    let rock = CGMutablePath()
                    rock.move(to: CGPoint(x: peak.x, y: peak.y - 0.5))
                    rock.addLine(to: CGPoint(x: end.x, y: end.y - 0.5))
                    rock.addQuadCurve(to: CGPoint(x: peak.x + span * 0.04, y: peak.y - thick),
                                      control: CGPoint(x: (peak.x + end.x) * 0.5,
                                                       y: (peak.y + end.y) * 0.5 - thick * 0.9))
                    rock.closeSubpath()
                    ctx.setFillColor(AdventPaint.color(rockTone, 0.40 - CGFloat(index) * 0.08))
                    ctx.addPath(rock)
                    ctx.fillPath()
                }
                peakIndex += 1
            }
            // Wind-packed snow: faint ripples across the slopes.
            let ripple = blend(0x8fa3bc, sky.horizon, 0.3)
            for wave in 0..<(30 - index * 6) {
                let x = layout.bounds.minX + layout.bounds.width * AdventLayout.noise(wave, 960 + index)
                let surface = AdventLayout.height(of: ridge, at: x)
                let y = surface - layout.bounds.height * (0.01 + AdventLayout.noise(wave, 961 + index) * 0.09)
                let length = layout.bounds.width * (0.02 + AdventLayout.noise(wave, 962 + index) * 0.04)
                ctx.setStrokeColor(AdventPaint.color(ripple, 0.16 - CGFloat(index) * 0.03))
                ctx.setLineWidth(max(0.5, layout.bounds.height * 0.0012))
                ctx.move(to: CGPoint(x: x, y: y))
                ctx.addQuadCurve(to: CGPoint(x: x + length, y: y - length * 0.06),
                                 control: CGPoint(x: x + length * 0.5, y: y + length * 0.06))
                ctx.strokePath()
            }
            // Rock outcrops breaking through on the steeper ground: low, broken
            // shapes half buried in the snow, lit on the left, with snow lying
            // along their top edge and drifted against their foot.
            let unitSize = layout.bounds.height * 0.011 * (1.15 - CGFloat(index) * 0.15)
            let lit = blend(0x5a6172, sky.horizon, 0.2 + CGFloat(index) * 0.15)
            let dark = blend(0x2c3242, sky.horizon, 0.2 + CGFloat(index) * 0.15)
            let drift = blend(0xeef3f9, sky.horizon, CGFloat(index) * 0.15)
            for crag in 0..<(18 - index * 4) {
                let x = layout.bounds.minX + layout.bounds.width * AdventLayout.noise(crag, 970 + index)
                let surface = AdventLayout.height(of: ridge, at: x)
                let slope = abs(AdventLayout.height(of: ridge, at: x + 6) - AdventLayout.height(of: ridge, at: x - 6)) / 12
                guard slope > 0.22 else { continue }
                let y = surface - layout.bounds.height * (0.006 + AdventLayout.noise(crag, 971 + index) * 0.03)
                let size = unitSize * (0.7 + AdventLayout.noise(crag, 972 + index) * 0.8)
                var top: [CGPoint] = []
                for k in 0...6 {
                    let t = CGFloat(k) / 6
                    let lift = sin(t * .pi) * (0.45 + AdventLayout.noise(crag * 11 + k, 974 + index) * 0.5)
                    top.append(CGPoint(x: x - size * 1.4 + size * 2.8 * t, y: y + size * lift))
                }
                let body = CGMutablePath()
                body.addLines(between: top)
                body.addLine(to: CGPoint(x: x + size * 1.4, y: y - size * 0.2))
                body.addLine(to: CGPoint(x: x - size * 1.4, y: y - size * 0.2))
                body.closeSubpath()
                ctx.setFillColor(AdventPaint.color(lit))
                ctx.addPath(body)
                ctx.fillPath()
                // Right half in shadow.
                ctx.saveGState()
                ctx.addPath(body)
                ctx.clip()
                ctx.setFillColor(AdventPaint.color(dark))
                ctx.fill(CGRect(x: x + size * 0.1, y: y - size, width: size * 2, height: size * 3))
                ctx.restoreGState()
                // Snow along the top edge, thicker on the flatter parts.
                AdventPaint.stroke(ctx, Array(top[1...5]).map { CGPoint(x: $0.x, y: $0.y + size * 0.04) }, drift,
                                   max(0.6, size * 0.22))
                // Drift against the foot buries the bottom of the rock.
                let mound = CGMutablePath()
                mound.move(to: CGPoint(x: x - size * 1.8, y: y - size * 0.25))
                mound.addQuadCurve(to: CGPoint(x: x + size * 1.8, y: y - size * 0.25),
                                   control: CGPoint(x: x - size * 0.4, y: y + size * 0.55))
                mound.closeSubpath()
                ctx.setFillColor(AdventPaint.color(drift))
                ctx.addPath(mound)
                ctx.fillPath()
            }
            ctx.restoreGState()
            if index == layout.ridges.count - 1 {
                ctx.setStrokeColor(AdventPaint.color(0xffffff, 0.30))
                ctx.setLineWidth(1.2)
                ctx.beginPath()
                ctx.addLines(between: ridge.points)
                ctx.strokePath()
            }
            if index == 1 {
                drawPistes(layout, sky: sky, in: ctx)
                drawGondolas(layout, sky: sky, in: ctx)
            }
            drawTreeLine(layout, ridge: index, sky: sky, in: ctx)
            // Mist pooling at the foot of each range: the layered look that
            // makes distance readable at a glance.
            let foot = (ridge.points.map(\.y).min() ?? layout.bounds.minY)
            let mist = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(blend(0xe8f0f8, sky.horizon, 0.3), 0.17),
                                           AdventPaint.color(blend(0xe8f0f8, sky.horizon, 0.3), 0)] as CFArray,
                                  locations: [0, 1])!
            ctx.saveGState()
            ctx.clip(to: CGRect(x: layout.bounds.minX, y: foot - layout.bounds.height * 0.02,
                                width: layout.bounds.width, height: layout.bounds.height * 0.07))
            ctx.drawLinearGradient(mist, start: CGPoint(x: 0, y: foot - layout.bounds.height * 0.02),
                                   end: CGPoint(x: 0, y: foot + layout.bounds.height * 0.055), options: [])
            ctx.restoreGState()
        }
    }

    private static func drawFirs(_ layout: AdventLayout, depth: Int, sky: AdventSky, in ctx: CGContext) {
        let base: UInt32 = [0x39566a, 0x2f4a5c, 0x26404f][depth]
        let shade = blend(base, sky.horizon, (1 - CGFloat(depth) * 0.35) * 0.35)
        for fir in layout.firs where fir.depth == depth {
            AdventPaint.fir(ctx, x: fir.x, y: fir.y, size: fir.size, fill: shade, snow: multiply(0xdbe8f0, sky.valleyLight))
        }
    }

    private static func drawLake(_ layout: AdventLayout, sky: AdventSky, aurora: Bool = false, in ctx: CGContext) {
        let lake = layout.lake
        // A bank of snow round the ice, shaded on the far side.
        // A low, lumpy bank of shovelled snow all round the ice.
        let bankColour = multiply(0xe6eef5, sky.valleyLight)
        ctx.setFillColor(AdventPaint.color(bankColour))
        ctx.fillEllipse(in: lake.insetBy(dx: -lake.width * 0.025, dy: -lake.height * 0.08))
        for lump in 0..<28 {
            let a = CGFloat(lump) / 28 * .pi * 2
            let at = CGPoint(x: lake.midX + cos(a) * lake.width * 0.51, y: lake.midY + sin(a) * lake.height * 0.54)
            let size = lake.height * (0.07 + AdventLayout.noise(lump, 840) * 0.06)
            AdventPaint.oval(ctx, at.x, at.y, size * 2.4, size, bankColour)
        }
        // The ice mirrors the sky: brighter at the far edge, deep blue near.
        ctx.saveGState()
        ctx.addEllipse(in: lake)
        ctx.clip()
        let ice = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                             colors: [AdventPaint.color(multiply(0x4d6d8a, sky.valleyLight)),
                                      AdventPaint.color(multiply(blend(0x86a7c3, sky.horizon, 0.3), sky.valleyLight)),
                                      AdventPaint.color(multiply(blend(0xc9dbea, sky.horizon, 0.4), sky.valleyLight))] as CFArray,
                             locations: [0, 0.6, 1])!
        ctx.drawLinearGradient(ice, start: CGPoint(x: 0, y: lake.minY), end: CGPoint(x: 0, y: lake.maxY), options: [])
        // The far bank throws a soft shadow onto the ice.
        let shadow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                colors: [AdventPaint.color(0x2a3a52, 0.32), AdventPaint.color(0x2a3a52, 0)] as CFArray,
                                locations: [0, 1])!
        ctx.drawLinearGradient(shadow, start: CGPoint(x: 0, y: lake.maxY), end: CGPoint(x: 0, y: lake.maxY - lake.height * 0.22), options: [])
        // A long sheen across the ice, and the scratches of skates.
        AdventPaint.glow(ctx, at: CGPoint(x: lake.midX - lake.width * 0.12, y: lake.midY + lake.height * 0.1),
                         radius: lake.width * 0.3, 0xffffff, 0.18 * (0.3 + sky.daylight))
        if aurora, sky.starlight > 0.3 {
            // On nights with the northern lights the smooth ice catches their
            // green, faintest near the bank, a touch of violet beyond.
            AdventPaint.pool(ctx, at: CGPoint(x: lake.midX + lake.width * 0.05, y: lake.midY + lake.height * 0.18),
                             width: lake.width * 0.95, flat: 0.32, 0x7df2c4, 0.20 * sky.starlight)
            AdventPaint.pool(ctx, at: CGPoint(x: lake.midX - lake.width * 0.22, y: lake.midY + lake.height * 0.26),
                             width: lake.width * 0.55, flat: 0.28, 0xb7a8f0, 0.12 * sky.starlight)
        }
        ctx.setStrokeColor(AdventPaint.color(0xffffff, 0.35))
        ctx.setLineWidth(max(0.5, lake.height * 0.012))
        for scratch in 0..<7 {
            let cx = lake.midX + (AdventLayout.noise(scratch, 830) - 0.5) * lake.width * 0.4
            let cy = lake.midY + (AdventLayout.noise(scratch, 831) - 0.5) * lake.height * 0.3
            let rx = lake.width * (0.12 + AdventLayout.noise(scratch, 832) * 0.2)
            let ry = lake.height * (0.12 + AdventLayout.noise(scratch, 833) * 0.18)
            let a = AdventLayout.noise(scratch, 834) * .pi * 2
            let arc = CGMutablePath()
            for step in 0...12 {
                let t = a + CGFloat(step) / 12 * 2.2
                let point = CGPoint(x: cx + cos(t) * rx, y: cy + sin(t) * ry)
                if step == 0 { arc.move(to: point) } else { arc.addLine(to: point) }
            }
            ctx.addPath(arc)
        }
        ctx.strokePath()
        // At night the village lights are mirrored in the ice.
        if sky.lampStrength > 0.3 {
            for streak in 0..<5 {
                let x = lake.minX + lake.width * (0.15 + CGFloat(streak) * 0.17)
                ctx.saveGState()
                ctx.translateBy(x: x, y: lake.maxY - lake.height * 0.25)
                ctx.scaleBy(x: 0.25, y: 1)
                AdventPaint.glow(ctx, at: .zero, radius: lake.height * 0.5, 0xffc27a, 0.35 * sky.lampStrength)
                ctx.restoreGState()
            }
        }
        ctx.restoreGState()
    }

    /// The park bench beside the pond: two seat slats and a backrest on cast
    /// iron ends, snow lying on the seat and along the top of the back.
    static func pondBench(_ layout: AdventLayout) -> CGRect {
        let lake = layout.lake
        return CGRect(x: lake.maxX - lake.width * 0.05, y: lake.maxY + lake.height * 0.05,
                      width: lake.width * 0.09, height: lake.height * 0.08)
    }

    static func drawBenchInField(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        drawBench(layout, sky: sky, in: ctx)
    }

    private static func drawBench(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let seat = pondBench(layout)
        let wood = multiply(0x7a5236, sky.valleyLight)
        let woodDark = multiply(0x553826, sky.valleyLight)
        let iron = multiply(0x2e3036, sky.valleyLight)
        let snow = multiply(0xeef5fa, sky.valleyLight)
        let u = seat.height
        // A soft shadow on the snow.
        AdventPaint.oval(ctx, seat.midX + u * 0.3, seat.minY - u * 1.0, seat.width * 1.2, u * 0.5,
                         multiply(0xb3c3d6, sky.valleyLight), alpha: 0.6)
        // Backrest behind the seat: two slats on the iron ends.
        for slat in 0..<2 {
            AdventPaint.box(ctx, CGRect(x: seat.minX + u * 0.1, y: seat.maxY + u * (0.35 + CGFloat(slat) * 0.55),
                                        width: seat.width - u * 0.2, height: u * 0.38), u * 0.1, slat == 0 ? woodDark : wood)
        }
        // Cast iron ends with a curl for the armrest.
        for side: CGFloat in [-1, 1] {
            let x = side < 0 ? seat.minX + u * 0.15 : seat.maxX - u * 0.15
            AdventPaint.stroke(ctx, [CGPoint(x: x, y: seat.minY - u * 0.95), CGPoint(x: x, y: seat.maxY + u * 1.4)], iron, max(0.6, u * 0.16))
            AdventPaint.stroke(ctx, [CGPoint(x: x - side * u * 0.35, y: seat.minY - u * 0.95), CGPoint(x: x, y: seat.minY - u * 0.3)],
                               iron, max(0.5, u * 0.12))
            AdventPaint.stroke(ctx, [CGPoint(x: x, y: seat.maxY + u * 0.3), CGPoint(x: x + side * u * 0.3, y: seat.maxY + u * 0.4),
                                     CGPoint(x: x + side * u * 0.3, y: seat.maxY + u * 0.15)], iron, max(0.5, u * 0.12))
        }
        // Seat slats, and the snow lying on them and on the backrest.
        AdventPaint.box(ctx, CGRect(x: seat.minX, y: seat.minY, width: seat.width, height: u * 0.45), u * 0.1, woodDark)
        AdventPaint.box(ctx, CGRect(x: seat.minX, y: seat.minY + u * 0.5, width: seat.width, height: u * 0.45), u * 0.1, wood)
        let cushion = CGMutablePath()
        cushion.move(to: CGPoint(x: seat.minX - u * 0.05, y: seat.maxY - u * 0.02))
        cushion.addQuadCurve(to: CGPoint(x: seat.maxX + u * 0.05, y: seat.maxY - u * 0.02),
                             control: CGPoint(x: seat.midX, y: seat.maxY + u * 0.85))
        cushion.closeSubpath()
        // A cool shadow edge, so the snow reads against the snow behind it.
        let edge = multiply(0x9fb2c8, sky.valleyLight)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -u * 0.08), blur: u * 0.12, color: AdventPaint.color(edge, 0.9))
        ctx.setFillColor(AdventPaint.color(blend(snow, 0xffffff, 0.4)))
        ctx.addPath(cushion)
        ctx.fillPath()
        AdventPaint.box(ctx, CGRect(x: seat.minX + u * 0.1, y: seat.maxY + u * 1.25, width: seat.width - u * 0.2, height: u * 0.22),
                        u * 0.1, blend(snow, 0xffffff, 0.4))
        ctx.restoreGState()
    }

    // MARK: Roads

    /// part 0 draws everything, 1 only the road surface, 2 only what stands
    /// along its front edge (fence and lanterns).
    private static func drawRoad(_ layout: AdventLayout, index: Int, season: AdventSeason,
                                 sky: AdventSky, part: Int = 0, in ctx: CGContext) {
        let road = layout.roads[index]
        if part != 2 {
        // Packed snow, a shade darker than the fresh snow either side, with two
        // worn wheel ruts: otherwise a white road vanishes on a white valley.
        // Packed snow on the road lies in the same light as the valley.
        AdventPaint.stroke(ctx, road.points, multiply(blend(0xb9c9d8, sky.horizon, 0.22), sky.valleyLight), road.width, alpha: 0.95)
        AdventPaint.stroke(ctx, road.points, multiply(blend(0xe4edf5, sky.horizon, 0.12), sky.valleyLight), road.width * 0.62, alpha: 0.9)
        for rut: CGFloat in [-0.18, 0.18] {
            AdventPaint.stroke(ctx, road.points.map { CGPoint(x: $0.x, y: $0.y + road.width * rut) },
                               blend(0x9fb3c6, sky.horizon, 0.2), max(0.7, road.width * 0.09), alpha: 0.7)
        }
        }
        guard part != 1 else { return }
        // A split-rail fence along the lower side, as on every alpine lane:
        // weathered posts with a lit edge and a cap of snow, two rails with
        // snow lying along the top one.
        let wood = blend(0x5a463c, sky.horizon, 0.15)
        let woodDark = blend(wood, 0x1c1410, 0.40)
        let woodLit = blend(wood, 0xe2cdb4, 0.30)
        let fenceSnow = multiply(0xeef5fa, sky.valleyLight)
        let fine = road.width > 6
        let fencePosts = fine ? 24 : 14
        func fenceY(_ x: CGFloat) -> CGFloat {
            let pts = road.points
            guard let next = pts.firstIndex(where: { $0.x >= x }), next > 0 else { return (pts.first?.y ?? 0) - road.width * 0.62 }
            let a = pts[next - 1], b = pts[next]
            return a.y + (b.y - a.y) * (x - a.x) / max(0.001, b.x - a.x) - road.width * 0.62
        }
        let railWidth = max(0.5, road.width * (fine ? 0.075 : 0.05))
        for rail: CGFloat in [0.18, 0.38] {
            let line = road.points.map { CGPoint(x: $0.x, y: $0.y - road.width * 0.62 + road.width * rail) }
            AdventPaint.stroke(ctx, line, fine ? woodDark : 0x4a3b35, railWidth * (fine ? 1.25 : 1), alpha: fine ? 0.9 : 0.75)
            if fine {
                AdventPaint.stroke(ctx, line.map { CGPoint(x: $0.x, y: $0.y + railWidth * 0.18) }, wood, railWidth * 0.8)
                AdventPaint.stroke(ctx, line.map { CGPoint(x: $0.x, y: $0.y + railWidth * 0.40) }, woodLit, railWidth * 0.25, alpha: 0.8)
                if rail > 0.3 {
                    // Snow along the top rail, broken where it has fallen off.
                    var x = line.first!.x
                    var k = 0
                    while x < line.last!.x {
                        let length = road.width * (0.6 + AdventLayout.noise(k + index * 50, 870) * 1.6)
                        defer { x += length + road.width * (0.15 + AdventLayout.noise(k, 871) * 0.5); k += 1 }
                        let y0 = fenceY(x) + road.width * rail + railWidth * 0.32
                        let y1 = fenceY(x + length) + road.width * rail + railWidth * 0.32
                        AdventPaint.stroke(ctx, [CGPoint(x: x, y: y0), CGPoint(x: x + length, y: y1)], fenceSnow, railWidth * 0.9)
                    }
                }
            }
        }
        for post in 0...fencePosts {
            let t = CGFloat(post) / CGFloat(fencePosts)
            let x = road.points.first!.x + (road.points.last!.x - road.points.first!.x) * t
                + (AdventLayout.noise(post + index * 31, 872) - 0.5) * road.width * 0.3
            let foot = CGPoint(x: x, y: fenceY(x))
            let tall = road.width * (0.50 + AdventLayout.noise(post, 873) * 0.06)
            if fine {
                let half = road.width * 0.055
                let lean = (AdventLayout.noise(post, 874) - 0.5) * road.width * 0.04
                let body = CGMutablePath()
                body.move(to: CGPoint(x: foot.x - half, y: foot.y))
                body.addLine(to: CGPoint(x: foot.x + half, y: foot.y))
                body.addLine(to: CGPoint(x: foot.x + half + lean, y: foot.y + tall))
                body.addLine(to: CGPoint(x: foot.x + lean, y: foot.y + tall + half * 0.9))
                body.addLine(to: CGPoint(x: foot.x - half + lean, y: foot.y + tall))
                body.closeSubpath()
                ctx.setFillColor(AdventPaint.color(wood))
                ctx.addPath(body)
                ctx.fillPath()
                ctx.saveGState()
                ctx.addPath(body)
                ctx.clip()
                ctx.setFillColor(AdventPaint.color(woodDark, 0.6))
                ctx.fill(CGRect(x: foot.x + half * 0.2 + lean * 0.5, y: foot.y, width: half * 2, height: tall + half))
                ctx.setFillColor(AdventPaint.color(woodLit, 0.6))
                ctx.fill(CGRect(x: foot.x - half + lean * 0.5, y: foot.y, width: half * 0.45, height: tall + half))
                // A crack in the grain.
                ctx.setStrokeColor(AdventPaint.color(woodDark, 0.7))
                ctx.setLineWidth(max(0.3, half * 0.18))
                ctx.move(to: CGPoint(x: foot.x - half * 0.2, y: foot.y + tall * 0.25))
                ctx.addLine(to: CGPoint(x: foot.x - half * 0.1 + lean * 0.6, y: foot.y + tall * 0.7))
                ctx.strokePath()
                ctx.restoreGState()
                // A cap of snow on top and a little drift at the foot.
                AdventPaint.oval(ctx, foot.x + lean, foot.y + tall + half * 0.75, half * 2.6, half * 1.3, fenceSnow)
                AdventPaint.oval(ctx, foot.x, foot.y + half * 0.2, half * 3.6, half * 1.2, fenceSnow, alpha: 0.85)
            } else {
                AdventPaint.stroke(ctx, [foot, CGPoint(x: foot.x, y: foot.y + tall)], 0x4a3b35, max(0.6, road.width * 0.07), alpha: 0.75)
            }
        }

        // The lanterns always stand along the road; the third door switches
        // them on, and more burn with every door after it.
        var burning = layout.litLamps(warmth: season.warmth)
        for before in 0..<index { burning -= layout.roads[before].lamps.count }
        let post = road.width * 1.9
        for (number, lamp) in road.lamps.enumerated() {
            // From door 3 every lantern burns, and by day they glow too, so the
            // gift can be seen the moment the door opens.
            let lit = season.has(.lanterns)
            let iron: UInt32 = 0x2a3540
            let fine = road.width > 5
            let pole = max(0.9, road.width * 0.11)
            AdventPaint.stroke(ctx, [lamp, CGPoint(x: lamp.x, y: lamp.y + post)], 0x33424f, pole)
            if fine {
                // Cast-iron detail: a flared foot, a collar half way up and
                // the light catching the left edge of the post.
                let foot = CGMutablePath()
                foot.move(to: CGPoint(x: lamp.x - road.width * 0.15, y: lamp.y))
                foot.addLine(to: CGPoint(x: lamp.x + road.width * 0.15, y: lamp.y))
                foot.addLine(to: CGPoint(x: lamp.x + pole * 0.6, y: lamp.y + road.width * 0.22))
                foot.addLine(to: CGPoint(x: lamp.x - pole * 0.6, y: lamp.y + road.width * 0.22))
                foot.closeSubpath()
                ctx.setFillColor(AdventPaint.color(iron))
                ctx.addPath(foot)
                ctx.fillPath()
                AdventPaint.box(ctx, CGRect(x: lamp.x - pole * 0.9, y: lamp.y + post * 0.55, width: pole * 1.8, height: pole * 0.7),
                                pole * 0.2, iron)
                AdventPaint.stroke(ctx, [CGPoint(x: lamp.x - pole * 0.25, y: lamp.y + road.width * 0.25),
                                         CGPoint(x: lamp.x - pole * 0.25, y: lamp.y + post * 0.97)],
                                   0x8796a6, max(0.4, pole * 0.22), alpha: 0.55)
            }
            let head = CGPoint(x: lamp.x, y: lamp.y + post + road.width * 0.1)
            if lit {
                AdventPaint.glow(ctx, at: head, radius: post * 0.95, 0xffcf8a, 0.28 * max(0.55, sky.lampStrength))
                AdventPaint.glow(ctx, at: CGPoint(x: head.x, y: lamp.y), radius: post * 0.6,
                                 0xffcf8a, 0.16 * sky.lampStrength)
            }
            // A proper lantern: glass in an iron frame, wider at the top, on
            // a little neck, under a roof with snow and a knob on top.
            let lw = road.width * 0.44, lh = road.width * 0.56
            let glass = CGRect(x: head.x - lw / 2, y: head.y - lh * 0.45, width: lw, height: lh)
            if fine {
                let neck = CGMutablePath()
                neck.move(to: CGPoint(x: head.x - pole * 0.5, y: glass.minY - lw * 0.30))
                neck.addLine(to: CGPoint(x: head.x + pole * 0.5, y: glass.minY - lw * 0.30))
                neck.addLine(to: CGPoint(x: glass.maxX - lw * 0.05, y: glass.minY - lw * 0.08))
                neck.addLine(to: CGPoint(x: glass.minX + lw * 0.05, y: glass.minY - lw * 0.08))
                neck.closeSubpath()
                ctx.setFillColor(AdventPaint.color(iron))
                ctx.addPath(neck)
                ctx.fillPath()
                let body = CGMutablePath()
                body.move(to: CGPoint(x: glass.minX - lw * 0.04, y: glass.minY - lw * 0.10))
                body.addLine(to: CGPoint(x: glass.maxX + lw * 0.04, y: glass.minY - lw * 0.10))
                body.addLine(to: CGPoint(x: glass.maxX + lw * 0.16, y: glass.maxY + lw * 0.10))
                body.addLine(to: CGPoint(x: glass.minX - lw * 0.16, y: glass.maxY + lw * 0.10))
                body.closeSubpath()
                ctx.setFillColor(AdventPaint.color(iron))
                ctx.addPath(body)
                ctx.fillPath()
                let pane = CGMutablePath()
                pane.move(to: CGPoint(x: glass.minX + lw * 0.04, y: glass.minY))
                pane.addLine(to: CGPoint(x: glass.maxX - lw * 0.04, y: glass.minY))
                pane.addLine(to: CGPoint(x: glass.maxX + lw * 0.07, y: glass.maxY))
                pane.addLine(to: CGPoint(x: glass.minX - lw * 0.07, y: glass.maxY))
                pane.closeSubpath()
                ctx.setFillColor(AdventPaint.color(lit ? 0xffe2ab : 0x6f8494))
                ctx.addPath(pane)
                ctx.fillPath()
                ctx.saveGState()
                ctx.addPath(pane)
                ctx.clip()
                if lit {
                    // The flame inside, brightest at its heart.
                    AdventPaint.glow(ctx, at: CGPoint(x: glass.midX, y: glass.minY + lh * 0.38), radius: lw * 0.42, 0xfff4d6, 0.9)
                    AdventPaint.oval(ctx, glass.midX, glass.minY + lh * 0.34, lw * 0.16, lh * 0.30, 0xffb84d)
                    AdventPaint.oval(ctx, glass.midX, glass.minY + lh * 0.32, lw * 0.07, lh * 0.15, 0xfff8e6)
                } else {
                    // Sky reflected in the glass: a light diagonal streak.
                    ctx.setStrokeColor(AdventPaint.color(0xd5e2ec, 0.55))
                    ctx.setLineWidth(max(0.5, lw * 0.14))
                    ctx.move(to: CGPoint(x: glass.minX, y: glass.minY + lh * 0.35))
                    ctx.addLine(to: CGPoint(x: glass.minX + lw * 0.55, y: glass.maxY))
                    ctx.strokePath()
                }
                ctx.restoreGState()
            } else {
                AdventPaint.box(ctx, glass.insetBy(dx: -lw * 0.12, dy: -lw * 0.10), lw * 0.08, iron)
                AdventPaint.box(ctx, glass, lw * 0.05, lit ? 0xffe2ab : 0x6f8494)
            }
            if road.width > 5 {
                ctx.setStrokeColor(AdventPaint.color(iron, 0.8))
                ctx.setLineWidth(max(0.4, lw * 0.08))
                ctx.move(to: CGPoint(x: glass.midX, y: glass.minY))
                ctx.addLine(to: CGPoint(x: glass.midX, y: glass.maxY))
                ctx.strokePath()
            }
            let cap = CGMutablePath()
            cap.move(to: CGPoint(x: glass.minX - lw * 0.30, y: glass.maxY + lw * 0.08))
            cap.addLine(to: CGPoint(x: glass.midX, y: glass.maxY + lw * 0.62))
            cap.addLine(to: CGPoint(x: glass.maxX + lw * 0.30, y: glass.maxY + lw * 0.08))
            cap.closeSubpath()
            ctx.setFillColor(AdventPaint.color(iron))
            ctx.addPath(cap)
            ctx.fillPath()
            AdventPaint.stroke(ctx, [CGPoint(x: glass.minX - lw * 0.22, y: glass.maxY + lw * 0.22),
                                     CGPoint(x: glass.midX, y: glass.maxY + lw * 0.66),
                                     CGPoint(x: glass.maxX + lw * 0.22, y: glass.maxY + lw * 0.22)],
                               multiply(0xeef5fa, sky.valleyLight), max(0.6, lw * 0.2))
            if fine {
                AdventPaint.oval(ctx, glass.midX, glass.maxY + lw * 0.74, lw * 0.16, lw * 0.16, iron)
            }
            if road.width > 8 {
                // A sprig of fir with a red bow tied round the post.
                let tie = CGPoint(x: lamp.x, y: lamp.y + post * 0.80)
                AdventPaint.oval(ctx, tie.x - pole * 0.9, tie.y, pole * 1.8, pole * 1.1, 0x2f5a3c)
                AdventPaint.oval(ctx, tie.x + pole * 0.9, tie.y + pole * 0.1, pole * 1.8, pole * 1.1, 0x2a5136)
                AdventPaint.stroke(ctx, [CGPoint(x: tie.x, y: tie.y), CGPoint(x: tie.x - pole * 0.9, y: tie.y - pole * 1.6)], 0xb8322b, max(0.5, pole * 0.45))
                AdventPaint.stroke(ctx, [CGPoint(x: tie.x, y: tie.y), CGPoint(x: tie.x + pole * 0.8, y: tie.y - pole * 1.7)], 0xb8322b, max(0.5, pole * 0.45))
                AdventPaint.oval(ctx, tie.x - pole * 0.8, tie.y + pole * 0.2, pole * 1.0, pole * 0.8, 0xc9392f)
                AdventPaint.oval(ctx, tie.x + pole * 0.8, tie.y + pole * 0.2, pole * 1.0, pole * 0.8, 0xc9392f)
                AdventPaint.oval(ctx, tie.x, tie.y + pole * 0.2, pole * 0.6, pole * 0.6, 0xa82b25)
            }
        }
    }

    /// Strings of lights between the lanterns hang in front of the houses,
    /// so they are drawn after them.
    private static func drawGarlands(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky,
                                     roads only: Set<Int> = [0, 1, 2], in ctx: CGContext) {
        guard season.has(.lanterns), season.has(.garland) else { return }
        var burning = layout.litLamps(warmth: season.warmth)
        for (roadIndex, road) in layout.roads.enumerated() {
            defer { burning -= road.lamps.count }
            guard only.contains(roadIndex) else { continue }
            let post = road.width * 1.9
            for (number, lamp) in road.lamps.enumerated() {
                let lit = true
            guard number + 1 < road.lamps.count else { continue }
            let next = road.lamps[number + 1]
            let sag = post * 0.42
            let from = CGPoint(x: lamp.x, y: lamp.y + post)
            let to = CGPoint(x: next.x, y: next.y + post)
            let control = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 - sag)
            // A string of lights never hangs across an Advent door or its
            // number: that span is left out.
            // Checked along the wire itself, not its bounding box: far houses
            // stand right on their road and a box would remove every span.
            let doorAreas = layout.doors.map { door in
                CGRect(x: door.rect.minX, y: door.rect.minY, width: door.rect.width,
                       height: door.rect.height + door.rect.width * 0.1 + max(9, door.rect.height * 0.38))
                    .insetBy(dx: -2, dy: -2)
            }
            let crossesDoor = (0...24).contains { step in
                let t = CGFloat(step) / 24, u = 1 - t
                let point = CGPoint(x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
                                    y: u * u * from.y + 2 * u * t * control.y + t * t * to.y - road.width * 0.1)
                return doorAreas.contains { $0.contains(point) }
            }
            if crossesDoor { continue }
            // A thin wire; the bulbs sit on the very same curve.
            ctx.setStrokeColor(AdventPaint.color(0x2a3a30, lit ? 0.8 : 0.45))
            ctx.setLineWidth(max(0.5, road.width * 0.035))
            ctx.move(to: from)
            ctx.addQuadCurve(to: to, control: control)
            ctx.strokePath()
            let span = hypot(to.x - from.x, to.y - from.y)
            let bulbs = max(3, Int(span / max(6, road.width * 0.5)))
            let size = max(1.4, road.width * 0.10)
            let tints: [UInt32] = [0xffe2a8, 0xe5574e, 0x5fb36d, 0x7fb4ef]
            for bulb in 0..<bulbs {
                let t = (CGFloat(bulb) + 0.5) / CGFloat(bulbs)
                let u = 1 - t
                let point = CGPoint(x: u * u * from.x + 2 * u * t * control.x + t * t * to.x,
                                    y: u * u * from.y + 2 * u * t * control.y + t * t * to.y)
                let tint = tints[(bulb + number) % tints.count]
                if lit {
                    AdventPaint.glow(ctx, at: CGPoint(x: point.x, y: point.y - size * 0.6), radius: size * 2.2,
                                     tint, 0.35 * sky.lampStrength + 0.22)
                }
                // Socket on the wire, the bulb hanging just below it.
                AdventPaint.box(ctx, CGRect(x: point.x - size * 0.25, y: point.y - size * 0.35,
                                            width: size * 0.5, height: size * 0.45), size * 0.1, 0x2a3a30)
                AdventPaint.oval(ctx, point.x, point.y - size * 0.75, size * 0.8, size * 1.0, tint,
                                 alpha: lit ? 0.95 : 0.35)
            }
        }
    }
    }

    /// Christmas Eve: paper lanterns with a candle inside line the near road.

    // MARK: Buildings

    /// A Walliser chalet in log construction: a masonry base, stacked round
    /// timbers with their notched ends standing proud of the corners, a deep
    /// overhanging roof weighted with stones, and a carved balcony across the
    /// front. The corner ends and the carving are what make it read as a chalet
    /// rather than a shed with planks.
    private static func drawChalet(_ chalet: AdventLayout.Chalet, layout: AdventLayout,
                                   season: AdventSeason, sky: AdventSky, in ctx: CGContext) {
        if chalet.kind == .church { drawChurch(chalet, sky: sky, in: ctx); return }
        if chalet.kind == .barn { drawStadel(chalet, sky: sky, in: ctx); return }
        let base = chalet.base
        let w = base.width, h = base.height
        let detail = w > 30
        let fine = w > 54
        // No two houses alike: five kinds of wood, from young pale larch to
        // old sun-burnt timber almost black, each with its own shutter colour,
        // and independently of that the build of the house: a stone or a
        // whitewashed ground floor, with or without a balcony, two to four
        // windows on the front.
        let variant = Int((base.midX * 13 + base.minY * 7).magnitude) % 5
        let style = Int((base.midX * 31 + base.minY * 17 + 7).magnitude) % 6
        let plastered = style % 3 == 0
        let hasBalcony = style % 3 != 1
        let wood: UInt32 = [0x7d5a3f, 0x56392a, 0x9a764f, 0x6a4632, 0x8c6a48][variant]
        // After dark the wood falls into the cool blue of the night; the
        // windows and lanterns then glow against it.
        let dark = 1 - sky.daylight
        let timber = blend(blend(wood, [0x7d5a3f, 0x8a6446, 0x95704e][chalet.depth], 0.12), sky.horizon, 0.10 + 0.24 * dark)
        let shutterPaint: UInt32 = [0x9a2f2b, 0x2f6b45, 0x2c4f78, 0xb8862e, 0x5d7486][variant]
        let timberDark = blend(timber, 0x241a16, 0.42)
        let timberLit = blend(timber, 0xe8d2b4, 0.30)
        let stone = blend(0x9aa2ab, sky.horizon, 0.22 + 0.2 * dark)
        let roofWood = blend(0x463530, sky.horizon, 0.08 + 0.24 * dark)
        let snowWhite = multiply(blend(0xeef5fa, sky.alpenglow, sky.alpenglowStrength * 0.22), sky.valleyLight)

        // Masonry base storey.
        let stoneHeight = h * 0.26
        AdventPaint.box(ctx, CGRect(x: base.minX - w * 0.02, y: base.minY,
                                    width: w * 1.04, height: stoneHeight), 1, stone)
        if plastered {
            // A whitewashed ground floor with dressed corner stones, as in
            // the Engadin and the Goms.
            let wallRect = CGRect(x: base.minX - w * 0.02, y: base.minY, width: w * 1.04, height: stoneHeight)
            let plaster = multiply(blend(0xece4d6, sky.horizon, 0.12 + 0.2 * dark), sky.valleyLight)
            AdventPaint.box(ctx, wallRect, 1, plaster)
            if detail {
                let courses = 3
                let ch = stoneHeight / CGFloat(courses)
                for course in 0..<courses {
                    let long = course % 2 == 0
                    for side: CGFloat in [-1, 1] {
                        let width = w * (long ? 0.11 : 0.07)
                        let x = side < 0 ? wallRect.minX : wallRect.maxX - width
                        AdventPaint.box(ctx, CGRect(x: x, y: wallRect.minY + CGFloat(course) * ch + 0.4, width: width, height: ch - 0.8),
                                        0.5, blend(stone, 0x000000, 0.08))
                    }
                }
                // A painted band under the timber.
                AdventPaint.box(ctx, CGRect(x: wallRect.minX, y: wallRect.maxY - stoneHeight * 0.1, width: wallRect.width,
                                            height: stoneHeight * 0.06), 0, shutterPaint, alpha: 0.7)
            }
        }
        if detail && !plastered {
            // Dry-stone masonry: courses of rounded field stones, each its own
            // shade, with dark joints between them.
            let wallRect = CGRect(x: base.minX - w * 0.02, y: base.minY, width: w * 1.04, height: stoneHeight)
            AdventPaint.box(ctx, wallRect, 1, blend(stone, 0x2a2f36, 0.45))
            let courses = fine ? 3 : 2
            let courseHeight = stoneHeight / CGFloat(courses)
            let seed = Int((base.midX * 5).magnitude)
            for course in 0..<courses {
                var x = wallRect.minX + (course % 2 == 0 ? 0 : -courseHeight * 0.6)
                var k = 0
                while x < wallRect.maxX {
                    let length = courseHeight * (1.1 + AdventLayout.noise(seed + course * 31 + k, 980) * 1.1)
                    let tone = blend(stone, AdventLayout.noise(seed + course * 17 + k, 981) > 0.5 ? 0xffffff : 0x50565e,
                                     0.12 + AdventLayout.noise(seed + k, 982) * 0.14)
                    let block = CGRect(x: max(wallRect.minX, x) + 0.35, y: wallRect.minY + CGFloat(course) * courseHeight + 0.35,
                                       width: min(x + length, wallRect.maxX) - max(wallRect.minX, x) - 0.7,
                                       height: courseHeight - 0.7)
                    if block.width > 0.5 {
                        AdventPaint.box(ctx, block, courseHeight * 0.3, tone)
                        // Light catches the top of each stone.
                        AdventPaint.box(ctx, CGRect(x: block.minX + block.width * 0.15, y: block.maxY - block.height * 0.28,
                                                    width: block.width * 0.6, height: block.height * 0.18),
                                        block.height * 0.08, blend(tone, 0xffffff, 0.25), alpha: 0.7)
                    }
                    x += length
                    k += 1
                }
            }
        }

        // Stacked round logs.
        let wallBottom = base.minY + stoneHeight
        let wallHeight = h - stoneHeight
        let rows = max(3, min(7, Int(wallHeight / 5)))
        let logHeight = wallHeight / CGFloat(rows)
        for row in 0..<rows {
            let y = wallBottom + CGFloat(row) * logHeight
            let rect = CGRect(x: base.minX, y: y, width: w, height: logHeight * 0.98)
            ctx.saveGState()
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: logHeight * 0.42,
                               cornerHeight: logHeight * 0.42, transform: nil))
            ctx.clip()
            // A round log catches light along its upper half.
            let barrel = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                    colors: [AdventPaint.color(timberDark),
                                             AdventPaint.color(timber),
                                             AdventPaint.color(timberLit)] as CFArray,
                                    locations: [0, 0.45, 1])!
            ctx.drawLinearGradient(barrel, start: CGPoint(x: 0, y: rect.minY),
                                   end: CGPoint(x: 0, y: rect.maxY),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            ctx.restoreGState()
            // The notched ends standing proud of the corners.
            if detail {
                // Crossed corners: every other log runs through and stands
                // proud, showing its sawn end grain.
                let stick = w * (row % 2 == 0 ? 0.06 : 0.035)
                for side: CGFloat in [-1, 1] {
                    let outer = side < 0 ? base.minX - stick : base.maxX + stick
                    let stub = CGRect(x: min(outer, side < 0 ? base.minX : base.maxX), y: y + logHeight * 0.06,
                                      width: stick, height: logHeight * 0.88)
                    AdventPaint.box(ctx, stub, logHeight * 0.3, row % 2 == 0 ? timber : timberDark)
                    let grain = CGPoint(x: outer - side * logHeight * 0.05, y: y + logHeight * 0.5)
                    AdventPaint.oval(ctx, grain.x, grain.y, logHeight * 0.5, logHeight * 0.84,
                                     blend(timberLit, 0xd9b98f, 0.4))
                    if fine {
                        ctx.setStrokeColor(AdventPaint.color(timberDark, 0.55))
                        ctx.setLineWidth(0.4)
                        ctx.strokeEllipse(in: CGRect(x: grain.x - logHeight * 0.13, y: grain.y - logHeight * 0.22,
                                                     width: logHeight * 0.26, height: logHeight * 0.44))
                    }
                }
            }
        }
        if plastered {
            // Engadin style: the whole ground storey is whitewashed masonry
            // up to the balcony, dark timber only above it. Dressed corner
            // stones, a sgraffito band of diamonds, a sill beam on top.
            let top = base.minY + h * 0.48
            let wall = CGRect(x: base.minX - w * 0.02, y: base.minY, width: w * 1.04, height: top - base.minY)
            let plaster = multiply(blend(0xf1ebe0, sky.horizon, 0.10 + 0.22 * dark), sky.valleyLight)
            AdventPaint.box(ctx, wall, 1, plaster)
            // A faint shadow where the timber above overhangs the plaster.
            AdventPaint.box(ctx, CGRect(x: wall.minX, y: top - h * 0.05, width: wall.width, height: h * 0.05), 0,
                            0x3a2a20, alpha: 0.12)
            if detail {
                let courses = 5
                let ch = wall.height / CGFloat(courses)
                for course in 0..<courses {
                    let long = course % 2 == 0
                    for side: CGFloat in [-1, 1] {
                        let width = w * (long ? 0.10 : 0.06)
                        let x = side < 0 ? wall.minX : wall.maxX - width
                        AdventPaint.box(ctx, CGRect(x: x, y: wall.minY + CGFloat(course) * ch + 0.4, width: width, height: ch - 0.8),
                                        0.5, blend(plaster, 0x6c7480, 0.28))
                    }
                }
                // Sgraffito: a row of diamonds scratched into the plaster.
                let bandY = top - h * 0.10
                let diamonds = max(4, Int(w / 7))
                let paint = blend(shutterPaint, plaster, 0.25)
                for k in 0..<diamonds {
                    let x = wall.minX + w * 0.12 + (wall.width - w * 0.24) * (CGFloat(k) + 0.5) / CGFloat(diamonds)
                    let d = min(h * 0.035, w * 0.035)
                    let diamond = CGMutablePath()
                    diamond.move(to: CGPoint(x: x, y: bandY + d)); diamond.addLine(to: CGPoint(x: x + d, y: bandY))
                    diamond.addLine(to: CGPoint(x: x, y: bandY - d)); diamond.addLine(to: CGPoint(x: x - d, y: bandY))
                    diamond.closeSubpath()
                    ctx.setFillColor(AdventPaint.color(paint)); ctx.addPath(diamond); ctx.fillPath()
                }
                AdventPaint.box(ctx, CGRect(x: wall.minX + w * 0.1, y: bandY + h * 0.035, width: wall.width - w * 0.2, height: max(0.4, h * 0.008)),
                                0, paint)
                AdventPaint.box(ctx, CGRect(x: wall.minX + w * 0.1, y: bandY - h * 0.043, width: wall.width - w * 0.2, height: max(0.4, h * 0.008)),
                                0, paint)
            }
            // The sill beam the timber storey sits on.
            AdventPaint.box(ctx, CGRect(x: base.minX - w * 0.03, y: top - h * 0.01, width: w * 1.06, height: h * 0.035), 0.5, timberDark)
        }
        // The deep overhang throws a band of shadow onto the top of the wall.
        let eaveShadow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                    colors: [AdventPaint.color(0x140d0a, 0.55),
                                             AdventPaint.color(0x140d0a, 0)] as CFArray,
                                    locations: [0, 1])!
        ctx.saveGState()
        ctx.clip(to: CGRect(x: base.minX, y: base.maxY - h * 0.24, width: w, height: h * 0.24))
        ctx.drawLinearGradient(eaveShadow, start: CGPoint(x: 0, y: base.maxY),
                               end: CGPoint(x: 0, y: base.maxY - h * 0.24), options: [])
        ctx.restoreGState()
        // The gable is log wall too, right up under the ridge: rows of
        // logs getting shorter toward the top, in the shade of the roof.
        let peak = CGPoint(x: base.midX, y: base.maxY + chalet.roof)
        // The chimney stands on the roof behind the gable and rises clear
        // of the snow, so it is drawn first.
        if detail {
            let reach = w * 0.86
            let x = base.midX + w * 0.22
            let roofAt = peak.y - (x - peak.x) / reach * (chalet.roof + h * 0.05)
            let chimney = CGRect(x: x - w * 0.06, y: roofAt - chalet.roof * 0.2,
                                 width: w * 0.12, height: chalet.roof * 0.62)
            AdventPaint.box(ctx, chimney, 0.6, blend(0x6b6f73, sky.horizon, 0.15))
            AdventPaint.box(ctx, CGRect(x: chimney.minX, y: chimney.minY, width: chimney.width * 0.35,
                                        height: chimney.height), 0.4, blend(0x4f5357, sky.horizon, 0.15))
            AdventPaint.box(ctx, CGRect(x: chimney.minX - w * 0.015, y: chimney.maxY - w * 0.03,
                                        width: chimney.width + w * 0.03, height: w * 0.05), 0.8, snowWhite)
        }
        let gable = CGMutablePath()
        gable.addLines(between: [CGPoint(x: base.minX, y: base.maxY), peak, CGPoint(x: base.maxX, y: base.maxY)])
        gable.closeSubpath()
        ctx.saveGState()
        ctx.addPath(gable)
        ctx.clip()
        let gableRows = max(2, Int(chalet.roof / logHeight))
        let gableLog = chalet.roof / CGFloat(gableRows)
        let shadeLog = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(blend(timberDark, 0x140d0a, 0.25)),
                                           AdventPaint.color(blend(timber, 0x241a16, 0.25)),
                                           AdventPaint.color(blend(timberLit, 0x241a16, 0.20))] as CFArray,
                                  locations: [0, 0.45, 1])!
        for row in 0..<gableRows {
            let y = base.maxY + CGFloat(row) * gableLog
            ctx.saveGState()
            ctx.clip(to: CGRect(x: base.minX, y: y, width: w, height: gableLog * 0.96))
            ctx.drawLinearGradient(shadeLog, start: CGPoint(x: 0, y: y), end: CGPoint(x: 0, y: y + gableLog),
                                   options: [])
            ctx.restoreGState()
        }
        // The overhang shades the gable most just under the roof: a soft
        // shadow cast from above, not a hard dark band (that read as a second
        // roof inside the first).
        ctx.setShadow(offset: CGSize(width: 0, height: -w * 0.05), blur: w * 0.10,
                      color: AdventPaint.color(0x140d0a, 0.55))
        ctx.setStrokeColor(AdventPaint.color(0x140d0a, 1))
        ctx.setLineWidth(max(1, w * 0.06))
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.addLines(between: [CGPoint(x: base.minX, y: base.maxY + w * 0.05), CGPoint(x: peak.x, y: peak.y + w * 0.05),
                               CGPoint(x: base.maxX, y: base.maxY + w * 0.05)].map { CGPoint(x: $0.x, y: $0.y + w * 0.02) })
        ctx.strokePath()
        ctx.restoreGState()
        if detail {
            // A small attic window in the gable.
            let attic = CGRect(x: base.midX - w * 0.07, y: base.maxY + chalet.roof * 0.22,
                               width: w * 0.14, height: chalet.roof * 0.30)
            let warm = sky.lampStrength > 0.2 && Int(base.midX) % 3 == 0
            AdventPaint.box(ctx, attic.insetBy(dx: -w * 0.012, dy: -w * 0.012), 0.4, blend(timberLit, 0xffffff, 0.35))
            AdventPaint.box(ctx, attic, 0.4, warm ? 0xffd08a : 0x4d6170)
            ctx.setStrokeColor(AdventPaint.color(0x3a2a26, 0.6))
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: attic.midX, y: attic.minY))
            ctx.addLine(to: CGPoint(x: attic.midX, y: attic.maxY))
            ctx.strokePath()
            if warm { AdventPaint.glow(ctx, at: CGPoint(x: attic.midX, y: attic.midY), radius: w * 0.3, 0xffc87e,
                                       0.3 * sky.lampStrength) }
        }

        // Balcony across the front, with turned balusters; houses without
        // one get a carved band of sawn boards instead.
        if detail && !hasBalcony {
            let bandY = base.minY + h * 0.55
            AdventPaint.box(ctx, CGRect(x: base.minX - w * 0.02, y: bandY, width: w * 1.04, height: h * 0.05), 0.4, timberDark)
            let teeth = max(6, Int(w / 6))
            for k in 0..<teeth {
                let x = base.minX + w * (CGFloat(k) + 0.5) / CGFloat(teeth)
                AdventPaint.oval(ctx, x, bandY - h * 0.005, w * 0.035, h * 0.03, timberLit)
            }
        }
        if detail && hasBalcony {
            let railY = base.minY + h * 0.50
            let span = w + w * 0.46
            let left = base.midX - span / 2
            AdventPaint.box(ctx, CGRect(x: left, y: railY, width: span, height: h * 0.055), 0.4,
                            blend(0x6b4a33, sky.horizon, 0.1))
            let postTop = railY + h * 0.20
            AdventPaint.box(ctx, CGRect(x: left, y: postTop, width: span, height: h * 0.045), 0.4,
                            blend(0x7a5639, sky.horizon, 0.1))
            let posts = max(5, Int(span / 5))
            for post in 0...posts {
                let x = left + span * CGFloat(post) / CGFloat(posts)
                if fine {
                    // Sawn balusters: wide at top and foot, waisted between.
                    let bw = w * 0.026
                    let low = railY + h * 0.055, high = postTop
                    let baluster = CGMutablePath()
                    baluster.move(to: CGPoint(x: x - bw, y: low))
                    baluster.addQuadCurve(to: CGPoint(x: x - bw, y: high), control: CGPoint(x: x - bw * 0.2, y: (low + high) / 2))
                    baluster.addLine(to: CGPoint(x: x + bw, y: high))
                    baluster.addQuadCurve(to: CGPoint(x: x + bw, y: low), control: CGPoint(x: x + bw * 0.2, y: (low + high) / 2))
                    baluster.closeSubpath()
                    ctx.setFillColor(AdventPaint.color(blend(0x5c3f2c, sky.horizon, 0.08)))
                    ctx.addPath(baluster)
                    ctx.fillPath()
                } else {
                    AdventPaint.stroke(ctx, [CGPoint(x: x, y: railY + h * 0.05), CGPoint(x: x, y: postTop)], 0x5c3f2c,
                                       max(0.6, w * 0.016), alpha: 0.95)
                }
            }
            // Snow lying along the top rail.
            AdventPaint.box(ctx, CGRect(x: left - w * 0.01, y: postTop + h * 0.04, width: span + w * 0.02, height: h * 0.035),
                            h * 0.017, snowWhite)
            // Firewood stacked under the balcony.
            if fine {
                let stackX = base.minX + w * 0.06
                for log in 0..<6 {
                    let col = CGFloat(log % 3), row = CGFloat(log / 3)
                    AdventPaint.oval(ctx, stackX + col * w * 0.075, base.minY + stoneHeight * 0.30 + row * h * 0.06,
                                     w * 0.062, w * 0.062, log % 2 == 0 ? timberLit : timber)
                }
            }
        }

        // Windows with shutters.
        let total = max(1, layout.chalets.count)
        let order = CGFloat(abs((base.midX * 7).truncatingRemainder(dividingBy: CGFloat(total)))) / CGFloat(total)
        let alwaysHome = order < 0.18
        // On Christmas Eve the whole village is at home.
        let lit = sky.lampStrength > 0.2 && (alwaysHome || season.has(.finale) || season.warmth > order * 0.85)
        let count = fine ? [2, 3, 3, 4, 3, 2][style] : (detail ? 2 : 1)
        for slot in 0..<count {
            let share = (CGFloat(slot) + 0.5) / CGFloat(count)
            let center = CGPoint(x: base.minX + w * share, y: base.minY + h * 0.78)
            let size = CGSize(width: max(2.4, w * 0.15), height: max(2.8, h * 0.18))
            let frame = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                               width: size.width, height: size.height)
            if lit {
                AdventPaint.glow(ctx, at: center, radius: size.width * 2.6, 0xffc87e, 0.30 * sky.lampStrength)
                // One warm pool on the snow per house, not one per window.
                if slot == count / 2 {
                    ctx.saveGState()
                    ctx.translateBy(x: base.midX, y: base.minY)
                    ctx.scaleBy(x: 1, y: 0.3)
                    AdventPaint.glow(ctx, at: .zero, radius: w * 0.95, 0xffb86a, 0.24 * sky.lampStrength)
                    ctx.restoreGState()
                }
            }
            AdventPaint.box(ctx, frame.insetBy(dx: -size.width * 0.12, dy: -size.height * 0.1), 0.4,
                            blend(timberLit, 0xffffff, 0.4))
            AdventPaint.box(ctx, frame, 0.5, lit ? 0xffd79a : 0x58707f)
            if fine {
                if lit {
                    // Curtains drawn to the sides, a warm room between.
                    for side: CGFloat in [-1, 1] {
                        let curtain = CGRect(x: side < 0 ? frame.minX : frame.maxX - frame.width * 0.22, y: frame.minY,
                                             width: frame.width * 0.22, height: frame.height)
                        AdventPaint.box(ctx, curtain, 0.3, slot % 2 == 0 ? 0xc0584a : 0xe8d2a8, alpha: 0.85)
                    }
                } else {
                    // The sky reflected in the glass: a pale diagonal sheen.
                    ctx.saveGState()
                    ctx.clip(to: frame)
                    ctx.setFillColor(AdventPaint.color(0xdbe8f2, 0.35))
                    ctx.beginPath()
                    ctx.move(to: CGPoint(x: frame.minX, y: frame.maxY - frame.height * 0.15))
                    ctx.addLine(to: CGPoint(x: frame.minX + frame.width * 0.45, y: frame.maxY))
                    ctx.addLine(to: CGPoint(x: frame.minX + frame.width * 0.7, y: frame.maxY))
                    ctx.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - frame.height * 0.55))
                    ctx.closePath()
                    ctx.fillPath()
                    ctx.restoreGState()
                }
                // Transom bar across the panes.
                AdventPaint.stroke(ctx, [CGPoint(x: frame.minX, y: frame.midY + frame.height * 0.1),
                                         CGPoint(x: frame.maxX, y: frame.midY + frame.height * 0.1)],
                                   0x3a2a26, max(0.4, frame.height * 0.05), alpha: 0.6)
            }
            if season.has(.starsInWindows), w > 18 {
                // Door 10: a paper star hangs in every window, two stars laid
                // over each other like a Moravian star, glowing warm by day
                // and brightly after dark.
                let star = CGPoint(x: frame.midX, y: frame.midY - frame.height * 0.05)
                let r = min(frame.width, frame.height) * 0.52
                AdventPaint.glow(ctx, at: star, radius: r * 3.0, 0xffd98a, 0.55 + 0.3 * sky.lampStrength)
                AdventPaint.stroke(ctx, [CGPoint(x: star.x, y: frame.maxY), CGPoint(x: star.x, y: star.y + r)], 0x3a2a26, max(0.3, r * 0.08))
                AdventPaint.star(ctx, star.x, star.y, r, 0xf6c34a)
                ctx.saveGState()
                ctx.translateBy(x: star.x, y: star.y)
                ctx.rotate(by: .pi / 5)
                AdventPaint.star(ctx, 0, 0, r * 0.8, 0xfff2c4)
                ctx.restoreGState()
            }
            if fine {
                // A sill with a ridge of snow on it.
                AdventPaint.box(ctx, CGRect(x: frame.minX - size.width * 0.18, y: frame.minY - size.height * 0.12,
                                            width: frame.width + size.width * 0.36, height: size.height * 0.1),
                                0.3, blend(timberLit, 0x241a16, 0.2))
                AdventPaint.box(ctx, CGRect(x: frame.minX - size.width * 0.16, y: frame.minY - size.height * 0.03,
                                            width: frame.width + size.width * 0.32, height: size.height * 0.08),
                                size.height * 0.04, snowWhite)
            }
            if detail {
                for side: CGFloat in [-1, 1] {
                    let shutter = CGRect(x: center.x + side * size.width * 0.86 - size.width * 0.17,
                                         y: frame.minY, width: size.width * 0.34, height: size.height)
                    AdventPaint.box(ctx, shutter, 0.3, shutterPaint)
                    if fine {
                        // The Swiss flame pattern: pale chevrons on the painted leaf.
                        ctx.saveGState()
                        ctx.clip(to: shutter)
                        ctx.setStrokeColor(AdventPaint.color(0xf1e7d8, 0.9))
                        ctx.setLineWidth(max(0.5, shutter.width * 0.16))
                        ctx.setLineJoin(.miter)
                        for chevron in 0..<4 {
                            let y = shutter.minY + shutter.height * (0.12 + CGFloat(chevron) * 0.25)
                            ctx.move(to: CGPoint(x: shutter.minX, y: y))
                            ctx.addLine(to: CGPoint(x: shutter.midX, y: y + shutter.width * 0.45))
                            ctx.addLine(to: CGPoint(x: shutter.maxX, y: y))
                        }
                        ctx.strokePath()
                        ctx.restoreGState()
                    }
                }
                ctx.setStrokeColor(AdventPaint.color(0x3a2a26, 0.55))
                ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: frame.midX, y: frame.minY))
                ctx.addLine(to: CGPoint(x: frame.midX, y: frame.maxY))
                ctx.strokePath()
                if fine && variant != 1 {
                    // A window box, in winter filled with fir sprigs under snow.
                    let planter = CGRect(x: frame.minX - size.width * 0.05, y: frame.minY - size.height * 0.24,
                                         width: size.width * 1.1, height: size.height * 0.2)
                    AdventPaint.box(ctx, planter, 0.4, blend(timber, 0x241a16, 0.35))
                    for sprig in 0..<4 {
                        let x = planter.minX + planter.width * (0.15 + CGFloat(sprig) * 0.23)
                        AdventPaint.oval(ctx, x, planter.maxY + size.height * 0.05, size.width * 0.22, size.height * 0.16,
                                         0x2f5a3c)
                    }
                    AdventPaint.box(ctx, CGRect(x: planter.minX, y: planter.maxY + size.height * 0.06, width: planter.width,
                                                height: size.height * 0.07), size.height * 0.03, snowWhite)
                }
            }
        }

        // The roof seen end-on: only its thick edge shows — the barge board
        // with carved scallops, the purlin heads under it and a deep pillow
        // of snow on top.
        let eaves = w * 0.36
        let roofLeft = CGPoint(x: base.minX - eaves, y: base.maxY - h * 0.05)
        let roofRight = CGPoint(x: base.maxX + eaves, y: base.maxY - h * 0.05)
        let board = max(1.4, w * 0.075)
        func down(_ point: CGPoint, _ amount: CGFloat) -> CGPoint { CGPoint(x: point.x, y: point.y - amount) }
        // The underside of the overhang: seen from below, the boarded soffit
        // fills the space between the roof edge and the gable wall. Without
        // it the sky showed through under the roof.
        let soffit = blend(roofWood, 0x0d0907, 0.45)
        for (eave, corner) in [(roofLeft, CGPoint(x: base.minX, y: base.maxY)),
                               (roofRight, CGPoint(x: base.maxX, y: base.maxY))] {
            let under = CGMutablePath()
            under.move(to: down(eave, board * 0.9))
            under.addLine(to: down(peak, board))
            under.addLine(to: corner)
            under.addLine(to: CGPoint(x: corner.x, y: corner.y - h * 0.05))
            under.closeSubpath()
            ctx.setFillColor(AdventPaint.color(soffit))
            ctx.addPath(under)
            ctx.fillPath()
            if detail {
                // Rafters running from the wall out to the eave.
                ctx.saveGState()
                ctx.addPath(under)
                ctx.clip()
                ctx.setStrokeColor(AdventPaint.color(blend(soffit, timber, 0.35), 0.9))
                ctx.setLineWidth(max(0.4, w * 0.018))
                let rafters = max(3, Int(w / 9))
                for rafter in 1...rafters {
                    let t = CGFloat(rafter) / CGFloat(rafters + 1)
                    let onWall = CGPoint(x: corner.x + (peak.x - corner.x) * t, y: corner.y + (peak.y - corner.y) * t)
                    let onEave = down(CGPoint(x: eave.x + (peak.x - eave.x) * t, y: eave.y + (peak.y - eave.y) * t), board)
                    ctx.move(to: onWall)
                    ctx.addLine(to: onEave)
                }
                ctx.strokePath()
                ctx.restoreGState()
            }
        }
        if detail {
            // Purlins are round logs too: their sawn ends show under the board,
            // three down each slope and the ridge purlin right under the apex.
            var heads: [CGPoint] = [CGPoint(x: peak.x, y: peak.y - board * 1.15 - w * 0.06)]
            for side: CGFloat in [-1, 1] {
                let edge = side < 0 ? roofLeft : roofRight
                for beam in 0..<3 {
                    let t = 0.16 + CGFloat(beam) * 0.27
                    let at = CGPoint(x: edge.x + (peak.x - edge.x) * t, y: edge.y + (peak.y - edge.y) * t)
                    heads.append(CGPoint(x: at.x, y: at.y - board - w * 0.045))
                }
            }
            for (index, head) in heads.enumerated() {
                let r = w * (index == 0 ? 0.058 : 0.045)
                // A short stub of log, then its lit end grain and growth rings.
                AdventPaint.oval(ctx, head.x, head.y - r * 0.15, r * 2.1, r * 2.0, blend(roofWood, 0x000000, 0.25))
                AdventPaint.oval(ctx, head.x - r * 0.08, head.y, r * 1.8, r * 1.8, blend(timberLit, 0xc9a77a, 0.45))
                if fine {
                    ctx.setStrokeColor(AdventPaint.color(blend(timber, 0x3a2a20, 0.4), 0.55))
                    ctx.setLineWidth(max(0.3, r * 0.1))
                    for ring: CGFloat in [0.55, 0.3] {
                        ctx.strokeEllipse(in: CGRect(x: head.x - r * 0.08 - r * ring, y: head.y - r * ring,
                                                     width: r * ring * 2, height: r * ring * 2))
                    }
                    // A cap of snow on each log end.
                    AdventPaint.oval(ctx, head.x, head.y + r * 0.85, r * 1.7, r * 0.55, snowWhite)
                }
            }
        }
        let boardPath = CGMutablePath()
        boardPath.addLines(between: [roofLeft, peak, roofRight, down(roofRight, board), down(peak, board * 1.15),
                                     down(roofLeft, board)])
        boardPath.closeSubpath()
        ctx.setFillColor(AdventPaint.color(blend(roofWood, timber, 0.35)))
        ctx.addPath(boardPath)
        ctx.fillPath()
        if fine {
            // The board is two planks: a seam along its middle.
            AdventPaint.stroke(ctx, [down(roofLeft, board * 0.5), down(peak, board * 0.6), down(roofRight, board * 0.5)],
                               blend(roofWood, 0x000000, 0.3), max(0.3, board * 0.06), alpha: 0.6)
        }
        // A lighter lower edge on the board, then the carved scallops.
        AdventPaint.stroke(ctx, [down(roofLeft, board), down(peak, board * 1.15), down(roofRight, board)],
                           blend(timberLit, 0x8a6446, 0.3), max(0.5, board * 0.22))
        if detail {
            ctx.setFillColor(AdventPaint.color(blend(timberLit, 0x8a6446, 0.3)))
            let scallops = max(4, Int(w / 7))
            for side in [roofLeft, roofRight] {
                for scallop in 0..<scallops {
                    let t = (CGFloat(scallop) + 0.5) / CGFloat(scallops)
                    let at = down(CGPoint(x: side.x + (peak.x - side.x) * t, y: side.y + (peak.y - side.y) * t),
                                  board * 1.05)
                    let r = max(0.5, board * 0.28)
                    ctx.fillEllipse(in: CGRect(x: at.x - r, y: at.y - r * 1.2, width: r * 2, height: r * 2))
                }
            }
        }
        // From the seventh door: a string of lights under the roof edge.
        if detail && season.has(.garland) {
            let tints: [UInt32] = [0xffe2a8, 0xe5574e, 0x5fb36d, 0x7fb4ef]
            let glowing = sky.lampStrength > 0.2
            for side in [roofLeft, roofRight] {
                let bulbs = max(5, Int(w / 6))
                for bulb in 0..<bulbs {
                    let t = (CGFloat(bulb) + 0.5) / CGFloat(bulbs) * 0.96
                    let at = CGPoint(x: side.x + (peak.x - side.x) * t,
                                     y: side.y + (peak.y - side.y) * t - board * 1.25 - sin(CGFloat(bulb) * 1.7) * board * 0.12)
                    let tint = tints[(bulb + (side == roofLeft ? 0 : 2)) % 4]
                    if glowing { AdventPaint.glow(ctx, at: at, radius: w * 0.05, tint, 0.45 * sky.lampStrength) }
                    AdventPaint.oval(ctx, at.x, at.y, max(1.2, w * 0.022), max(1.4, w * 0.026), tint, alpha: glowing ? 1 : 0.55)
                }
            }
        }
        // Snow: a cushion of roughly even depth lying along each slope, with
        // a lumpy crest, a cool front face where it rounds over the board, a
        // droop hanging past each eave and a mound along the ridge.
        let snowDepth = max(1.8, w * 0.11)
        let seed = Int((base.midX * 3 + base.minY).magnitude)
        func crest(from eave: CGPoint, outwardSign: CGFloat) -> [CGPoint] {
            let dx = peak.x - eave.x, dy = peak.y - eave.y
            let length = max(1, hypot(dx, dy))
            // Normal pointing up and away from the roof.
            var n = CGPoint(x: -dy / length, y: dx / length)
            if n.y < 0 { n = CGPoint(x: -n.x, y: -n.y) }
            var points: [CGPoint] = []
            let steps = fine ? 14 : 7
            for step in 0...steps {
                let t = CGFloat(step) / CGFloat(steps)
                let lump = 0.82 + 0.36 * AdventLayout.noise(seed + step * 7 + Int(outwardSign + 2), 950)
                // Rounded off at the eave, swelling a little at the ridge.
                let ease = min(1, t / 0.08) * (1 + 0.25 * max(0, t - 0.85) / 0.15)
                let depth = snowDepth * lump * (0.35 + 0.65 * ease)
                points.append(CGPoint(x: eave.x + dx * t + n.x * depth, y: eave.y + dy * t + n.y * depth))
            }
            return points
        }
        let leftCrest = crest(from: roofLeft, outwardSign: -1)
        let rightCrest = crest(from: roofRight, outwardSign: 1)
        let cushion = CGMutablePath()
        let droop = board * 0.55
        cushion.move(to: CGPoint(x: roofLeft.x + board * 0.2, y: roofLeft.y - droop))
        // Droop over the left eave, rounding up into the crest.
        cushion.addQuadCurve(to: leftCrest[0], control: CGPoint(x: roofLeft.x - snowDepth * 0.9, y: roofLeft.y - droop * 0.4))
        func smooth(_ points: [CGPoint], into path: CGMutablePath) {
            for index in 1..<points.count {
                let mid = CGPoint(x: (points[index - 1].x + points[index].x) / 2, y: (points[index - 1].y + points[index].y) / 2)
                path.addQuadCurve(to: mid, control: points[index - 1])
            }
            path.addLine(to: points[points.count - 1])
        }
        smooth(leftCrest, into: cushion)
        // Over the ridge in a soft mound.
        cushion.addQuadCurve(to: rightCrest[rightCrest.count - 1],
                             control: CGPoint(x: peak.x, y: max(leftCrest.last!.y, rightCrest.last!.y) + snowDepth * 0.45))
        smooth(Array(rightCrest.reversed()), into: cushion)
        cushion.addQuadCurve(to: CGPoint(x: roofRight.x - board * 0.2, y: roofRight.y - droop),
                             control: CGPoint(x: roofRight.x + snowDepth * 0.9, y: roofRight.y - droop * 0.4))
        cushion.addLine(to: down(roofRight, board * 0.15))
        cushion.addLine(to: down(peak, board * 0.15))
        cushion.addLine(to: down(roofLeft, board * 0.15))
        cushion.closeSubpath()
        ctx.saveGState()
        ctx.addPath(cushion)
        ctx.clip()
        let snowShade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                   colors: [AdventPaint.color(blend(snowWhite, 0x8ea4bd, 0.5)),
                                            AdventPaint.color(snowWhite),
                                            AdventPaint.color(blend(snowWhite, 0xffffff, 0.6))] as CFArray,
                                   locations: [0, 0.5, 1])!
        ctx.drawLinearGradient(snowShade, start: CGPoint(x: 0, y: roofLeft.y - droop),
                               end: CGPoint(x: 0, y: peak.y + snowDepth * 1.3),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        // The front face of the cushion, where it curls over the board, lies
        // in its own shade.
        ctx.setStrokeColor(AdventPaint.color(blend(snowWhite, 0x7f94b0, 0.4), 0.55))
        ctx.setLineWidth(snowDepth * 0.7)
        ctx.setLineJoin(.round)
        ctx.beginPath()
        ctx.addLines(between: [roofLeft, peak, roofRight])
        ctx.strokePath()
        ctx.restoreGState()
        // Lit crest along the top of the snow, and a few glints.
        if detail {
            ctx.saveGState()
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setStrokeColor(AdventPaint.color(0xffffff, 0.75))
            ctx.setLineWidth(max(0.5, snowDepth * 0.12))
            let crestPath = CGMutablePath()
            crestPath.move(to: leftCrest[0])
            smooth(leftCrest, into: crestPath)
            ctx.addPath(crestPath)
            ctx.strokePath()
            ctx.restoreGState()
            if fine {
                for glint in 0..<6 {
                    let source = glint % 2 == 0 ? leftCrest : rightCrest
                    let point = source[1 + (glint * 3) % (source.count - 2)]
                    AdventPaint.oval(ctx, point.x, point.y - snowDepth * 0.25, 1.1, 1.1, 0xffffff, alpha: 0.85)
                }
            }
        }
        // A few icicles where the snow hangs over the eaves.
        if detail {
            ctx.setFillColor(AdventPaint.color(0xe4f0fa, 0.9))
            for side in [roofLeft, roofRight] {
                for icicle in 0..<3 {
                    let t = 0.04 + CGFloat(icicle) * 0.07
                    let at = down(CGPoint(x: side.x + (peak.x - side.x) * t, y: side.y + (peak.y - side.y) * t), board)
                    let length = w * (0.04 + AdventLayout.noise(Int(base.midX) + icicle, 77) * 0.06)
                    ctx.beginPath()
                    ctx.move(to: CGPoint(x: at.x - w * 0.012, y: at.y))
                    ctx.addLine(to: CGPoint(x: at.x + w * 0.012, y: at.y))
                    ctx.addLine(to: CGPoint(x: at.x, y: at.y - length))
                    ctx.closePath()
                    ctx.fillPath()
                }
            }
        }

        // Snow banked against the walls, with the path to the door shovelled clear.
        if detail {
            let doorHalf = w * 0.17
            for (from, to) in [(base.minX - eaves * 0.35, base.midX - doorHalf),
                               (base.midX + doorHalf, base.maxX + eaves * 0.35)] {
                let drift = CGMutablePath()
                drift.move(to: CGPoint(x: from, y: base.minY - 1))
                let bumps = fine ? 4 : 2
                var last = CGPoint(x: from, y: base.minY - 1)
                for bump in 1...bumps {
                    let t = CGFloat(bump) / CGFloat(bumps)
                    let x = from + (to - from) * t
                    let height = h * (0.10 + AdventLayout.noise(Int(x.magnitude) + bump, 990) * 0.08) * sin(t * .pi * 0.9 + 0.15)
                    let end = CGPoint(x: x, y: bump == bumps ? base.minY - 1 : base.minY + height * 0.6)
                    drift.addQuadCurve(to: end, control: CGPoint(x: (last.x + x) / 2, y: base.minY + height))
                    last = end
                }
                drift.closeSubpath()
                ctx.saveGState()
                ctx.addPath(drift)
                ctx.clip()
                let driftShade = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                            colors: [AdventPaint.color(blend(snowWhite, 0x8ea4bd, 0.35)),
                                                     AdventPaint.color(snowWhite)] as CFArray, locations: [0, 1])!
                ctx.drawLinearGradient(driftShade, start: CGPoint(x: 0, y: base.minY), end: CGPoint(x: 0, y: base.minY + h * 0.16),
                                       options: [.drawsAfterEndLocation])
                ctx.restoreGState()
                ctx.setStrokeColor(AdventPaint.color(blend(snowWhite, 0xffffff, 0.4), 0.6))
                ctx.setLineWidth(0.6)
                ctx.addPath(drift)
                ctx.strokePath()
            }
        }
    }

    /// The snowy valley floor the village stands on. Without it the bottom of
    /// the screen showed the rock colour of the nearest range, so the houses
    /// stood on grey instead of snow.
    private static func drawValleyFloor(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let bounds = layout.bounds
        let top = bounds.minY + bounds.height * 0.395
        let surface = CGMutablePath()
        surface.move(to: CGPoint(x: bounds.minX, y: bounds.minY))
        let steps = 48
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let swell = sin(t * 6.8 + 0.6) * 0.011 + sin(t * 15.3 + 1.9) * 0.004
            surface.addLine(to: CGPoint(x: bounds.minX + bounds.width * t,
                                        y: top + bounds.height * swell))
        }
        surface.addLine(to: CGPoint(x: bounds.maxX, y: bounds.minY))
        surface.closeSubpath()
        ctx.saveGState()
        ctx.addPath(surface)
        ctx.clip()
        // The valley sits in the same light as the mountains, a little
        // brighter because it is near: blue under the moon, never paper white.
        let nearLight = blend(sky.mountainLight, 0xffffff, 0.30)
        let farLight = blend(sky.mountainLight, 0xffffff, 0.08)
        let snow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [AdventPaint.color(multiply(blend(0xf6f9fc, sky.horizon, 0.10), nearLight)),
                                       AdventPaint.color(multiply(blend(0xe6eef6, sky.horizon, 0.18),
                                                                  blend(nearLight, farLight, 0.6))),
                                       AdventPaint.color(multiply(blend(0xcad8e7, sky.horizon, 0.30), farLight))] as CFArray,
                              locations: [0, 0.6, 1])!
        ctx.drawLinearGradient(snow, start: CGPoint(x: 0, y: bounds.minY),
                               end: CGPoint(x: 0, y: top + bounds.height * 0.015),
                               options: [.drawsAfterEndLocation])
        // Soft dunes: a little shade on the lee side of each swell.
        ctx.setStrokeColor(AdventPaint.color(blend(0xa8bcd0, sky.horizon, 0.2), 0.28))
        ctx.setLineCap(.round)
        for dune in 0..<5 {
            let y = bounds.minY + bounds.height * (0.05 + CGFloat(dune) * 0.068)
            ctx.setLineWidth(bounds.height * 0.004)
            ctx.move(to: CGPoint(x: bounds.minX, y: y))
            ctx.addCurve(to: CGPoint(x: bounds.maxX, y: y + bounds.height * 0.006),
                         control1: CGPoint(x: bounds.width * 0.33, y: y + bounds.height * 0.022),
                         control2: CGPoint(x: bounds.width * 0.66, y: y - bounds.height * 0.016))
            ctx.strokePath()
        }
        ctx.restoreGState()
        // A bright rim where the valley floor meets the mountains.
        ctx.setStrokeColor(AdventPaint.color(0xffffff, 0.12 + 0.33 * sky.daylight))
        ctx.setLineWidth(1.2)
        ctx.addPath(surface)
        ctx.strokePath()
    }

    /// The open snowfield in front of the village: soft drifts with blue
    /// shadows, a trail of footprints down to the pond and a snowman the
    /// village children built.
    private static func drawForegroundField(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky,
                                            in ctx: CGContext) {
        let bounds = layout.bounds
        let w = bounds.width, h = bounds.height
        let snow = multiply(0xf4f8fc, sky.valleyLight)
        let shade = multiply(0xb3c3d6, sky.valleyLight)
        // Drifts: low mounds, lit on top, shadowed underneath.
        // Above the band where the real fallen snow piles up at the bottom
        // of the screen, which would bury them.
        for (fx, fy, fw) in [(0.17, 0.058, 0.09), (0.42, 0.064, 0.10), (0.92, 0.104, 0.06)]
            as [(CGFloat, CGFloat, CGFloat)] {
            let base = CGPoint(x: bounds.minX + w * fx, y: bounds.minY + h * fy)
            let width = w * fw, height = h * 0.018
            let mound = CGMutablePath()
            mound.move(to: CGPoint(x: base.x - width / 2, y: base.y))
            mound.addCurve(to: CGPoint(x: base.x + width / 2, y: base.y),
                           control1: CGPoint(x: base.x - width * 0.25, y: base.y + height * 1.3),
                           control2: CGPoint(x: base.x + width * 0.15, y: base.y + height * 1.1))
            mound.closeSubpath()
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: width * 0.04, height: -height * 0.35), blur: height * 0.9,
                          color: AdventPaint.color(shade, 0.8))
            ctx.setFillColor(AdventPaint.color(snow))
            ctx.addPath(mound)
            ctx.fillPath()
            ctx.restoreGState()
            AdventPaint.stroke(ctx, [CGPoint(x: base.x - width * 0.3, y: base.y + height * 0.65),
                                     CGPoint(x: base.x - width * 0.05, y: base.y + height * 0.85)],
                               0xffffff, max(0.6, height * 0.12), alpha: 0.7 * (0.4 + sky.daylight * 0.6))
        }
        // Dry grass and the tips of a few bushes poke through the snow at the
        // foot of the drifts, so the field is not an empty sheet.
        let straw = multiply(0x8a7650, sky.valleyLight)
        ctx.setLineCap(.round)
        for tuft in 0..<14 {
            let x = bounds.minX + w * (0.08 + AdventLayout.noise(tuft, 1210) * 0.48)
            let y = bounds.minY + h * (0.050 + AdventLayout.noise(tuft, 1211) * 0.045)
            let size = h * (0.008 + AdventLayout.noise(tuft, 1212) * 0.008)
            for blade in 0..<5 {
                let lean = (CGFloat(blade) - 2) * 0.28 + (AdventLayout.noise(tuft * 7 + blade, 1213) - 0.5) * 0.3
                let length = size * (0.7 + AdventLayout.noise(tuft * 5 + blade, 1214) * 0.6)
                ctx.setStrokeColor(AdventPaint.color(straw, 0.75))
                ctx.setLineWidth(max(0.5, h * 0.0011))
                ctx.move(to: CGPoint(x: x + CGFloat(blade - 2) * size * 0.08, y: y))
                ctx.addQuadCurve(to: CGPoint(x: x + sin(lean) * length, y: y + cos(lean) * length),
                                 control: CGPoint(x: x + sin(lean) * length * 0.3, y: y + length * 0.6))
                ctx.strokePath()
            }
            // Snow banked round the foot of the tuft.
            AdventPaint.oval(ctx, x, y, size * 1.3, size * 0.35, snow)
        }
        // A child's wooden sled left beside the snowman, its rope trailing,
        // with a dusting of fresh snow on the slats.
        do {
            let r = h * 0.0108
            let foot = CGPoint(x: bounds.minX + w * 0.585 - r * 3.4, y: bounds.minY + h * 0.068)
            let wood = multiply(0xa0663a, sky.valleyLight)
            let runner = multiply(0x5a3a24, sky.valleyLight)
            AdventPaint.oval(ctx, foot.x + r * 0.2, foot.y - r * 0.05, r * 3.0, r * 0.45, shade, alpha: 0.5)
            AdventPaint.stroke(ctx, [CGPoint(x: foot.x - r * 1.2, y: foot.y), CGPoint(x: foot.x + r * 1.1, y: foot.y),
                                     CGPoint(x: foot.x + r * 1.45, y: foot.y + r * 0.45)], runner, max(0.6, r * 0.14))
            for strut: CGFloat in [-0.8, 0.0, 0.8] {
                AdventPaint.stroke(ctx, [CGPoint(x: foot.x + strut * r, y: foot.y), CGPoint(x: foot.x + strut * r, y: foot.y + r * 0.42)],
                                   runner, max(0.5, r * 0.1))
            }
            AdventPaint.box(ctx, CGRect(x: foot.x - r * 1.2, y: foot.y + r * 0.40, width: r * 2.3, height: r * 0.28), r * 0.06, wood)
            ctx.setStrokeColor(AdventPaint.color(multiply(0x6e4428, sky.valleyLight), 0.8))
            ctx.setLineWidth(max(0.4, r * 0.04))
            for slat in 1..<4 {
                let x = foot.x - r * 1.2 + r * 2.3 * CGFloat(slat) / 4
                ctx.move(to: CGPoint(x: x, y: foot.y + r * 0.40)); ctx.addLine(to: CGPoint(x: x, y: foot.y + r * 0.68))
            }
            ctx.strokePath()
            AdventPaint.box(ctx, CGRect(x: foot.x - r * 0.9, y: foot.y + r * 0.64, width: r * 1.4, height: r * 0.08), r * 0.04, snow)
            ctx.setStrokeColor(AdventPaint.color(multiply(0xb23a32, sky.valleyLight), 0.9))
            ctx.setLineWidth(max(0.4, r * 0.06))
            ctx.move(to: CGPoint(x: foot.x + r * 1.45, y: foot.y + r * 0.45))
            ctx.addQuadCurve(to: CGPoint(x: foot.x + r * 2.2, y: foot.y - r * 0.15), control: CGPoint(x: foot.x + r * 2.3, y: foot.y + r * 0.5))
            ctx.strokePath()
            // The snow trampled round the snowman while it was built: a
            // flattened ring, and boot prints in pairs, left and right, along
            // the path the children walked round it, seen in perspective.
            let middle = CGPoint(x: bounds.minX + w * 0.585, y: foot.y)
            AdventPaint.pool(ctx, at: middle, width: r * 6.4, flat: 0.30, shade, 0.30)
            for step in 0..<18 {
                let a = CGFloat(step) / 18 * .pi * 2 + AdventLayout.noise(step, 870) * 0.25
                let reach = r * (2.3 + AdventLayout.noise(step, 871) * 0.7)
                let centre = CGPoint(x: middle.x + cos(a) * reach, y: middle.y + sin(a) * reach * 0.30)
                for side: CGFloat in [-1, 1] {
                    ctx.saveGState()
                    ctx.translateBy(x: centre.x, y: centre.y)
                    ctx.scaleBy(x: 1, y: 0.42)
                    ctx.rotate(by: a + .pi / 2)
                    AdventPaint.oval(ctx, side * r * 0.13, side * r * 0.08, r * 0.30, r * 0.15, shade, alpha: 0.5)
                    ctx.restoreGState()
                }
            }
        }
        // Footprints from the road down to the pond's bench, pairs of small
        // pressed ovals, fainter further from the road.
        if season.has(.pond), layout.roads.count == 3 {
            let bench = AdventVillage.pondBench(layout)
            // The prints end in front of the bench, where someone sat down.
            let start = CGPoint(x: bench.minX - bench.height * 0.6, y: bench.minY - bench.height * 1.3)
            let road = layout.roads[2]
            let top = AdventVillage.roadPoint(road, at: start.x - w * 0.05).map { CGPoint(x: $0.x, y: $0.y - road.width * 0.75) }
                ?? CGPoint(x: start.x - w * 0.05, y: start.y + h * 0.06)
            let steps = 16
            for step in 0..<steps {
                let t = CGFloat(step) / CGFloat(steps - 1)
                let sway = sin(t * .pi * 1.4) * w * 0.010
                let centre = CGPoint(x: top.x + (start.x - top.x) * t + sway, y: top.y + (start.y - top.y) * t)
                let side: CGFloat = step % 2 == 0 ? -1 : 1
                let print = CGPoint(x: centre.x + side * w * 0.0016, y: centre.y + side * h * 0.0006)
                // A boot print: an elongated sole pointing along the way.
                let angle = atan2(start.y - top.y, start.x - top.x)
                ctx.saveGState()
                ctx.translateBy(x: print.x, y: print.y)
                ctx.rotate(by: angle)
                AdventPaint.oval(ctx, 0, 0, w * 0.0034, h * 0.0024, shade, alpha: 0.5 * (0.6 + t * 0.4))
                AdventPaint.oval(ctx, -w * 0.0021, 0, w * 0.0015, h * 0.0022, shade, alpha: 0.45 * (0.6 + t * 0.4))
                ctx.restoreGState()
            }
        }
        if season.has(.pond) { AdventVillage.drawBenchInField(layout, sky: sky, in: ctx) }
        // A snowman in the field: three balls, coal eyes, carrot, a red
        // scarf, twig arms and a little pot for a hat.
        // Between the fallen snow at the bottom of the screen and the near
        // road, where the road runs high, just left of the pond.
        let foot = CGPoint(x: bounds.minX + w * 0.585, y: bounds.minY + h * 0.068)
        let r = h * 0.0108
        let balls: [(CGFloat, CGFloat)] = [(r, r), (r * 0.72, r * 2.45), (r * 0.5, r * 3.55)]
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: r * 0.3, height: -r * 0.15), blur: r * 0.6, color: AdventPaint.color(shade, 0.6))
        AdventPaint.oval(ctx, foot.x + r * 0.4, foot.y - r * 0.05, r * 2.6, r * 0.5, shade, alpha: 0.5)
        ctx.restoreGState()
        // A ring of trodden snow round the foot, behind the balls.
        AdventPaint.oval(ctx, foot.x, foot.y + r * 0.12, r * 2.3, r * 0.3, snow, alpha: 0.6)
        AdventPaint.oval(ctx, foot.x - r * 0.95, foot.y + r * 0.12, r * 0.45, r * 0.24, snow)
        AdventPaint.oval(ctx, foot.x + r * 1.0, foot.y + r * 0.08, r * 0.35, r * 0.2, snow)
        for (radius, height) in balls {
            let centre = CGPoint(x: foot.x, y: foot.y + height)
            let ball = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(snow), AdventPaint.color(shade)] as CFArray, locations: [0.35, 1])!
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
            ctx.clip()
            ctx.drawRadialGradient(ball, startCenter: CGPoint(x: centre.x - radius * 0.35, y: centre.y + radius * 0.35),
                                   startRadius: 0, endCenter: centre, endRadius: radius * 1.15,
                                   options: [.drawsAfterEndLocation])
            // Packed by hand: a few dents and lighter lumps on the surface.
            for lump in 0..<5 {
                let a = CGFloat(lump) * 1.3 + radius
                let at = CGPoint(x: centre.x + cos(a) * radius * 0.55, y: centre.y + sin(a) * radius * 0.5)
                AdventPaint.oval(ctx, at.x, at.y, radius * 0.32, radius * 0.22, lump % 2 == 0 ? snow : shade, alpha: 0.35)
            }
            ctx.restoreGState()
            // Snow crumbs where the ball sits on the one below.
            for crumb in 0..<(height < r * 3 && height > r * 1.5 ? 4 : 0) {
                let t = (CGFloat(crumb) + 0.5) / 4
                AdventPaint.oval(ctx, centre.x - radius * 0.8 + radius * 1.6 * t, centre.y - radius * 0.92,
                                 radius * 0.28, radius * 0.16, snow, alpha: 0.9)
            }
        }

        let head = CGPoint(x: foot.x, y: foot.y + r * 3.55)
        AdventPaint.oval(ctx, head.x - r * 0.18, head.y + r * 0.1, r * 0.12, r * 0.12, 0x1e1a18)
        AdventPaint.oval(ctx, head.x + r * 0.16, head.y + r * 0.1, r * 0.12, r * 0.12, 0x1e1a18)
        ctx.setFillColor(AdventPaint.color(0xe8762c))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: head.x + r * 0.02, y: head.y + r * 0.02))
        ctx.addLine(to: CGPoint(x: head.x + r * 0.55, y: head.y - r * 0.08))
        ctx.addLine(to: CGPoint(x: head.x + r * 0.02, y: head.y - r * 0.14))
        ctx.closePath()
        ctx.fillPath()
        for ridge in 1...2 {
            let x = head.x + r * (0.02 + 0.16 * CGFloat(ridge))
            AdventPaint.stroke(ctx, [CGPoint(x: x, y: head.y + r * 0.01 - r * 0.02 * CGFloat(ridge)),
                                     CGPoint(x: x + r * 0.03, y: head.y - r * 0.11 + r * 0.01 * CGFloat(ridge))],
                               0xb4541c, max(0.3, r * 0.03))
        }
        // A smile of little coals.
        for coal in 0..<5 {
            let a = CGFloat.pi * (1.18 + 0.16 * CGFloat(coal))
            AdventPaint.oval(ctx, head.x - r * 0.02 + cos(a) * r * 0.17, head.y - r * 0.12 + sin(a) * r * 0.09,
                             r * 0.075, r * 0.075, 0x1e1a18)
        }
        AdventPaint.box(ctx, CGRect(x: head.x - r * 0.55, y: head.y - r * 0.55, width: r * 1.1, height: r * 0.22), r * 0.1, 0xc23b32)
        AdventPaint.stroke(ctx, [CGPoint(x: head.x + r * 0.25, y: head.y - r * 0.5), CGPoint(x: head.x + r * 0.4, y: head.y - r * 1.1)],
                           0xc23b32, r * 0.18)
        for stripe in 0..<3 {
            let x = head.x - r * 0.35 + r * 0.3 * CGFloat(stripe)
            AdventPaint.box(ctx, CGRect(x: x, y: head.y - r * 0.55, width: r * 0.08, height: r * 0.22), 0, 0xf3e7cf)
        }
        AdventPaint.box(ctx, CGRect(x: head.x + r * 0.27, y: head.y - r * 0.82, width: r * 0.16, height: r * 0.06), 0, 0xf3e7cf)
        for fringe in 0..<3 {
            let x = head.x + r * (0.33 + 0.06 * CGFloat(fringe))
            AdventPaint.stroke(ctx, [CGPoint(x: x, y: head.y - r * 1.08), CGPoint(x: x + r * 0.02, y: head.y - r * 1.22)],
                               0xc23b32, max(0.3, r * 0.04))
        }
        AdventPaint.box(ctx, CGRect(x: head.x - r * 0.38, y: head.y + r * 0.42, width: r * 0.76, height: r * 0.42), r * 0.05, 0x3a3236)
        AdventPaint.box(ctx, CGRect(x: head.x - r * 0.5, y: head.y + r * 0.38, width: r, height: r * 0.1), r * 0.04, 0x3a3236)
        AdventPaint.box(ctx, CGRect(x: head.x - r * 0.46, y: head.y + r * 0.47, width: r * 0.3, height: r * 0.06), r * 0.03, snow)
        AdventPaint.box(ctx, CGRect(x: head.x - r * 0.34, y: head.y + r * 0.83, width: r * 0.5, height: r * 0.07), r * 0.03, snow)
        AdventPaint.box(ctx, CGRect(x: head.x - r * 0.38, y: head.y + r * 0.6, width: r * 0.76, height: r * 0.07), 0, 0x8a2a26)
        for side: CGFloat in [-1, 1] {
            let shoulder = CGPoint(x: foot.x + side * r * 0.6, y: foot.y + r * 2.6)
            AdventPaint.stroke(ctx, [shoulder, CGPoint(x: shoulder.x + side * r * 0.9, y: shoulder.y + r * 0.6),
                                     CGPoint(x: shoulder.x + side * r * 1.15, y: shoulder.y + r * 0.95)], 0x4a3a2c, r * 0.1)
            let hand = CGPoint(x: shoulder.x + side * r * 1.15, y: shoulder.y + r * 0.95)
            AdventPaint.stroke(ctx, [hand, CGPoint(x: hand.x + side * r * 0.25, y: hand.y + r * 0.1)], 0x4a3a2c, r * 0.06)
            AdventPaint.stroke(ctx, [hand, CGPoint(x: hand.x + side * r * 0.02, y: hand.y + r * 0.28)], 0x4a3a2c, r * 0.06)
            AdventPaint.stroke(ctx, [CGPoint(x: shoulder.x + side * r * 0.55, y: shoulder.y + r * 0.37),
                                     CGPoint(x: shoulder.x + side * r * 0.6, y: shoulder.y + r * 0.62)], 0x4a3a2c, r * 0.05)
        }
        for button in 0..<3 {
            AdventPaint.oval(ctx, foot.x, foot.y + r * (1.95 + CGFloat(button) * 0.32), r * 0.1, r * 0.1, 0x1e1a18)
        }
        if season.has(.snowmanFamily) {
            // Door 12: the snowman gets a family, a snow woman with a
            // pink bobble hat and a little snow child in a blue one.
            littleSnowman(ctx, at: CGPoint(x: foot.x + r * 3.3, y: foot.y), r: r * 0.85, snow: snow, shade: shade,
                          scarf: 0x2f6b45, hat: 0xd8668a, bobble: true)
            littleSnowman(ctx, at: CGPoint(x: foot.x + r * 5.4, y: foot.y - r * 0.05), r: r * 0.55, snow: snow, shade: shade,
                          scarf: 0xe8b440, hat: 0x2f6fb0, bobble: true)
        }
    }

    /// A smaller snowman: two balls and a head, coal eyes, carrot nose,
    /// scarf and a knitted hat.
    private static func littleSnowman(_ ctx: CGContext, at foot: CGPoint, r: CGFloat, snow: UInt32, shade: UInt32,
                                      scarf: UInt32, hat: UInt32, bobble: Bool) {
        AdventPaint.oval(ctx, foot.x + r * 0.35, foot.y - r * 0.05, r * 2.4, r * 0.45, shade, alpha: 0.5)
        for (radius, height) in [(r, r), (r * 0.72, r * 2.4), (r * 0.5, r * 3.5)] as [(CGFloat, CGFloat)] {
            let centre = CGPoint(x: foot.x, y: foot.y + height)
            let ball = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(snow), AdventPaint.color(shade)] as CFArray, locations: [0.35, 1])!
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
            ctx.clip()
            ctx.drawRadialGradient(ball, startCenter: CGPoint(x: centre.x - radius * 0.35, y: centre.y + radius * 0.35),
                                   startRadius: 0, endCenter: centre, endRadius: radius * 1.15, options: [.drawsAfterEndLocation])
            ctx.restoreGState()
        }
        let head = CGPoint(x: foot.x, y: foot.y + r * 3.5)
        for side: CGFloat in [-1, 1] { AdventPaint.oval(ctx, head.x + side * r * 0.17, head.y + r * 0.1, r * 0.09, r * 0.09, 0x1e1a18) }
        AdventPaint.stroke(ctx, [CGPoint(x: head.x, y: head.y - r * 0.05), CGPoint(x: head.x + r * 0.42, y: head.y - r * 0.1)], 0xe8822e, max(0.6, r * 0.12))
        AdventPaint.box(ctx, CGRect(x: head.x - r * 0.48, y: head.y - r * 0.55, width: r * 0.96, height: r * 0.18), r * 0.08, scarf)
        AdventPaint.stroke(ctx, [CGPoint(x: head.x + r * 0.2, y: head.y - r * 0.5), CGPoint(x: head.x + r * 0.32, y: head.y - r * 0.95)], scarf, max(0.6, r * 0.14))
        let cap = CGMutablePath()
        cap.move(to: CGPoint(x: head.x - r * 0.46, y: head.y + r * 0.22))
        cap.addQuadCurve(to: CGPoint(x: head.x + r * 0.46, y: head.y + r * 0.22), control: CGPoint(x: head.x, y: head.y + r * 0.95))
        cap.closeSubpath()
        ctx.setFillColor(AdventPaint.color(hat)); ctx.addPath(cap); ctx.fillPath()
        AdventPaint.box(ctx, CGRect(x: head.x - r * 0.48, y: head.y + r * 0.16, width: r * 0.96, height: r * 0.14), r * 0.05, 0xf4efe6)
        if bobble { AdventPaint.oval(ctx, head.x, head.y + r * 0.66, r * 0.22, r * 0.22, 0xf4efe6) }
        for button in 0..<2 { AdventPaint.oval(ctx, foot.x, foot.y + r * (2.0 + CGFloat(button) * 0.32), r * 0.09, r * 0.09, 0x1e1a18) }
    }

    /// Sledge runs and footpaths pressed into the snow below the village.
    private static func drawTracks(_ layout: AdventLayout, skip: CGRect?, sky: AdventSky, in ctx: CGContext) {
        let bounds = layout.bounds
        let groove = blend(0x9fb6cb, sky.horizon, 0.2)
        ctx.setLineCap(.round)
        for track in 0..<3 {
            let startX = bounds.minX + bounds.width * (0.08 + CGFloat(track) * 0.31)
            let baseY = bounds.minY + bounds.height * (0.055 + CGFloat(track % 2) * 0.025)
            let run = bounds.width * 0.26
            // No sledge run straight across the skating pond.
            if let skip, skip.insetBy(dx: -bounds.width * 0.02, dy: -bounds.height * 0.03)
                .intersects(CGRect(x: startX, y: baseY - bounds.height * 0.04, width: run, height: bounds.height * 0.08)) {
                continue
            }
            for rail: CGFloat in [-1, 1] {
                ctx.setStrokeColor(AdventPaint.color(groove, 0.55))
                ctx.setLineWidth(max(0.8, bounds.height * 0.0016))
                ctx.move(to: CGPoint(x: startX, y: baseY + rail * bounds.height * 0.004))
                ctx.addCurve(to: CGPoint(x: startX + run, y: baseY - bounds.height * 0.02 + rail * bounds.height * 0.004),
                             control1: CGPoint(x: startX + run * 0.3, y: baseY + bounds.height * 0.03),
                             control2: CGPoint(x: startX + run * 0.7, y: baseY - bounds.height * 0.04))
                ctx.strokePath()
            }
        }
    }

    /// The village fountain beside the church: a timber trough, a spout and
    /// the icicle that grows from it every winter.
    private static func drawFountain(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        guard let church = layout.chalets.first(where: { $0.kind == .church }) else { return }
        let w = church.base.width * 0.9
        let x = church.base.maxX + w * 0.9
        let y = church.base.minY
        let wood = blend(0x7a5639, sky.horizon, 0.15)
        let woodDark = blend(wood, 0x241a16, 0.4)
        let stone = blend(0x9a9289, sky.horizon, 0.2)
        let snow = multiply(blend(0xeef5fa, sky.alpenglow, sky.alpenglowStrength * 0.22), sky.valleyLight)
        // A hollowed larch trunk on two stone blocks.
        for side: CGFloat in [-1, 1] {
            AdventPaint.box(ctx, CGRect(x: x + side * w * 0.32 - w * 0.08, y: y, width: w * 0.16, height: w * 0.12),
                            0.3, stone)
        }
        let trough = CGRect(x: x - w * 0.5, y: y + w * 0.10, width: w, height: w * 0.26)
        let barrel = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                colors: [AdventPaint.color(woodDark), AdventPaint.color(wood),
                                         AdventPaint.color(blend(wood, 0xe8d2b4, 0.25))] as CFArray,
                                locations: [0, 0.6, 1])!
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: trough, cornerWidth: trough.height * 0.45, cornerHeight: trough.height * 0.45,
                           transform: nil))
        ctx.clip()
        ctx.drawLinearGradient(barrel, start: CGPoint(x: 0, y: trough.minY), end: CGPoint(x: 0, y: trough.maxY),
                               options: [])
        ctx.restoreGState()
        // End grain and iron hoops.
        AdventPaint.oval(ctx, trough.minX + trough.height * 0.25, trough.midY, trough.height * 0.45,
                         trough.height * 0.9, blend(wood, 0xd9b98f, 0.45))
        for hoop: CGFloat in [0.28, 0.72] {
            AdventPaint.box(ctx, CGRect(x: trough.minX + trough.width * hoop - w * 0.015, y: trough.minY,
                                        width: w * 0.03, height: trough.height), 0, 0x3a3a40, alpha: 0.8)
        }
        // Seen a little from above, the trunk is open: the far inner wall in
        // shade, frozen water inside it, snow lying on both rims.
        let opening = CGRect(x: trough.minX + w * 0.07, y: trough.maxY - w * 0.10, width: trough.width - w * 0.14, height: w * 0.14)
        AdventPaint.box(ctx, opening, opening.height * 0.5, woodDark)
        AdventPaint.box(ctx, opening.insetBy(dx: w * 0.025, dy: w * 0.025).offsetBy(dx: 0, dy: -w * 0.01), opening.height * 0.35,
                        blend(0xbcd8ea, sky.horizon, 0.2))
        AdventPaint.stroke(ctx, [CGPoint(x: opening.minX + w * 0.1, y: opening.midY - w * 0.01),
                                 CGPoint(x: opening.midX, y: opening.midY - w * 0.005)], 0xffffff, max(0.5, w * 0.012), alpha: 0.7)
        AdventPaint.stroke(ctx, [CGPoint(x: trough.minX + w * 0.04, y: opening.maxY + w * 0.005),
                                 CGPoint(x: trough.maxX - w * 0.04, y: opening.maxY + w * 0.005)], snow, max(1, w * 0.05))
        AdventPaint.stroke(ctx, [CGPoint(x: trough.minX + w * 0.06, y: opening.minY - w * 0.005),
                                 CGPoint(x: trough.maxX - w * 0.10, y: opening.minY - w * 0.005)], snow, max(0.8, w * 0.03), alpha: 0.85)
        // The stone column with its spout, a capital and a snow hat.
        let column = CGRect(x: x + w * 0.24, y: y + w * 0.1, width: w * 0.16, height: w * 0.95)
        AdventPaint.box(ctx, column, w * 0.02, stone)
        AdventPaint.box(ctx, CGRect(x: column.maxX - column.width * 0.4, y: column.minY, width: column.width * 0.4,
                                    height: column.height), w * 0.02, blend(stone, 0x000000, 0.18))
        AdventPaint.box(ctx, CGRect(x: column.minX - w * 0.04, y: column.maxY, width: column.width + w * 0.08,
                                    height: w * 0.06), w * 0.02, stone)
        AdventPaint.oval(ctx, column.midX, column.maxY + w * 0.09, column.width + w * 0.1, w * 0.09, snow)
        // Ashlar joints and a carved top: the column is built of stone.
        ctx.setStrokeColor(AdventPaint.color(blend(stone, 0x000000, 0.35), 0.6))
        ctx.setLineWidth(max(0.4, w * 0.008))
        for course in 1..<5 {
            let yy = column.minY + column.height * CGFloat(course) / 5
            ctx.move(to: CGPoint(x: column.minX, y: yy)); ctx.addLine(to: CGPoint(x: column.maxX, y: yy))
        }
        ctx.strokePath()
        AdventPaint.box(ctx, CGRect(x: column.minX - w * 0.02, y: column.maxY - w * 0.05, width: column.width + w * 0.04, height: w * 0.03),
                        w * 0.01, blend(stone, 0xffffff, 0.15))
        AdventPaint.box(ctx, CGRect(x: column.minX - w * 0.03, y: column.minY, width: column.width + w * 0.06, height: w * 0.05),
                        w * 0.01, blend(stone, 0x000000, 0.12))
        // Dressed for Christmas: a fir garland wound round the column and
        // a red bow under the capital.
        for turn in 0..<6 {
            let t = (CGFloat(turn) + 0.5) / 6
            let yy = column.minY + column.height * (0.25 + t * 0.6)
            AdventPaint.oval(ctx, column.midX + (turn % 2 == 0 ? -1 : 1) * column.width * 0.25, yy, column.width * 0.75, w * 0.05,
                             blend(0x2f5a3c, sky.horizon, 0.12))
        }
        let bow = CGPoint(x: column.midX, y: column.maxY - w * 0.12)
        AdventPaint.oval(ctx, bow.x - w * 0.04, bow.y, w * 0.07, w * 0.05, 0xc0302a)
        AdventPaint.oval(ctx, bow.x + w * 0.04, bow.y, w * 0.07, w * 0.05, 0xc0302a)
        AdventPaint.stroke(ctx, [bow, CGPoint(x: bow.x - w * 0.03, y: bow.y - w * 0.09)], 0xc0302a, max(0.5, w * 0.02))
        AdventPaint.stroke(ctx, [bow, CGPoint(x: bow.x + w * 0.035, y: bow.y - w * 0.085)], 0xc0302a, max(0.5, w * 0.02))
        AdventPaint.oval(ctx, bow.x, bow.y, w * 0.035, w * 0.035, 0x9e2620)
        let spout = CGPoint(x: column.minX, y: column.maxY - w * 0.28)
        // An iron pipe: dark, with a lit upper edge so it stays readable
        // against the dark fir behind it at night too.
        let pipeEnd = CGPoint(x: spout.x - w * 0.16, y: spout.y - w * 0.02)
        AdventPaint.stroke(ctx, [spout, pipeEnd], blend(0x3a3f47, sky.horizon, 0.1), max(0.8, w * 0.045))
        AdventPaint.stroke(ctx, [CGPoint(x: spout.x, y: spout.y + w * 0.012), CGPoint(x: pipeEnd.x, y: pipeEnd.y + w * 0.012)],
                           multiply(0xc4ccd6, sky.valleyLight), max(0.4, w * 0.014), alpha: 0.8)
        // The spout has frozen into an icicle reaching down to the trough;
        // ice takes the light of the hour like the snow does.
        ctx.setFillColor(AdventPaint.color(multiply(0xdcecf8, sky.valleyLight), 0.92))
        ctx.beginPath()
        ctx.move(to: CGPoint(x: spout.x - w * 0.19, y: spout.y - w * 0.02))
        ctx.addLine(to: CGPoint(x: spout.x - w * 0.15, y: trough.maxY + w * 0.03))
        ctx.addLine(to: CGPoint(x: spout.x - w * 0.11, y: spout.y - w * 0.02))
        ctx.closePath()
        ctx.fillPath()
    }

    /// A Walliser granary on stilts, each post capped with a flat stone disc so
    /// the mice cannot climb in.
    private static func drawStadel(_ chalet: AdventLayout.Chalet, sky: AdventSky, in ctx: CGContext) {
        // A Valais granary: sun-burnt, almost black larch logs on wooden
        // stilts, each topped by a flat round stone that keeps the mice out,
        // a timber sill lying on the stones, log ends crossing at the corners,
        // a small door and a stone-slab roof under thick snow.
        let base = chalet.base
        let w = base.width, h = base.height
        let timber = blend(0x4a3426, sky.horizon, 0.16)
        let timberDark = blend(timber, 0x120c08, 0.35)
        let timberLit = blend(timber, 0xc9a77e, 0.25)
        let stoneTone = blend(0xa3a7ab, sky.horizon, 0.2)
        let snow = multiply(blend(0xeef5fa, sky.alpenglow, sky.alpenglowStrength * 0.22), sky.valleyLight)
        let stilt = h * 0.30
        let detail = w > 20
        // The mouse stones sit between each post and the sill: flat round
        // slabs, wider than the post, a lit top edge and a shadow below,
        // darker than the snow behind so they read as stone.
        let slab = blend(0x7a7f85, sky.horizon, 0.18)
        for post in 0..<4 {
            let x = base.minX + w * (0.12 + CGFloat(post) * 0.25)
            AdventPaint.box(ctx, CGRect(x: x - w * 0.035, y: base.minY, width: w * 0.07, height: stilt * 0.72),
                            0.4, blend(0x4f3a2a, sky.horizon, 0.2))
            let stoneY = base.minY + stilt * 0.77
            AdventPaint.oval(ctx, x, stoneY - h * 0.012, w * 0.20, h * 0.035, blend(slab, 0x1c2026, 0.45), alpha: 0.6)
            AdventPaint.oval(ctx, x, stoneY, w * 0.22, h * 0.05, slab)
            AdventPaint.oval(ctx, x, stoneY + h * 0.012, w * 0.18, h * 0.022, blend(stoneTone, 0xffffff, 0.3))
            AdventPaint.oval(ctx, x, base.minY + h * 0.01, w * 0.14, h * 0.05, snow)
        }
        // The sill beam lying on the stones.
        AdventPaint.box(ctx, CGRect(x: base.minX - w * 0.04, y: base.minY + stilt * 0.84, width: w * 1.08, height: stilt * 0.16),
                        0.4, timberDark)
        let box = CGRect(x: base.minX, y: base.minY + stilt, width: w, height: h - stilt)
        let rows = max(3, Int(box.height / 3.5))
        for row in 0..<rows {
            let y = box.minY + box.height * CGFloat(row) / CGFloat(rows)
            let rowHeight = box.height / CGFloat(rows)
            AdventPaint.box(ctx, CGRect(x: box.minX, y: y, width: w, height: rowHeight * 0.92), rowHeight * 0.4,
                            row % 2 == 0 ? timber : blend(timber, 0x241a16, 0.2))
            if detail {
                AdventPaint.stroke(ctx, [CGPoint(x: box.minX + w * 0.04, y: y + rowHeight * 0.8),
                                         CGPoint(x: box.maxX - w * 0.04, y: y + rowHeight * 0.8)], timberLit, max(0.3, rowHeight * 0.12), alpha: 0.6)
                // Log ends crossing out at both corners.
                for side: CGFloat in [-1, 1] {
                    let x = side < 0 ? box.minX - w * 0.05 : box.maxX + w * 0.05
                    AdventPaint.oval(ctx, x, y + rowHeight * 0.45, w * 0.07, rowHeight * 0.85, blend(timberLit, timber, 0.4))
                }
            }
        }
        if detail {
            // A small plank door with iron hinges.
            let door = CGRect(x: box.midX - w * 0.13, y: box.minY + box.height * 0.08, width: w * 0.26, height: box.height * 0.62)
            AdventPaint.box(ctx, door, w * 0.02, timberDark)
            for hinge: CGFloat in [0.25, 0.75] {
                AdventPaint.stroke(ctx, [CGPoint(x: door.minX, y: door.minY + door.height * hinge),
                                         CGPoint(x: door.minX + door.width * 0.6, y: door.minY + door.height * hinge)],
                                   0x2a2a2e, max(0.3, w * 0.02))
            }
        }
        let eaves = w * 0.22
        let peak = CGPoint(x: base.midX, y: base.maxY + chalet.roof)
        let left = CGPoint(x: base.minX - eaves, y: base.maxY), right = CGPoint(x: base.maxX + eaves, y: base.maxY)
        // Gable of vertical boards under the roof.
        ctx.setFillColor(AdventPaint.color(timberDark))
        ctx.beginPath(); ctx.addLines(between: [CGPoint(x: base.minX, y: base.maxY), peak, CGPoint(x: base.maxX, y: base.maxY)]); ctx.closePath(); ctx.fillPath()
        if detail {
            // The boards' joints, each from the wall plate up to the roof.
            let boards = max(4, Int(w / 4))
            for board in 1..<boards {
                let x = base.minX + w * CGFloat(board) / CGFloat(boards)
                let rise = (1 - abs(x - peak.x) / (w / 2)) * (peak.y - base.maxY)
                guard rise > h * 0.04 else { continue }
                AdventPaint.stroke(ctx, [CGPoint(x: x, y: base.maxY), CGPoint(x: x, y: base.maxY + rise - h * 0.02)],
                                   blend(timberDark, 0x000000, 0.3), max(0.3, w * 0.012))
                AdventPaint.stroke(ctx, [CGPoint(x: x + max(0.3, w * 0.012), y: base.maxY),
                                         CGPoint(x: x + max(0.3, w * 0.012), y: base.maxY + rise - h * 0.03)],
                                   timberLit, max(0.25, w * 0.008), alpha: 0.35)
            }
        }
        // Stone-slab roof, its edge showing under the snow.
        let roof = CGMutablePath()
        roof.addLines(between: [left, peak, right])
        roof.addLine(to: CGPoint(x: right.x, y: right.y - h * 0.05))
        roof.addLine(to: CGPoint(x: peak.x, y: peak.y - h * 0.05))
        roof.addLine(to: CGPoint(x: left.x, y: left.y - h * 0.05))
        roof.closeSubpath()
        ctx.setFillColor(AdventPaint.color(blend(0x6d6f73, sky.horizon, 0.18)))
        ctx.addPath(roof)
        ctx.fillPath()
        // Thick snow lying along both slopes, rounded over the ridge.
        let thick = h * 0.09
        let cap = CGMutablePath()
        cap.move(to: CGPoint(x: left.x - w * 0.02, y: left.y - h * 0.01))
        cap.addLine(to: peak)
        cap.addLine(to: CGPoint(x: right.x + w * 0.02, y: right.y - h * 0.01))
        cap.addQuadCurve(to: CGPoint(x: right.x - w * 0.03, y: right.y + thick * 0.7),
                         control: CGPoint(x: right.x + w * 0.05, y: right.y + thick * 0.4))
        cap.addLine(to: CGPoint(x: peak.x + w * 0.04, y: peak.y + thick * 0.9))
        cap.addQuadCurve(to: CGPoint(x: peak.x - w * 0.04, y: peak.y + thick * 0.9), control: CGPoint(x: peak.x, y: peak.y + thick * 1.2))
        cap.addLine(to: CGPoint(x: left.x + w * 0.03, y: left.y + thick * 0.7))
        cap.addQuadCurve(to: CGPoint(x: left.x - w * 0.02, y: left.y - h * 0.01),
                         control: CGPoint(x: left.x - w * 0.05, y: left.y + thick * 0.4))
        cap.closeSubpath()
        ctx.setFillColor(AdventPaint.color(snow))
        ctx.addPath(cap)
        ctx.fillPath()
        for side: CGFloat in [-1, 1] {
            let edge = side < 0 ? left : right
            AdventPaint.oval(ctx, edge.x + side * w * 0.01, edge.y, w * 0.12, h * 0.05, snow)
        }
    }

    /// The belfry's twin openings with their bells. The backdrop draws them
    /// at rest; on the hour the live layer draws them again over it with
    /// the bells swinging, so nothing in the backdrop has to change.
    static func drawBelfry(_ chalet: AdventLayout.Chalet, sky: AdventSky, swing: CGFloat, swingPhase: CGFloat = 0,
                           in ctx: CGContext) {
        let tower = chalet.base
        let w = tower.width, h = tower.height
        let warm = sky.lampStrength > 0.2
        let detail = w > 22
        let belfry = CGRect(x: tower.minX, y: tower.maxY - h * 0.26, width: w, height: h * 0.26)
        if detail {
            for side: CGFloat in [-1, 1] {
                let cx = tower.midX + side * w * 0.17
                let open = CGRect(x: cx - w * 0.1, y: belfry.minY + h * 0.04, width: w * 0.2, height: h * 0.17)
                let arch = CGMutablePath()
                arch.move(to: CGPoint(x: open.minX, y: open.minY))
                arch.addLine(to: CGPoint(x: open.minX, y: open.maxY - open.width / 2))
                arch.addArc(center: CGPoint(x: open.midX, y: open.maxY - open.width / 2), radius: open.width / 2,
                            startAngle: .pi, endAngle: 0, clockwise: true)
                arch.addLine(to: CGPoint(x: open.maxX, y: open.minY))
                arch.closeSubpath()
                ctx.setFillColor(AdventPaint.color(0x2a2430))
                ctx.addPath(arch)
                ctx.fillPath()
                if warm {
                    // After dark a lamp burns in the belfry: warm light behind
                    // the bells, so they stand out against it.
                    ctx.saveGState()
                    ctx.addPath(arch)
                    ctx.clip()
                    let lamp = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                          colors: [AdventPaint.color(0xffcf86, 0.85 * sky.lampStrength),
                                                   AdventPaint.color(0xb8743a, 0.4 * sky.lampStrength)] as CFArray,
                                          locations: [0, 1])!
                    ctx.drawRadialGradient(lamp, startCenter: CGPoint(x: open.midX, y: open.midY), startRadius: 0,
                                           endCenter: CGPoint(x: open.midX, y: open.midY), endRadius: open.height * 0.7,
                                           options: [.drawsAfterEndLocation])
                    ctx.restoreGState()
                }
                // A bronze bell hangs in each opening, caught by a little light.
                let bell = CGMutablePath()
                let top = CGPoint(x: open.midX, y: open.maxY - open.width * 0.55)
                let bw = open.width * 0.34, bh = open.height * 0.42
                bell.move(to: CGPoint(x: top.x - bw * 0.35, y: top.y))
                bell.addQuadCurve(to: CGPoint(x: top.x + bw * 0.35, y: top.y), control: CGPoint(x: top.x, y: top.y + bw * 0.45))
                bell.addQuadCurve(to: CGPoint(x: top.x + bw, y: top.y - bh), control: CGPoint(x: top.x + bw * 0.45, y: top.y - bh * 0.55))
                bell.addLine(to: CGPoint(x: top.x - bw, y: top.y - bh))
                bell.addQuadCurve(to: CGPoint(x: top.x - bw * 0.35, y: top.y), control: CGPoint(x: top.x - bw * 0.45, y: top.y - bh * 0.55))
                bell.closeSubpath()
                // Swinging on the hour, the two bells a little out of step,
                // each turning about the yoke it hangs from.
                let angle = swing * sin(swingPhase * 2.9 + (side < 0 ? 0 : 1.4))
                ctx.saveGState()
                ctx.translateBy(x: top.x, y: top.y + bw * 0.3)
                ctx.rotate(by: angle)
                ctx.translateBy(x: -top.x, y: -(top.y + bw * 0.3))
                // By day bronze in the shade; at night a dark shape against the lamp.
                ctx.setFillColor(AdventPaint.color(blend(blend(0xb8862e, sky.horizon, 0.2), 0x2a1c12,
                                                         warm ? 0.65 * sky.lampStrength : 0)))
                ctx.addPath(bell)
                ctx.fillPath()
                AdventPaint.stroke(ctx, [CGPoint(x: top.x - bw * 0.5, y: top.y - bh * 0.25), CGPoint(x: top.x - bw * 0.75, y: top.y - bh * 0.9)],
                                   blend(0xf2d48a, sky.horizon, 0.2), max(0.4, open.width * 0.06), alpha: 0.8)
                ctx.restoreGState()
                ctx.setStrokeColor(AdventPaint.color(0x7a6a5c, 0.9))
                ctx.setLineWidth(max(0.4, h * 0.008))
                for slat in 1...3 {
                    let y = open.minY + open.height * CGFloat(slat) / 5
                    ctx.move(to: CGPoint(x: open.minX + 0.5, y: y))
                    ctx.addLine(to: CGPoint(x: open.maxX - 0.5, y: y - h * 0.008))
                }
                ctx.strokePath()
            }
        }
    }

    /// On the full hour the bells ring for a quarter of a minute, swinging
    /// wide at first and slowly coming to rest.
    /// Set when door 8 is opened, so the bells ring there and then.
    static var bellsCue: Date?

    private static func drawChurchBells(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        guard let church = layout.chalets.first(where: { $0.kind == .church }) else { return }
        var t: CGFloat?
        if let cue = bellsCue, Date().timeIntervalSince(cue) < 16 {
            t = CGFloat(Date().timeIntervalSince(cue))
        } else {
            let parts = Calendar.current.dateComponents([.minute, .second, .nanosecond], from: Date())
            if parts.minute == 0, let second = parts.second, second < 16 {
                t = CGFloat(second) + CGFloat(parts.nanosecond ?? 0) / 1_000_000_000
            }
        }
        guard let t else { return }
        drawBelfry(church, sky: sky, swing: 0.5 * (1 - t / 16), swingPhase: t, in: ctx)
        // Rings of sound spreading from the belfry while the bells swing.
        let belfry = CGPoint(x: church.base.midX, y: church.base.maxY - church.base.height * 0.13)
        for k in 0..<3 {
            let age = (t * 0.9 + CGFloat(k) / 3).truncatingRemainder(dividingBy: 1)
            let r = church.base.width * (0.6 + age * 1.6)
            ctx.setStrokeColor(AdventPaint.color(0xffe6a8, 0.5 * (1 - age) * (1 - t / 16)))
            ctx.setLineWidth(max(0.6, church.base.width * 0.03))
            ctx.addArc(center: belfry, radius: r, startAngle: .pi * 0.15, endAngle: .pi * 0.85, clockwise: false)
            ctx.strokePath()
        }
    }

    private static func drawChurch(_ chalet: AdventLayout.Chalet, sky: AdventSky, in ctx: CGContext) {
        let tower = chalet.base
        let w = tower.width, h = tower.height
        let plaster = multiply(blend(0xe6e0d4, sky.horizon, 0.14), sky.valleyLight)
        let plasterShade = multiply(blend(0xb9b3ab, sky.horizon, 0.22), sky.valleyLight)
        let stone = blend(0x9a9289, sky.horizon, 0.2)
        let roofDark = blend(0x3e3540, sky.horizon, 0.1)
        let roofLit = blend(0x5d5160, sky.horizon, 0.1)
        let snow = multiply(blend(0xeef5fa, sky.alpenglow, sky.alpenglowStrength * 0.22), sky.valleyLight)
        let warm = sky.lampStrength > 0.2
        let detail = w > 22

        // The nave stands behind the tower to the left: a long white hall
        // under a steep roof, its round-arched windows lit in the evening.
        let nave = CGRect(x: tower.minX - w * 1.05, y: tower.minY, width: w * 1.2, height: h * 0.58)
        AdventPaint.box(ctx, nave, 0.6, plaster)
        let naveRoof = CGMutablePath()
        let ridge = nave.maxY + h * 0.42
        naveRoof.move(to: CGPoint(x: nave.minX - w * 0.12, y: nave.maxY - h * 0.02))
        naveRoof.addLine(to: CGPoint(x: nave.minX + w * 0.18, y: ridge))
        naveRoof.addLine(to: CGPoint(x: nave.maxX, y: ridge))
        naveRoof.addLine(to: CGPoint(x: nave.maxX, y: nave.maxY - h * 0.02))
        naveRoof.closeSubpath()
        ctx.setFillColor(AdventPaint.color(roofDark))
        ctx.addPath(naveRoof)
        ctx.fillPath()
        // Snow lies thick on the long slope.
        let naveSnow = CGMutablePath()
        naveSnow.move(to: CGPoint(x: nave.minX - w * 0.14, y: nave.maxY - h * 0.02))
        naveSnow.addLine(to: CGPoint(x: nave.minX + w * 0.16, y: ridge + h * 0.03))
        naveSnow.addLine(to: CGPoint(x: nave.maxX, y: ridge + h * 0.03))
        naveSnow.addLine(to: CGPoint(x: nave.maxX, y: ridge - h * 0.30))
        naveSnow.addQuadCurve(to: CGPoint(x: nave.minX - w * 0.14, y: nave.maxY - h * 0.02),
                              control: CGPoint(x: nave.minX + w * 0.4, y: nave.maxY + h * 0.02))
        naveSnow.closeSubpath()
        ctx.setFillColor(AdventPaint.color(snow))
        ctx.addPath(naveSnow)
        ctx.fillPath()
        // Eave shadow on the wall.
        AdventPaint.box(ctx, CGRect(x: nave.minX, y: nave.maxY - h * 0.06, width: nave.width, height: h * 0.06),
                        0, 0x2a2430, alpha: 0.25)
        if detail {
            for slot in 0..<3 {
                let cx = nave.minX + nave.width * (0.20 + CGFloat(slot) * 0.27)
                let window = CGRect(x: cx - w * 0.08, y: nave.minY + h * 0.18, width: w * 0.16, height: h * 0.28)
                let arch = CGMutablePath()
                arch.move(to: CGPoint(x: window.minX, y: window.minY))
                arch.addLine(to: CGPoint(x: window.minX, y: window.maxY - window.width / 2))
                arch.addArc(center: CGPoint(x: window.midX, y: window.maxY - window.width / 2),
                            radius: window.width / 2, startAngle: .pi, endAngle: 0, clockwise: true)
                arch.addLine(to: CGPoint(x: window.maxX, y: window.minY))
                arch.closeSubpath()
                ctx.setStrokeColor(AdventPaint.color(stone))
                ctx.setLineWidth(max(0.6, w * 0.03))
                ctx.addPath(arch)
                ctx.strokePath()
                ctx.setFillColor(AdventPaint.color(warm ? 0xffcf86 : 0x56677a))
                ctx.addPath(arch)
                ctx.fillPath()
                if warm {
                    AdventPaint.glow(ctx, at: CGPoint(x: window.midX, y: window.midY), radius: w * 0.5,
                                     0xffc27a, 0.35 * sky.lampStrength)
                }
            }
        }

        // The tower: plaster, shaded on the side away from the light,
        // with dressed stone at the corners.
        AdventPaint.box(ctx, tower, 0.4, plaster)
        AdventPaint.box(ctx, CGRect(x: tower.maxX - w * 0.32, y: tower.minY, width: w * 0.32, height: h),
                        0.4, plasterShade)
        if detail {
            let blocks = 9
            for block in 0..<blocks {
                let y = tower.minY + h * CGFloat(block) / CGFloat(blocks)
                let long = block % 2 == 0
                AdventPaint.box(ctx, CGRect(x: tower.minX, y: y + h * 0.006, width: w * (long ? 0.16 : 0.10),
                                            height: h / CGFloat(blocks) - h * 0.012), 0.3, stone)
                AdventPaint.box(ctx, CGRect(x: tower.maxX - w * (long ? 0.16 : 0.10), y: y + h * 0.006,
                                            width: w * (long ? 0.16 : 0.10),
                                            height: h / CGFloat(blocks) - h * 0.012), 0.3, blend(stone, 0x000000, 0.15))
            }
        }
        // Belfry: twin arched openings with louvres, dark inside.
        let belfry = CGRect(x: tower.minX, y: tower.maxY - h * 0.26, width: w, height: h * 0.26)
        drawBelfry(chalet, sky: sky, swing: 0, in: ctx)
        // Cornice under the belfry and at the eaves.
        for level in [belfry.minY, tower.maxY - h * 0.02] {
            AdventPaint.box(ctx, CGRect(x: tower.minX - w * 0.05, y: level - h * 0.012, width: w * 1.1, height: h * 0.03),
                            0.3, stone)
        }
        // Clock face below the belfry.
        if detail {
            let clock = CGPoint(x: tower.midX, y: belfry.minY - h * 0.11)
            let r = w * 0.17
            AdventPaint.oval(ctx, clock.x, clock.y, r * 2.4, r * 2.4, 0x3b3340)
            AdventPaint.oval(ctx, clock.x, clock.y, r * 2.24, r * 2.24, 0xc9a24e)
            AdventPaint.oval(ctx, clock.x, clock.y, r * 2.0, r * 2.0, 0xf3ead8)
            // Twelve hour marks, the quarters heavier.
            ctx.setStrokeColor(AdventPaint.color(0x3b3340, 0.9))
            ctx.setLineCap(.butt)
            for mark in 0..<12 {
                let a = CGFloat(mark) / 12 * .pi * 2
                let quarter = mark % 3 == 0
                ctx.setLineWidth(max(0.4, r * (quarter ? 0.12 : 0.06)))
                ctx.move(to: CGPoint(x: clock.x + sin(a) * r * (quarter ? 0.68 : 0.78), y: clock.y + cos(a) * r * (quarter ? 0.68 : 0.78)))
                ctx.addLine(to: CGPoint(x: clock.x + sin(a) * r * 0.92, y: clock.y + cos(a) * r * 0.92))
                ctx.strokePath()
            }
            // The hands tell the real time on this Mac; the backdrop is drawn
            // again every minute.
            let minutes = CGFloat(sky.stamp)
            let hourAngle = (minutes / 60).truncatingRemainder(dividingBy: 12) / 12 * .pi * 2
            let minuteAngle = minutes.truncatingRemainder(dividingBy: 60) / 60 * .pi * 2
            ctx.setLineCap(.round)
            ctx.setStrokeColor(AdventPaint.color(0x2a2430, 0.95))
            ctx.setLineWidth(max(0.5, r * 0.15))
            ctx.move(to: clock); ctx.addLine(to: CGPoint(x: clock.x + sin(hourAngle) * r * 0.5, y: clock.y + cos(hourAngle) * r * 0.5))
            ctx.strokePath()
            ctx.setLineWidth(max(0.4, r * 0.09))
            ctx.move(to: clock); ctx.addLine(to: CGPoint(x: clock.x + sin(minuteAngle) * r * 0.78, y: clock.y + cos(minuteAngle) * r * 0.78))
            ctx.strokePath()
            AdventPaint.oval(ctx, clock.x, clock.y, r * 0.16, r * 0.16, 0xc9a24e)
            if warm { AdventPaint.glow(ctx, at: clock, radius: r * 2.2, 0xfff0c8, 0.25 * sky.lampStrength) }
        }
        // Arched portal with a stone surround.
        let portal = CGRect(x: tower.midX - w * 0.15, y: tower.minY, width: w * 0.30, height: h * 0.30)
        let door = CGMutablePath()
        door.move(to: CGPoint(x: portal.minX, y: portal.minY))
        door.addLine(to: CGPoint(x: portal.minX, y: portal.maxY - portal.width / 2))
        door.addArc(center: CGPoint(x: portal.midX, y: portal.maxY - portal.width / 2), radius: portal.width / 2,
                    startAngle: .pi, endAngle: 0, clockwise: true)
        door.addLine(to: CGPoint(x: portal.maxX, y: portal.minY))
        door.closeSubpath()
        ctx.setStrokeColor(AdventPaint.color(stone))
        ctx.setLineWidth(max(0.8, w * 0.06))
        ctx.addPath(door)
        ctx.strokePath()
        ctx.setFillColor(AdventPaint.color(blend(0x5a3a28, sky.horizon, 0.1)))
        ctx.addPath(door)
        ctx.fillPath()
        if detail {
            AdventPaint.stroke(ctx, [CGPoint(x: portal.midX, y: portal.minY),
                                     CGPoint(x: portal.midX, y: portal.maxY - portal.width * 0.1)],
                               0x3a2618, max(0.4, w * 0.015))
            // An Advent wreath on the door.
            AdventPaint.oval(ctx, portal.midX, portal.minY + portal.height * 0.55, w * 0.14, w * 0.14, 0x2d6a46)
            AdventPaint.oval(ctx, portal.midX, portal.minY + portal.height * 0.55, w * 0.07, w * 0.07,
                             blend(0x5a3a28, sky.horizon, 0.1))
        }

        // Spire: an octagonal helm seen as two faces, lit and shaded, with
        // shingle courses and snow on the lit edge.
        let peak = CGPoint(x: tower.midX, y: tower.maxY + chalet.roof * 1.5)
        let eaveL = CGPoint(x: tower.minX - w * 0.06, y: tower.maxY)
        let eaveR = CGPoint(x: tower.maxX + w * 0.06, y: tower.maxY)
        let mid = CGPoint(x: tower.midX + w * 0.08, y: tower.maxY)
        ctx.setFillColor(AdventPaint.color(roofLit))
        ctx.beginPath(); ctx.addLines(between: [eaveL, peak, mid]); ctx.closePath(); ctx.fillPath()
        ctx.setFillColor(AdventPaint.color(roofDark))
        ctx.beginPath(); ctx.addLines(between: [mid, peak, eaveR]); ctx.closePath(); ctx.fillPath()
        // Fish-scale shingles in courses up the helm, snow caught on some of
        // them on the lit side.
        let helm = CGMutablePath()
        helm.addLines(between: [eaveL, peak, eaveR])
        helm.closeSubpath()
        ctx.saveGState()
        ctx.addPath(helm)
        ctx.clip()
        let courses = detail ? 14 : 8
        let scale = max(1.2, (eaveR.x - eaveL.x) / 9)
        for course in 0..<courses {
            let t = (CGFloat(course) + 0.5) / CGFloat(courses)
            let y = tower.maxY + (peak.y - tower.maxY) * t
            let left = eaveL.x + (peak.x - eaveL.x) * t
            let right = eaveR.x + (peak.x - eaveR.x) * t
            let size = scale * (1 - t * 0.6)
            var x = left + (course % 2 == 0 ? 0 : size * 0.5)
            var k = 0
            while x < right {
                ctx.setStrokeColor(AdventPaint.color(0x241e28, 0.38))
                ctx.setLineWidth(max(0.4, size * 0.12))
                ctx.beginPath()
                ctx.addArc(center: CGPoint(x: x, y: y), radius: size * 0.5, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
                ctx.strokePath()
                if x < mid.x - size * 0.5 && AdventLayout.noise(course * 13 + k, 990) > 0.78 {
                    ctx.setStrokeColor(AdventPaint.color(snow, 0.8))
                    ctx.setLineWidth(max(0.5, size * 0.2))
                    ctx.move(to: CGPoint(x: x - size * 0.45, y: y + size * 0.02))
                    ctx.addLine(to: CGPoint(x: x + size * 0.35, y: y - size * 0.03))
                    ctx.strokePath()
                }
                x += size
                k += 1
            }
        }
        ctx.restoreGState()
        AdventPaint.stroke(ctx, [eaveL, peak], snow, max(0.8, w * 0.06))
        AdventPaint.stroke(ctx, [CGPoint(x: eaveL.x - w * 0.02, y: eaveL.y), CGPoint(x: eaveR.x + w * 0.02, y: eaveR.y)],
                           snow, max(1, w * 0.07))
        // A little gilded ball and cross on top; the Advent star sits above it.
        AdventPaint.oval(ctx, peak.x, peak.y - w * 0.02, w * 0.07, w * 0.07, 0xd9a94a)
        AdventPaint.stroke(ctx, [CGPoint(x: peak.x, y: peak.y + w * 0.02), CGPoint(x: peak.x, y: peak.y + w * 0.14)],
                           0xc9963c, max(0.6, w * 0.022))
        AdventPaint.stroke(ctx, [CGPoint(x: peak.x - w * 0.035, y: peak.y + w * 0.10), CGPoint(x: peak.x + w * 0.035, y: peak.y + w * 0.10)],
                           0xc9963c, max(0.6, w * 0.022))
    }

    /// The banner cloud that streams off the summit on a windy day.
    private static func drawBanner(_ layout: AdventLayout, time: CGFloat, sky: AdventSky, in ctx: CGContext) {
        guard layout.matterhorn.count > layout.matterhornSummit else { return }
        let summit = layout.matterhorn[layout.matterhornSummit]
        let span = layout.bounds.width * 0.11
        for index in 0..<4 {
            let drift = (time * 0.055 + CGFloat(index) * 0.25).truncatingRemainder(dividingBy: 1)
            let x = summit.x + span * (0.12 + drift * 1.5)
            let y = summit.y + sin(drift * 2.4 + CGFloat(index)) * span * 0.10 - span * 0.04
            let radius = span * (0.10 + drift * 0.26)
            ctx.saveGState()
            ctx.translateBy(x: x, y: y)
            ctx.scaleBy(x: 2.4, y: 1)
            AdventPaint.glow(ctx, at: .zero, radius: radius * 1.2,
                             sky.daylight > 0.4 ? 0xffffff : 0xb9c6da, (1 - drift) * 0.42)
            ctx.restoreGState()
        }
    }

    /// Wood smoke from every chimney: soft puffs that rise, swell, fade and
    /// all lean the same way in the valley breeze. Only houses that have a
    /// chimney smoke; granaries and the far little huts do not.
    private static func drawSmoke(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky,
                                  in ctx: CGContext, time: CGFloat) {
        let rise = layout.bounds.height * 0.075
        let wind = layout.bounds.height * 0.05 * (0.8 + 0.2 * sin(time * 0.05))
        // Wood smoke reads against both: a soft grey-brown core that shows
        // over the white valley by day, and a pale rim that glows against
        // the dark at night.
        let core = blend(0x6f7482, 0x8e97aa, 1 - sky.daylight)
        let rim = blend(0xe9edf3, 0xb9c3d4, 1 - sky.daylight)
        // The smoke is drawn over the finished backdrop, so a nearer house
        // standing in front of a chimney has to be cut back out of it: its
        // wall, gable and roof with the snow lying on it.
        func outline(_ house: AdventLayout.Chalet) -> CGPath {
            let b = house.base, w = b.width, h = b.height
            let eaves = w * 0.36, pillow = max(1.4, w * 0.075) * 1.1
            let path = CGMutablePath()
            path.move(to: CGPoint(x: b.minX, y: b.minY))
            path.addLine(to: CGPoint(x: b.maxX, y: b.minY))
            path.addLine(to: CGPoint(x: b.maxX, y: b.maxY - h * 0.05))
            path.addLine(to: CGPoint(x: b.maxX + eaves, y: b.maxY - h * 0.05 + pillow * 0.4))
            path.addLine(to: CGPoint(x: b.midX, y: b.maxY + house.roof + pillow))
            path.addLine(to: CGPoint(x: b.minX - eaves, y: b.maxY - h * 0.05 + pillow * 0.4))
            path.addLine(to: CGPoint(x: b.minX, y: b.maxY - h * 0.05))
            path.closeSubpath()
            return path
        }
        for (index, chalet) in layout.chalets.enumerated()
        where chalet.kind == .chalet && chalet.base.width > 30 {
            // Before the fifth door only some houses have the stove going.
            if !season.has(.smoke) && index % 5 >= 2 { continue }
            let w = chalet.base.width
            let origin = CGPoint(x: chalet.base.minX + w * 0.72, y: chalet.base.maxY + chalet.roof * 1.16)
            let reach = CGRect(x: origin.x - w * 0.4, y: origin.y - w * 0.1, width: wind + w * 0.9, height: rise + w * 0.5)
            // Only the outlines that can reach this chimney's smoke at all;
            // and below only for the puffs that overlap one, within the
            // puff's own small square: a clip path covering the whole
            // screen had to be rasterised for every puff and cost more than
            // the smoke itself.
            let occluders = layout.chalets.compactMap { house -> CGPath? in
                guard house.depth > chalet.depth else { return nil }
                let shape = outline(house)
                return shape.boundingBox.intersects(reach) ? shape : nil
            }
            let puffs = 6
            for puff in 0..<puffs {
                let life = (time * 0.11 + CGFloat(puff) / CGFloat(puffs) + CGFloat(index) * 0.37)
                    .truncatingRemainder(dividingBy: 1)
                let fadeIn = min(1, life * 8)
                let alpha = pow(1 - life, 1.4) * 0.5 * fadeIn
                guard alpha > 0.01 else { continue }
                let x = origin.x + wind * life * life + sin(life * 5 + CGFloat(index)) * w * 0.03
                let y = origin.y + rise * life
                let radius = w * (0.06 + life * 0.22)
                ctx.saveGState()
                let square = CGRect(x: x - radius * 1.7, y: y - radius * 1.2, width: radius * 3.4, height: radius * 2.6)
                for shape in occluders where shape.boundingBox.intersects(square) {
                    let outside = CGMutablePath()
                    outside.addRect(square)
                    outside.addPath(shape)
                    ctx.addPath(outside)
                    ctx.clip(using: .evenOdd)
                }
                // Puffs are a quarter wider than high; the stamps carry that
                // stretch themselves, so they are drawn unscaled.
                AdventPaint.glowStamp(ctx, at: CGPoint(x: x - radius * 0.15, y: y + radius * 0.12), radius: radius * 1.15,
                                      rim, min(0.9, alpha * 1.3), stretch: 1.25)
                AdventPaint.glowStamp(ctx, at: CGPoint(x: x, y: y), radius: radius * 0.85,
                                      core, min(0.9, alpha * (1.1 + 0.5 * sky.daylight)), stretch: 1.25)
                ctx.restoreGState()
            }
        }
    }

    /// A gondola lift beside every ski run: a rope from a valley station
    /// up over steel towers to a mountain station near the top of the run.
    struct Gondola {
        var rope: [CGPoint]
        var towers: [(foot: CGPoint, top: CGPoint)]
        var bottom: CGPoint
        var top: CGPoint
    }

    static func gondolas(_ layout: AdventLayout) -> [Gondola] {
        guard layout.ridges.count == 3 else { return [] }
        let bounds = layout.bounds
        let w = bounds.width, h = bounds.height
        let station = h * 0.0125
        let near = layout.ridges[2]
        return layout.pistes.enumerated().compactMap { index, run in
            guard let first = run.first, let last = run.last else { return nil }
            // The lift climbs the face beside the run, slanting away from it
            // on the side the run does not swing to, so they never cross.
            // The mountain station stands right where the run starts, so the
            // skiers step out of the cabins onto the piste; the valley station
            // stands on the slope just above the near range, where it shows.
            let side: CGFloat = index == 0 ? 1 : -1
            let top = CGPoint(x: first.x + side * w * 0.016, y: first.y - h * 0.010)
            let bottomX = top.x + side * w * 0.11
            let bottom = CGPoint(x: bottomX, y: max(last.y, AdventLayout.height(of: near, at: bottomX) + h * 0.014))
            let start = CGPoint(x: bottom.x, y: bottom.y + station)
            let end = CGPoint(x: top.x, y: top.y + station)
            var rope = [start]
            var towers: [(foot: CGPoint, top: CGPoint)] = []
            for k in 1...4 {
                let t = CGFloat(k) / 5
                let head = CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
                // Towers stand on the slope under the rope.
                towers.append((CGPoint(x: head.x, y: head.y - h * 0.030), head))
                rope.append(head)
            }
            rope.append(end)
            return Gondola(rope: rope, towers: towers, bottom: bottom, top: top)
        }
    }

    /// A point a fraction of the way along a polyline, by length.
    static func alongRope(_ rope: [CGPoint], _ t: CGFloat) -> CGPoint {
        guard rope.count > 1 else { return rope.first ?? .zero }
        var lengths: [CGFloat] = []
        for i in 1..<rope.count { lengths.append(hypot(rope[i].x - rope[i - 1].x, rope[i].y - rope[i - 1].y)) }
        var target = max(0, min(1, t)) * lengths.reduce(0, +)
        for (i, length) in lengths.enumerated() {
            if target <= length || i == lengths.count - 1 {
                let u = length > 0 ? min(1, target / length) : 0
                return CGPoint(x: rope[i].x + (rope[i + 1].x - rope[i].x) * u, y: rope[i].y + (rope[i + 1].y - rope[i].y) * u)
            }
            target -= length
        }
        return rope.last!
    }

    /// Towers, ropes and stations are still; they go into the backdrop.
    private static func drawGondolas(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let h = layout.bounds.height
        let unit = h * 0.02
        let steel = blend(0x6e7784, sky.horizon, 0.25)
        let steelDark = blend(0x464d58, sky.horizon, 0.25)
        let snow = multiply(0xeef5fa, sky.valleyLight)
        let light = sky.lampStrength > 0.3
        for way in gondolas(layout) {
            // Steel towers: two tapering legs braced across, a crossarm with
            // the rope wheels on top, snow on the arm.
            for tower in way.towers {
                let height = tower.top.y - tower.foot.y
                let spread = unit * 0.22
                let legs = [CGPoint(x: tower.foot.x - spread, y: tower.foot.y), CGPoint(x: tower.foot.x + spread, y: tower.foot.y)]
                let head = CGPoint(x: tower.top.x, y: tower.top.y - unit * 0.12)
                AdventPaint.stroke(ctx, [legs[0], CGPoint(x: head.x - unit * 0.05, y: head.y)], steelDark, max(0.5, unit * 0.06))
                AdventPaint.stroke(ctx, [legs[1], CGPoint(x: head.x + unit * 0.05, y: head.y)], steel, max(0.5, unit * 0.06))
                let braces = max(2, Int(height / (unit * 0.45)))
                ctx.setStrokeColor(AdventPaint.color(steel, 0.8))
                ctx.setLineWidth(max(0.3, unit * 0.025))
                for b in 0..<braces {
                    let t0 = CGFloat(b) / CGFloat(braces), t1 = CGFloat(b + 1) / CGFloat(braces)
                    func leg(_ side: Int, _ t: CGFloat) -> CGPoint {
                        let foot = legs[side]
                        let topX = head.x + (side == 0 ? -unit * 0.05 : unit * 0.05)
                        return CGPoint(x: foot.x + (topX - foot.x) * t, y: foot.y + (head.y - foot.y) * t)
                    }
                    ctx.move(to: leg(0, t0)); ctx.addLine(to: leg(1, t1))
                    ctx.move(to: leg(1, t0)); ctx.addLine(to: leg(0, t1))
                }
                ctx.strokePath()
                AdventPaint.box(ctx, CGRect(x: head.x - unit * 0.32, y: head.y, width: unit * 0.64, height: unit * 0.08), unit * 0.02, steelDark)
                AdventPaint.box(ctx, CGRect(x: head.x - unit * 0.3, y: head.y + unit * 0.07, width: unit * 0.6, height: unit * 0.04), unit * 0.02, snow)
                for side: CGFloat in [-1, 1] {
                    AdventPaint.oval(ctx, head.x + side * unit * 0.24, head.y + unit * 0.12, unit * 0.1, unit * 0.1, steelDark)
                }
                // A little snow drift at the foot.
                AdventPaint.oval(ctx, tower.foot.x, tower.foot.y + unit * 0.02, unit * 0.7, unit * 0.14, snow)
            }
            // Two ropes: the cabins go up on one and come down on the other.
            for offset: CGFloat in [0, -unit * 0.16] {
                let line = way.rope.map { CGPoint(x: $0.x, y: $0.y + offset) }
                AdventPaint.stroke(ctx, line, 0x2a313c, max(0.4, unit * 0.035), alpha: 0.85)
            }
            // The stations: an open hall under a wide cantilevered roof, the
            // big bull wheel lying flat inside it, a cabin waiting at the
            // platform, a control room with a lit window at the back.
            for (point, wide) in [(way.bottom, unit * 1.0), (way.top, unit * 1.1)] {
                let hall = CGRect(x: point.x - wide / 2, y: point.y, width: wide, height: unit * 0.72)
                // A level terrace of packed snow and a concrete platform.
                AdventPaint.oval(ctx, hall.midX, hall.minY + unit * 0.02, wide * 1.8, unit * 0.34, snow)
                AdventPaint.box(ctx, CGRect(x: hall.minX - unit * 0.06, y: hall.minY - unit * 0.06, width: wide + unit * 0.12, height: unit * 0.1),
                                unit * 0.03, multiply(0x9aa2ab, sky.valleyLight))
                // Back wall in shade and the control room on one side; after
                // dark the hall is flooded with warm light for boarding.
                AdventPaint.box(ctx, CGRect(x: hall.minX, y: hall.minY, width: hall.width, height: hall.height * 0.92), unit * 0.04,
                                light ? blend(multiply(0x5d636c, sky.valleyLight), 0xffc98a, 0.45 * sky.lampStrength)
                                      : multiply(0x5d636c, sky.valleyLight))
                if light {
                    AdventPaint.glow(ctx, at: CGPoint(x: hall.midX, y: hall.minY + hall.height * 0.5), radius: unit * 1.8,
                                     0xffc27a, 0.38 * sky.lampStrength)
                    // Light spilling onto the snow in front of the hall.
                    AdventPaint.pool(ctx, at: CGPoint(x: hall.midX, y: hall.minY - unit * 0.02), width: wide * 2.0, flat: 0.16,
                                     0xffd9a0, 0.45 * sky.lampStrength)
                }
                let control = CGRect(x: hall.maxX - hall.width * 0.32, y: hall.minY, width: hall.width * 0.32, height: hall.height * 0.92)
                AdventPaint.box(ctx, control, unit * 0.04, multiply(0x9aa0a8, sky.valleyLight))
                AdventPaint.box(ctx, CGRect(x: control.minX + control.width * 0.18, y: control.minY + control.height * 0.42,
                                            width: control.width * 0.64, height: control.height * 0.3), unit * 0.02,
                                light ? 0xffd08a : 0x7d93a8)
                if light {
                    AdventPaint.glow(ctx, at: CGPoint(x: control.midX, y: control.midY), radius: unit * 1.0, 0xffc27a, 0.3 * sky.lampStrength)
                }
                // The bull wheel, flat, seen from a little above.
                let wheel = CGPoint(x: hall.minX + hall.width * 0.36, y: hall.minY + hall.height * 0.62)
                ctx.setStrokeColor(AdventPaint.color(0xb8c0ca))
                ctx.setLineWidth(max(0.4, unit * 0.05))
                ctx.strokeEllipse(in: CGRect(x: wheel.x - unit * 0.3, y: wheel.y - unit * 0.07, width: unit * 0.6, height: unit * 0.14))
                AdventPaint.stroke(ctx, [CGPoint(x: wheel.x, y: wheel.y), CGPoint(x: wheel.x, y: hall.minY + hall.height * 0.92)],
                                   0x4a525c, max(0.4, unit * 0.06))
                // A cabin waiting at the platform.
                let waiting = CGRect(x: wheel.x - unit * 0.14, y: hall.minY + unit * 0.06, width: unit * 0.28, height: unit * 0.3)
                AdventPaint.box(ctx, waiting, unit * 0.08, 0xc0392b)
                AdventPaint.box(ctx, CGRect(x: waiting.minX + unit * 0.04, y: waiting.minY + waiting.height * 0.4,
                                            width: waiting.width - unit * 0.08, height: waiting.height * 0.34), unit * 0.02,
                                light ? 0xffd9a0 : 0xbcd2e4)
                // Steel posts holding the roof at the front corners.
                for x in [hall.minX + unit * 0.03, hall.maxX - unit * 0.03] {
                    AdventPaint.stroke(ctx, [CGPoint(x: x, y: hall.minY), CGPoint(x: x, y: hall.maxY)], 0x4a525c, max(0.4, unit * 0.05))
                }
                if light {
                    // Lamps under the roof edge.
                    for k in 0..<3 {
                        let x = hall.minX + hall.width * (0.2 + CGFloat(k) * 0.3)
                        AdventPaint.oval(ctx, x, hall.maxY - unit * 0.04, unit * 0.07, unit * 0.04, 0xfff1c8)
                    }
                }
                // A flat roof reaching out over the rope, thick with snow.
                let roof = CGRect(x: hall.minX - unit * 0.22, y: hall.maxY, width: hall.width + unit * 0.44, height: unit * 0.1)
                AdventPaint.box(ctx, roof, unit * 0.02, multiply(0x3e434b, sky.valleyLight))
                let cap = CGMutablePath()
                cap.move(to: CGPoint(x: roof.minX - unit * 0.03, y: roof.maxY - unit * 0.01))
                cap.addQuadCurve(to: CGPoint(x: roof.maxX + unit * 0.03, y: roof.maxY - unit * 0.01),
                                 control: CGPoint(x: roof.midX, y: roof.maxY + unit * 0.24))
                cap.closeSubpath()
                ctx.setFillColor(AdventPaint.color(snow))
                ctx.addPath(cap)
                ctx.fillPath()
                for icicle in 0..<3 {
                    let x = roof.minX + roof.width * (0.2 + CGFloat(icicle) * 0.3)
                    ctx.setFillColor(AdventPaint.color(0xdfeaf4, 0.9))
                    ctx.move(to: CGPoint(x: x - unit * 0.02, y: roof.minY))
                    ctx.addLine(to: CGPoint(x: x + unit * 0.02, y: roof.minY))
                    ctx.addLine(to: CGPoint(x: x, y: roof.minY - unit * (0.08 + CGFloat(icicle % 2) * 0.05)))
                    ctx.closePath()
                    ctx.fillPath()
                }
            }
        }
    }

    /// The cabins go round the loop, evenly spaced: up on the front rope,
    /// down on the back one. Before the door that starts the lifts they
    /// hang still. The near range hides them where it rises in front.
    private static func drawGondolaCabins(_ layout: AdventLayout, season: AdventSeason, sky: AdventSky,
                                          time: CGFloat, in ctx: CGContext) {
        guard layout.ridges.count == 3 else { return }
        let ways = gondolas(layout)
        guard !ways.isEmpty else { return }
        let bounds = layout.bounds
        let unit = bounds.height * 0.02
        // The lifts run all the time, day and night; from the thirteenth door
        // on their cabins are lit after dark.
        let lit = season.has(.cableCar)
        let near = layout.ridges[2]
        ctx.saveGState()
        let above = CGMutablePath()
        above.move(to: CGPoint(x: bounds.minX, y: bounds.maxY))
        above.addLines(between: [CGPoint(x: bounds.minX, y: bounds.maxY)] + near.points + [CGPoint(x: bounds.maxX, y: bounds.maxY)])
        above.closeSubpath()
        ctx.addPath(above)
        ctx.clip()
        let paints: [UInt32] = [0xc0392b, 0xc0392b, 0xd35400, 0xc0392b, 0x2c5f8a]
        let glass: UInt32 = lit ? 0xffd9a0 : (sky.lampStrength > 0.3 ? 0x3e4a5e : 0xbcd2e4)
        for (number, way) in ways.enumerated() {
            let phase = time * 0.022 + CGFloat(number) * 0.37
            let cabins = 5
            for k in 0..<cabins {
                for up in [true, false] {
                    var t = (phase + CGFloat(k) / CGFloat(cabins) + (up ? 0 : 0.5 / CGFloat(cabins))).truncatingRemainder(dividingBy: 1)
                    if !up { t = 1 - t }
                    guard t > 0.04, t < 0.96 else { continue }
                    // Into the station hall a cabin fades out, and out of it
                    // fades in, over the last stretch of rope: it no longer
                    // vanishes all at once in front of the waiting cabin.
                    let fade = min(1, max(0, min(t - 0.04, 0.96 - t) / 0.05))
                    if fade < 1 {
                        ctx.saveGState()
                        ctx.setAlpha(fade)
                        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                    }
                    defer { if fade < 1 { ctx.endTransparencyLayer(); ctx.restoreGState() } }
                    var grip = alongRope(way.rope, t)
                    if !up { grip.y -= unit * 0.16 }
                    let sway = sin(time * 1.3 + CGFloat(k) * 1.7) * unit * 0.02
                    // A cabin holds eight people: clearly bigger than a skier.
                    let c: CGFloat = 1.4
                    let cabin = CGRect(x: grip.x - unit * 0.15 * c + sway, y: grip.y - unit * 0.55 * c,
                                       width: unit * 0.30 * c, height: unit * 0.34 * c)
                    AdventPaint.stroke(ctx, [grip, CGPoint(x: cabin.midX, y: cabin.maxY)], 0x262d38, max(0.4, unit * 0.04))
                    AdventPaint.box(ctx, CGRect(x: grip.x - unit * 0.06, y: grip.y - unit * 0.03, width: unit * 0.12, height: unit * 0.06),
                                    unit * 0.02, 0x262d38)
                    // The cabins going up hang on the far rope: a touch darker,
                    // so where they pass the near ones the two read as one
                    // behind the other, not as a cabin drawn twice.
                    let paint = up ? blend(paints[(k + number * 2) % paints.count], 0x2a3442, 0.22)
                                   : paints[(k + number * 2) % paints.count]
                    AdventPaint.box(ctx, cabin, unit * 0.1, paint)
                    AdventPaint.box(ctx, CGRect(x: cabin.minX, y: cabin.maxY - unit * 0.05, width: cabin.width, height: unit * 0.05),
                                    unit * 0.03, multiply(0xeef5fa, sky.valleyLight))
                    AdventPaint.box(ctx, CGRect(x: cabin.minX + unit * 0.05, y: cabin.minY + cabin.height * 0.38,
                                                width: cabin.width - unit * 0.10, height: cabin.height * 0.36), unit * 0.02, glass)
                    // A darker skirt along the bottom, like the real ones.
                    AdventPaint.box(ctx, CGRect(x: cabin.minX + unit * 0.02, y: cabin.minY + unit * 0.02,
                                                width: cabin.width - unit * 0.04, height: cabin.height * 0.16), unit * 0.03,
                                    blend(paint, 0x000000, 0.3))
                    AdventPaint.stroke(ctx, [CGPoint(x: cabin.midX, y: cabin.minY + cabin.height * 0.38),
                                             CGPoint(x: cabin.midX, y: cabin.minY + cabin.height * 0.74)], paint, max(0.3, unit * 0.03))
                    if lit {
                        // Door 13: every cabin dressed for Christmas, a fir
                        // garland with a red bow along the roof and a string of
                        // bulbs under it, blinking, warm windows day and night.
                        AdventPaint.box(ctx, CGRect(x: cabin.minX - unit * 0.02, y: cabin.maxY - unit * 0.09, width: cabin.width + unit * 0.04,
                                                    height: unit * 0.07), unit * 0.03, 0x2f6b45)
                        AdventPaint.oval(ctx, cabin.midX, cabin.maxY - unit * 0.06, unit * 0.09, unit * 0.07, 0xc8322b)
                        let tints: [UInt32] = [0xffd25a, 0xff5a4a, 0x6ad07a, 0x6aa8ff]
                        for b in 0..<4 {
                            let on = (Int(time * 3) + b + k) % 3 != 0
                            let bx = cabin.minX + cabin.width * (CGFloat(b) + 0.5) / 4
                            let by = cabin.maxY - unit * 0.12
                            if on { AdventPaint.glow(ctx, at: CGPoint(x: bx, y: by), radius: unit * 0.08, tints[b], 0.6) }
                            AdventPaint.oval(ctx, bx, by, unit * 0.035, unit * 0.035, on ? tints[b] : blend(tints[b], 0x000000, 0.5))
                        }
                        AdventPaint.glow(ctx, at: CGPoint(x: cabin.midX, y: cabin.midY), radius: unit * 0.6, 0xffc87a, 0.12 + 0.2 * sky.lampStrength)
                    }
                }
            }
        }
        ctx.restoreGState()
    }

    /// The village tree itself is still, so it lives in the backdrop.
    private static func drawTreeBody(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        AdventPaint.fir(ctx, x: layout.tree.x, y: layout.tree.y, size: layout.treeSize, fill: 0x22454e,
                        snow: multiply(0xd7e6e9, sky.valleyLight))
    }

    /// Only the lights move: a garland wound three times round the tree,
    /// bulbs on the far side dimmer, and the star right on the top.
    private static func drawTree(_ layout: AdventLayout, season: AdventSeason, time: CGFloat, in ctx: CGContext) {
        guard season.has(.tree) else { return }
        let size = layout.treeSize
        let base = layout.tree
        let top = CGPoint(x: base.x, y: base.y + size * 1.02)
        AdventPaint.glow(ctx, at: CGPoint(x: base.x, y: base.y + size * 0.55), radius: size * 0.9, 0xffcf8a, 0.22)
        // The wire of the garland, wound three times round; only the turns on
        // the near side show.
        func spiral(_ f: CGFloat) -> (CGPoint, CGFloat) {
            let height = 0.16 + f * 0.78
            let half = size * (0.40 - 0.31 * f) * 0.86
            let angle = f * .pi * 2 * 3 + 0.4
            let depth = sin(angle)
            return (CGPoint(x: base.x + cos(angle) * half, y: base.y + height * size - depth * size * 0.025), depth)
        }
        ctx.setLineCap(.round)
        ctx.setStrokeColor(AdventPaint.color(0x1a2a22, 0.55))
        ctx.setLineWidth(max(0.4, size * 0.006))
        var previous: (CGPoint, CGFloat)? = nil
        for step in 0...180 {
            let current = spiral(CGFloat(step) / 180)
            if let last = previous, last.1 < 0, current.1 < 0 {
                ctx.move(to: last.0)
                ctx.addLine(to: current.0)
            }
            previous = current
        }
        ctx.strokePath()
        // Glass baubles hanging between the boughs, each with a cap and a
        // gleam of the lights in it.
        let baubleColours: [UInt32] = [0xc0302a, 0xd9a43a, 0xc9d3dc, 0x8e2430, 0xd9a43a, 0xc0302a]
        for bauble in 0..<16 {
            let f = 0.06 + CGFloat(bauble) / 16 * 0.80
            let rise = 0.14 + f * 0.70
            // The crown narrows to the top: keep each bauble well inside it.
            let half = size * 0.40 * (1 - (rise - 0.12) / 0.95) * 0.62
            let across = (AdventLayout.noise(bauble, 950) * 2 - 1) * half
            let at = CGPoint(x: base.x + across, y: base.y + size * rise)
            let radius = size * (0.017 + AdventLayout.noise(bauble, 951) * 0.007) * (1 - f * 0.4)
            let paint = baubleColours[bauble % baubleColours.count]
            let ball = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(blend(paint, 0xffffff, 0.45)), AdventPaint.color(paint),
                                           AdventPaint.color(blend(paint, 0x000000, 0.45))] as CFArray,
                                  locations: [0, 0.45, 1])!
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: at.x - radius, y: at.y - radius, width: radius * 2, height: radius * 2))
            ctx.clip()
            ctx.drawRadialGradient(ball, startCenter: CGPoint(x: at.x - radius * 0.35, y: at.y + radius * 0.35), startRadius: 0,
                                   endCenter: at, endRadius: radius * 1.1, options: [.drawsAfterEndLocation])
            ctx.restoreGState()
            AdventPaint.box(ctx, CGRect(x: at.x - radius * 0.3, y: at.y + radius * 0.85, width: radius * 0.6, height: radius * 0.35),
                            radius * 0.08, 0xc9a65a)
            let gleam = 0.6 + 0.4 * sin(time * 1.7 + CGFloat(bauble) * 2.1)
            AdventPaint.oval(ctx, at.x - radius * 0.38, at.y + radius * 0.38, radius * 0.32, radius * 0.32, 0xffffff, alpha: 0.75 * gleam)
        }
        let bulbs = 34
        for index in 0..<bulbs {
            let f = CGFloat(index) / CGFloat(bulbs - 1)
            let (point, depth) = spiral(f)
            let blink = 0.55 + 0.45 * sin(time * 2.4 + CGFloat(index) * 1.3)
            let front = depth < 0
            let tint: UInt32 = [0xffd99c, 0xf49d9b, 0xffd99c, 0x9fd0ff][index % 4]
            if front {
                AdventPaint.glow(ctx, at: point, radius: size * 0.04, tint, 0.45 * blink)
                AdventPaint.oval(ctx, point.x, point.y, size * 0.026, size * 0.03, tint, alpha: 0.7 + 0.3 * blink)
                AdventPaint.oval(ctx, point.x, point.y + size * 0.004, size * 0.011, size * 0.013, 0xffffff, alpha: 0.8 * blink)
            } else {
                AdventPaint.oval(ctx, point.x, point.y, size * 0.022, size * 0.022, tint, alpha: 0.22)
            }
        }
        let twinkle = 0.85 + 0.15 * sin(time * 1.9)
        AdventPaint.glow(ctx, at: top, radius: size * 0.22, 0xffd79b, 0.45 * twinkle)
        AdventPaint.star(ctx, top.x, top.y + size * 0.02, size * 0.075, 0xffc864)
        AdventPaint.star(ctx, top.x, top.y + size * 0.02, size * 0.04, 0xfff3d4)
    }

    /// Now and then on Christmas Eve a shooting star crosses the sky.
    private static func drawShootingStar(_ layout: AdventLayout, time: CGFloat, in ctx: CGContext) {
        let period: CGFloat = 23, flight: CGFloat = 1.4
        let cycle = time.truncatingRemainder(dividingBy: period)
        guard cycle < flight else { return }
        let round = Int(time / period)
        let bounds = layout.bounds
        let t = cycle / flight
        let start = CGPoint(x: bounds.minX + bounds.width * (0.15 + AdventLayout.noise(round, 900) * 0.5),
                            y: bounds.minY + bounds.height * (0.88 + AdventLayout.noise(round, 901) * 0.08))
        let travel = CGPoint(x: bounds.width * 0.22, y: -bounds.height * 0.12)
        let head = CGPoint(x: start.x + travel.x * t, y: start.y + travel.y * t)
        let tail = CGPoint(x: head.x - travel.x * 0.35, y: head.y - travel.y * 0.35)
        let fade = sin(t * .pi)
        let streak = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                colors: [AdventPaint.color(0xffffff, 0), AdventPaint.color(0xfff6e0, 0.9 * fade)] as CFArray,
                                locations: [0, 1])!
        // A meteor burns up far beyond the mountains: it shows only in the
        // sky above the skyline and slips behind a peak, never in front of
        // the Matterhorn (as two in five of them did).
        ctx.saveGState()
        defer { ctx.restoreGState() }
        if layout.horizon.count > 1 {
            let sky = CGMutablePath()
            sky.addLines(between: layout.horizon)
            sky.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            sky.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            sky.closeSubpath()
            ctx.addPath(sky)
            ctx.clip()
        }
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineWidth(max(1, bounds.height * 0.0025))
        ctx.move(to: tail)
        ctx.addLine(to: head)
        ctx.replacePathWithStrokedPath()
        ctx.clip()
        ctx.drawLinearGradient(streak, start: tail, end: head, options: [])
        ctx.restoreGState()
        AdventPaint.glow(ctx, at: head, radius: bounds.height * 0.008, 0xffffff, 0.9 * fade)
    }

    private static func drawChurchStar(_ layout: AdventLayout, time: CGFloat, in ctx: CGContext) {
        guard let church = layout.chalets.first(where: { $0.kind == .church }) else { return }
        let point = CGPoint(x: church.base.midX, y: church.base.maxY + church.roof * 1.5)
        let twinkle = 0.78 + 0.22 * sin(time * 2.1)
        AdventPaint.glow(ctx, at: point, radius: layout.bounds.height * 0.06, 0xffd79b, 0.3 * twinkle)
        AdventPaint.star(ctx, point.x, point.y, layout.bounds.height * 0.016 * twinkle, 0xffcd83)
        AdventPaint.star(ctx, point.x, point.y, layout.bounds.height * 0.009 * twinkle, 0xfff3d4)
    }

    private static func drawAurora(_ layout: AdventLayout, time: CGFloat, in ctx: CGContext) {
        let bounds = layout.bounds
        // The aurora is far behind the mountains: only the sky above them shows it.
        ctx.saveGState()
        defer { ctx.restoreGState() }
        if !layout.horizon.isEmpty {
            let sky = CGMutablePath()
            sky.addLines(between: layout.horizon)
            sky.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
            sky.addLine(to: CGPoint(x: bounds.minX, y: bounds.maxY))
            sky.closeSubpath()
            ctx.addPath(sky)
            ctx.clip()
        }
        // Each band is a blurred glow; blurring a stroke the width of the
        // screen every frame is far too slow, so each band is rendered once at
        // a quarter of the resolution (the light is soft anyway) and then only
        // drifts and breathes.
        let bands = auroraBands(bounds)
        guard let first = bands.first else { return }
        // The four curtains drift and breathe each on its own. They are laid
        // over one another at their own half resolution in a CGLayer, and
        // only that one strip is scaled up to the screen. A CGLayer, not a
        // fresh image each frame: sixty new images a second flooded the
        // image cache and slowed the snowflakes down for good.
        let reach = bounds.height * 0.02
        let strip = bands.dropFirst().reduce(first.rect) { $0.union($1.rect) }
            .insetBy(dx: 0, dy: -reach - 2).intersection(bounds)
        let scale: CGFloat = 0.5
        let size = CGSize(width: ceil(strip.width * scale), height: ceil(strip.height * scale))
        // One layer per screen size, so two displays do not keep replacing
        // each other's.
        let key = "\(Int(size.width))x\(Int(size.height))"
        if auroraLayers[key] == nil { auroraLayers[key] = CGLayer(ctx, size: size, auxiliaryInfo: nil) }
        guard let layer = auroraLayers[key], let canvas = layer.context else { return }
        canvas.saveGState()
        canvas.clear(CGRect(origin: .zero, size: size))
        canvas.scaleBy(x: scale, y: scale)
        canvas.translateBy(x: -strip.minX, y: -strip.minY)
        canvas.interpolationQuality = .medium
        for (index, band) in bands.enumerated() {
            let drift = sin(time * 0.21 + CGFloat(index) * 0.9) * reach
            let breathe = 0.6 + 0.4 * sin(time * 0.37 + CGFloat(index) * 1.4)
            canvas.setAlpha(breathe)
            canvas.draw(band.image, in: band.rect.offsetBy(dx: 0, dy: drift))
        }
        canvas.restoreGState()
        ctx.interpolationQuality = .high
        ctx.draw(layer, in: CGRect(x: strip.minX, y: strip.minY, width: size.width / scale, height: size.height / scale))
    }

    private static var auroraCache: (bounds: CGRect, bands: [(image: CGImage, rect: CGRect)])?
    private static var auroraLayers: [String: CGLayer] = [:]

    /// Each band, cut down to the strip of sky its light actually covers:
    /// the rest of a full-screen image is transparent, but scaling it up
    /// every frame cost as much as the light itself.
    private static func auroraBands(_ bounds: CGRect) -> [(image: CGImage, rect: CGRect)] {
        if let cache = auroraCache, cache.bounds == bounds { return cache.bands }
        // Half resolution: soft enough to be cheap, fine enough to stay smooth.
        let quarter: CGFloat = 0.5
        let width = max(1, Int(bounds.width * quarter)), height = max(1, Int(bounds.height * quarter))
        let tints: [UInt32] = [0x7df2c4, 0x8ae4e8, 0xb7a8f0, 0x7df2c4]
        var images: [(image: CGImage, rect: CGRect)] = []
        for index in 0..<4 {
            guard let layer = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { continue }
            layer.scaleBy(x: quarter, y: quarter)
            layer.translateBy(x: -bounds.minX, y: -bounds.minY)
            // A curtain of light: a fold-line across the sky with vertical
            // rays hanging up from it. Each ray is brightest at its foot,
            // a hard green lower edge, and fades upward into violet, as the
            // real aurora does. The rays bunch into folds that differ along
            // the curtain.
            let offset = CGFloat(index) * bounds.height * 0.035
            let a0 = CGPoint(x: bounds.minX - 10, y: bounds.minY + bounds.height * 0.80 + offset)
            let a1 = CGPoint(x: bounds.width * 0.35, y: bounds.minY + bounds.height * 1.02 + offset)
            let a2 = CGPoint(x: bounds.width * 0.72, y: bounds.minY + bounds.height * 0.70 + offset)
            let a3 = CGPoint(x: bounds.maxX + 10, y: bounds.minY + bounds.height * 0.86 + offset)
            var foot: [CGPoint] = []
            for step in 0...120 {
                let t = CGFloat(step) / 120, u = 1 - t
                let x = u * u * u * a0.x + 3 * u * u * t * a1.x + 3 * u * t * t * a2.x + t * t * t * a3.x
                let y = u * u * u * a0.y + 3 * u * u * t * a1.y + 3 * u * t * t * a2.y + t * t * t * a3.y
                foot.append(CGPoint(x: x, y: y))
            }
            func footY(_ x: CGFloat) -> CGFloat {
                guard let next = foot.firstIndex(where: { $0.x >= x }), next > 0 else { return foot.first!.y }
                let a = foot[next - 1], b = foot[next]
                return a.y + (b.y - a.y) * (x - a.x) / max(0.001, b.x - a.x)
            }
            let strength = 0.30 - CGFloat(index) * 0.045
            let base = tints[index]
            let crown: UInt32 = index == 2 ? 0xd59cf0 : 0xa98ce8
            let tall = bounds.height * (0.11 + CGFloat(index % 2) * 0.03)
            let rays = layer
            let space = CGColorSpace(name: CGColorSpace.sRGB)!
            var x = bounds.minX
            var ray = 0
            let step = 1.6 / quarter
            while x < bounds.maxX {
                // Folds: two slow waves and a little noise per ray.
                let fold = 0.5 + 0.32 * sin(x * 0.011 + CGFloat(index) * 1.7) + 0.18 * sin(x * 0.037 + CGFloat(index) * 4.1)
                let grain = AdventLayout.noise(ray + index * 997, 790)
                let lit = max(0, min(1, fold * 0.85 + grain * 0.3 - 0.08))
                if lit > 0.04 {
                    let y = footY(x)
                    let top = y + tall * (0.55 + 0.6 * lit + 0.2 * grain)
                    let gradient = CGGradient(colorsSpace: space,
                                              colors: [AdventPaint.color(base, 0),
                                                       AdventPaint.color(blend(base, 0xffffff, 0.35), strength * lit * 1.5),
                                                       AdventPaint.color(base, strength * lit),
                                                       AdventPaint.color(crown, strength * lit * 0.35),
                                                       AdventPaint.color(crown, 0)] as CFArray,
                                              locations: [0, 0.06, 0.22, 0.62, 1])!
                    let below = bounds.height * 0.008
                    rays.saveGState()
                    rays.clip(to: CGRect(x: x, y: y - below, width: step * 1.15, height: top - y + below))
                    rays.drawLinearGradient(gradient, start: CGPoint(x: x, y: y - below), end: CGPoint(x: x, y: top), options: [])
                    rays.restoreGState()
                }
                x += step
                ray += 1
            }
            // Soften the rays a little, so they read as light and not as a
            // bar code; done once, when the band is made.
            if let sharp = layer.makeImage() {
                let soft = CIImage(cgImage: sharp).clampedToExtent()
                    .applyingGaussianBlur(sigma: 1.3).cropped(to: CGRect(x: 0, y: 0, width: width, height: height))
                if let blurred = CIContext(options: [.cacheIntermediates: false]).createCGImage(soft, from: soft.extent) {
                    layer.saveGState()
                    layer.concatenate(layer.ctm.inverted())
                    layer.clear(CGRect(x: 0, y: 0, width: width, height: height))
                    layer.draw(blurred, in: CGRect(x: 0, y: 0, width: width, height: height))
                    layer.restoreGState()
                }
            }
            guard let image = layer.makeImage() else { continue }
            // Rows of the bitmap run from the top of the sky down; find the
            // first and last that hold any light at all.
            var first = height, last = -1
            if let data = layer.data {
                let pixels = data.bindMemory(to: UInt8.self, capacity: layer.bytesPerRow * height)
                for row in 0..<height {
                    let start = row * layer.bytesPerRow
                    var lit = false
                    var column = 0
                    while column < width {
                        if pixels[start + column * 4 + 3] != 0 { lit = true; break }
                        column += 1
                    }
                    if lit { first = min(first, row); last = row }
                }
            }
            guard last >= first else { continue }
            first = max(0, first - 2); last = min(height - 1, last + 2)
            guard let strip = image.cropping(to: CGRect(x: 0, y: first, width: width, height: last - first + 1)) else { continue }
            let rect = CGRect(x: bounds.minX, y: bounds.maxY - CGFloat(last + 1) / quarter,
                              width: CGFloat(width) / quarter, height: CGFloat(last - first + 1) / quarter)
            images.append((strip, rect))
        }
        auroraCache = (bounds, images)
        return images
    }

    /// Big snow-laden firs at both edges, cut off by the frame: the near
    /// layer that gives the valley the depth of a postcard.
    private static func drawFrameTrees(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let bounds = layout.bounds
        let unit = min(bounds.height * 0.052, bounds.width / 26)
        let shade = blend(0x16303c, sky.horizon, 0.12)
        let snow = multiply(blend(0xf2f7fb, sky.alpenglow, sky.alpenglowStrength * 0.3),
                            blend(sky.mountainLight, 0xffffff, 0.45))
        for (fx, fy, scale) in AdventLayout.frameTreeSpots {
            AdventPaint.fir(ctx, x: bounds.minX + bounds.width * fx, y: bounds.minY + bounds.height * fy,
                            size: unit * scale, fill: shade, snow: snow)
        }
    }

    /// Glints where the light catches the snow crust.
    private static func drawSparkle(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        let strength = 0.25 + sky.daylight * 0.5
        for sparkle in layout.sparkles {
            AdventPaint.oval(ctx, sparkle.point.x, sparkle.point.y, sparkle.size, sparkle.size,
                             0xffffff, alpha: 0.5 * strength)
        }
    }

    /// A cold veil over the whole valley, heaviest at the horizon: this is what
    /// pushes the scene into the distance behind the snow in front.
    private static func drawHaze(_ layout: AdventLayout, sky: AdventSky, in ctx: CGContext) {
        // Aerial haze belongs where the valley meets the far ranges. Near
        // things stay crisp; only the distance goes soft.
        let bounds = layout.bounds
        let haze = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [AdventPaint.color(sky.horizon, 0),
                                       AdventPaint.color(sky.horizon, 0.24),
                                       AdventPaint.color(sky.horizon, 0)] as CFArray,
                              locations: [0, 0.48, 1])!
        ctx.drawLinearGradient(haze, start: CGPoint(x: 0, y: bounds.minY + bounds.height * 0.26),
                               end: CGPoint(x: 0, y: bounds.minY + bounds.height * 0.64), options: [])
    }

    // MARK: Doors

    /// The little surprise behind an opened door, drawn into the doorway.
    /// Which present hides behind which door: twenty-four different ones,
    /// the star kept for Christmas Eve.
    static func treasureKind(_ day: Int) -> Int {
        if day == 24 { return 2 }
        if day == 2 { return 23 }
        if day <= 12 { return (day * 7) % 12 }
        return 12 + (day - 13)
    }

    private static func drawTreasure(_ kind: Int, in rect: CGRect, time: CGFloat, ctx: CGContext) {
        let c = CGPoint(x: rect.midX, y: rect.minY + rect.height * 0.42)
        let u = rect.width * 0.5
        switch kind {
        case 1:
            // A candle with a living flame.
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.22, y: rect.minY + rect.height * 0.12, width: u * 0.44,
                                        height: u * 1.0), u * 0.06, 0xc8322b)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.22, y: rect.minY + rect.height * 0.12, width: u * 0.14,
                                        height: u * 1.0), u * 0.06, 0xe0574c)
            let tip = CGPoint(x: c.x, y: rect.minY + rect.height * 0.12 + u * 1.0)
            let flicker = 1 + 0.12 * sin(time * 9)
            AdventPaint.glow(ctx, at: CGPoint(x: tip.x, y: tip.y + u * 0.3), radius: u * 1.2, 0xffd27a, 0.6)
            ctx.setFillColor(AdventPaint.color(0xffb340))
            ctx.beginPath()
            ctx.move(to: CGPoint(x: tip.x, y: tip.y + u * 0.62 * flicker))
            ctx.addQuadCurve(to: CGPoint(x: tip.x, y: tip.y + u * 0.04), control: CGPoint(x: tip.x + u * 0.34, y: tip.y + u * 0.12))
            ctx.addQuadCurve(to: CGPoint(x: tip.x, y: tip.y + u * 0.62 * flicker), control: CGPoint(x: tip.x - u * 0.34, y: tip.y + u * 0.12))
            ctx.fillPath()
            AdventPaint.oval(ctx, tip.x, tip.y + u * 0.18, u * 0.12, u * 0.2, 0xfff6c8)
        case 2:
            // A golden star hanging on a thread.
            AdventPaint.stroke(ctx, [CGPoint(x: c.x, y: rect.maxY), CGPoint(x: c.x, y: c.y + u * 0.5)], 0xb08a4a, max(0.4, u * 0.05))
            AdventPaint.glow(ctx, at: c, radius: u * 1.4, 0xffd27a, 0.45)
            AdventPaint.star(ctx, c.x, c.y, u * 0.62, 0xe8a93a)
            AdventPaint.star(ctx, c.x, c.y, u * 0.34, 0xffe28a)
        case 3:
            // A gingerbread heart with white icing.
            let heart = CGMutablePath()
            let r = u * 0.42
            heart.move(to: CGPoint(x: c.x, y: c.y - r * 1.3))
            heart.addCurve(to: CGPoint(x: c.x, y: c.y + r * 0.55), control1: CGPoint(x: c.x - r * 2.2, y: c.y - r * 0.1),
                           control2: CGPoint(x: c.x - r * 0.9, y: c.y + r * 1.6))
            heart.addCurve(to: CGPoint(x: c.x, y: c.y - r * 1.3), control1: CGPoint(x: c.x + r * 0.9, y: c.y + r * 1.6),
                           control2: CGPoint(x: c.x + r * 2.2, y: c.y - r * 0.1))
            heart.closeSubpath()
            AdventPaint.stroke(ctx, [CGPoint(x: c.x, y: rect.maxY), CGPoint(x: c.x, y: c.y + r * 0.5)], 0xc23b32, max(0.4, u * 0.06))
            ctx.setFillColor(AdventPaint.color(0x9a5a2a))
            ctx.addPath(heart)
            ctx.fillPath()
            ctx.setStrokeColor(AdventPaint.color(0xfff8ee))
            ctx.setLineWidth(max(0.4, u * 0.06))
            ctx.saveGState()
            ctx.translateBy(x: c.x, y: c.y - r * 0.1)
            ctx.scaleBy(x: 0.78, y: 0.78)
            ctx.translateBy(x: -c.x, y: -(c.y - r * 0.1))
            ctx.addPath(heart)
            ctx.strokePath()
            ctx.restoreGState()
        case 4:
            // A wrapped present with a ribbon and bow.
            let box = CGRect(x: c.x - u * 0.55, y: rect.minY + rect.height * 0.10, width: u * 1.1, height: u * 0.85)
            AdventPaint.box(ctx, box, u * 0.05, 0x2d6a46)
            AdventPaint.box(ctx, CGRect(x: box.minX - u * 0.06, y: box.maxY - u * 0.24, width: box.width + u * 0.12,
                                        height: u * 0.24), u * 0.04, 0x37805a)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.09, y: box.minY, width: u * 0.18, height: box.height), 0, 0xe8b440)
            AdventPaint.oval(ctx, c.x - u * 0.2, box.maxY + u * 0.1, u * 0.38, u * 0.24, 0xe8b440)
            AdventPaint.oval(ctx, c.x + u * 0.2, box.maxY + u * 0.1, u * 0.38, u * 0.24, 0xe8b440)
        case 5:
            // A red stocking with a white cuff.
            let sock = CGMutablePath()
            let top = rect.minY + rect.height * 0.72
            sock.move(to: CGPoint(x: c.x - u * 0.3, y: top))
            sock.addLine(to: CGPoint(x: c.x - u * 0.3, y: c.y - u * 0.35))
            sock.addQuadCurve(to: CGPoint(x: c.x + u * 0.55, y: c.y - u * 0.75), control: CGPoint(x: c.x - u * 0.3, y: c.y - u * 0.9))
            sock.addQuadCurve(to: CGPoint(x: c.x + u * 0.25, y: c.y - u * 0.15), control: CGPoint(x: c.x + u * 0.75, y: c.y - u * 0.3))
            sock.addLine(to: CGPoint(x: c.x + u * 0.25, y: top))
            sock.closeSubpath()
            ctx.setFillColor(AdventPaint.color(0xc8322b))
            ctx.addPath(sock)
            ctx.fillPath()
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.38, y: top - u * 0.08, width: u * 0.71, height: u * 0.26), u * 0.08, 0xfff8ee)
        case 6:
            // A golden bell with a red bow.
            let bell = CGMutablePath()
            let mouth = c.y - u * 0.45
            bell.move(to: CGPoint(x: c.x - u * 0.55, y: mouth))
            bell.addQuadCurve(to: CGPoint(x: c.x, y: c.y + u * 0.55), control: CGPoint(x: c.x - u * 0.45, y: c.y + u * 0.6))
            bell.addQuadCurve(to: CGPoint(x: c.x + u * 0.55, y: mouth), control: CGPoint(x: c.x + u * 0.45, y: c.y + u * 0.6))
            bell.closeSubpath()
            AdventPaint.glow(ctx, at: c, radius: u * 1.2, 0xffd27a, 0.35)
            ctx.setFillColor(AdventPaint.color(0xd99a2a))
            ctx.addPath(bell)
            ctx.fillPath()
            AdventPaint.oval(ctx, c.x - u * 0.16, c.y + u * 0.05, u * 0.14, u * 0.42, 0xffe08a)
            AdventPaint.oval(ctx, c.x, mouth - u * 0.06, u * 0.2, u * 0.2, 0x8a5a1e)
            AdventPaint.oval(ctx, c.x - u * 0.16, c.y + u * 0.62, u * 0.3, u * 0.2, 0xc23b32)
            AdventPaint.oval(ctx, c.x + u * 0.16, c.y + u * 0.62, u * 0.3, u * 0.2, 0xc23b32)
        case 7:
            // A candy cane, red and white.
            let cane = [CGPoint(x: c.x + u * 0.1, y: rect.minY + rect.height * 0.1),
                        CGPoint(x: c.x + u * 0.1, y: c.y + u * 0.35)]
            let hook = CGMutablePath()
            hook.move(to: cane[0])
            hook.addLine(to: cane[1])
            hook.addArc(center: CGPoint(x: c.x - u * 0.15, y: cane[1].y), radius: u * 0.25, startAngle: 0, endAngle: .pi,
                        clockwise: false)
            hook.addLine(to: CGPoint(x: c.x - u * 0.4, y: cane[1].y - u * 0.15))
            ctx.setLineCap(.round)
            ctx.setStrokeColor(AdventPaint.color(0xfff8ee))
            ctx.setLineWidth(max(1, u * 0.22))
            ctx.addPath(hook)
            ctx.strokePath()
            ctx.setStrokeColor(AdventPaint.color(0xc8322b))
            ctx.setLineDash(phase: 0, lengths: [u * 0.12, u * 0.14])
            ctx.addPath(hook)
            ctx.strokePath()
            ctx.setLineDash(phase: 0, lengths: [])
        case 8:
            // A red glass bauble on a ribbon, with a gleam.
            let ball = CGPoint(x: c.x, y: c.y - u * 0.05)
            AdventPaint.stroke(ctx, [CGPoint(x: c.x, y: rect.maxY), CGPoint(x: c.x, y: ball.y + u * 0.42)], 0xc9a65a, max(0.5, u * 0.05))
            let glass = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                   colors: [AdventPaint.color(0xf07a6e), AdventPaint.color(0xc0302a), AdventPaint.color(0x6e1414)] as CFArray,
                                   locations: [0, 0.5, 1])!
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: ball.x - u * 0.38, y: ball.y - u * 0.38, width: u * 0.76, height: u * 0.76))
            ctx.clip()
            ctx.drawRadialGradient(glass, startCenter: CGPoint(x: ball.x - u * 0.12, y: ball.y + u * 0.12), startRadius: 0,
                                   endCenter: ball, endRadius: u * 0.42, options: [.drawsAfterEndLocation])
            ctx.restoreGState()
            AdventPaint.box(ctx, CGRect(x: ball.x - u * 0.1, y: ball.y + u * 0.34, width: u * 0.2, height: u * 0.1), u * 0.02, 0xd9a43a)
            AdventPaint.oval(ctx, ball.x - u * 0.14, ball.y + u * 0.14, u * 0.12, u * 0.12, 0xffffff, alpha: 0.7 + 0.3 * sin(time * 2))
        case 9:
            // A Christmas stocking with a white cuff and a heel patch.
            let sock = CGMutablePath()
            let top = rect.minY + rect.height * 0.78
            sock.move(to: CGPoint(x: c.x - u * 0.15, y: top))
            sock.addLine(to: CGPoint(x: c.x + u * 0.22, y: top))
            sock.addLine(to: CGPoint(x: c.x + u * 0.22, y: rect.minY + rect.height * 0.30))
            sock.addQuadCurve(to: CGPoint(x: c.x - u * 0.45, y: rect.minY + rect.height * 0.14),
                              control: CGPoint(x: c.x + u * 0.2, y: rect.minY + rect.height * 0.05))
            sock.addQuadCurve(to: CGPoint(x: c.x - u * 0.15, y: rect.minY + rect.height * 0.34),
                              control: CGPoint(x: c.x - u * 0.5, y: rect.minY + rect.height * 0.30))
            sock.closeSubpath()
            ctx.setFillColor(AdventPaint.color(0xc0302a))
            ctx.addPath(sock)
            ctx.fillPath()
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.2, y: top - u * 0.05, width: u * 0.47, height: u * 0.22), u * 0.06, 0xfff8ee)
            AdventPaint.oval(ctx, c.x + u * 0.1, rect.minY + rect.height * 0.2, u * 0.18, u * 0.14, 0x2f5a3c)
        case 10:
            // A six-armed snowflake, slowly turning.
            ctx.saveGState()
            ctx.translateBy(x: c.x, y: c.y)
            ctx.rotate(by: time * 0.3)
            ctx.setStrokeColor(AdventPaint.color(0x8fb6d8))
            ctx.setLineCap(.round)
            ctx.setLineWidth(max(0.5, u * 0.07))
            for arm in 0..<6 {
                let a = CGFloat(arm) * .pi / 3
                let tip = CGPoint(x: cos(a) * u * 0.45, y: sin(a) * u * 0.45)
                ctx.move(to: .zero)
                ctx.addLine(to: tip)
                for side: CGFloat in [-1, 1] {
                    let mid = CGPoint(x: cos(a) * u * 0.27, y: sin(a) * u * 0.27)
                    ctx.move(to: mid)
                    ctx.addLine(to: CGPoint(x: mid.x + cos(a + side * 0.8) * u * 0.14, y: mid.y + sin(a + side * 0.8) * u * 0.14))
                }
            }
            ctx.strokePath()
            ctx.restoreGState()
        case 11:
            // A little gingerbread man with icing.
            let dough: UInt32 = 0xb06b32
            AdventPaint.oval(ctx, c.x, c.y + u * 0.32, u * 0.36, u * 0.36, dough)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.2, y: c.y - u * 0.3, width: u * 0.4, height: u * 0.5), u * 0.12, dough)
            for side: CGFloat in [-1, 1] {
                AdventPaint.stroke(ctx, [CGPoint(x: c.x + side * u * 0.15, y: c.y + u * 0.08), CGPoint(x: c.x + side * u * 0.42, y: c.y + u * 0.0)],
                                   dough, u * 0.17)
                AdventPaint.stroke(ctx, [CGPoint(x: c.x + side * u * 0.1, y: c.y - u * 0.25), CGPoint(x: c.x + side * u * 0.22, y: c.y - u * 0.58)],
                                   dough, u * 0.18)
            }
            ctx.setStrokeColor(AdventPaint.color(0xffffff, 0.9))
            ctx.setLineWidth(max(0.4, u * 0.035))
            ctx.addArc(center: CGPoint(x: c.x, y: c.y + u * 0.29), radius: u * 0.08, startAngle: .pi * 1.15, endAngle: .pi * 1.85, clockwise: false)
            ctx.strokePath()
            for k in 0..<2 { AdventPaint.oval(ctx, c.x, c.y - u * (0.02 + CGFloat(k) * 0.14), u * 0.06, u * 0.06, 0xc0302a) }
        case 12:
            // A red knitted mitten with a white cuff and a snowflake.
            let wool: UInt32 = 0xc8322b
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.30, y: c.y - u * 0.30, width: u * 0.58, height: u * 0.78), u * 0.26, wool)
            AdventPaint.oval(ctx, c.x + u * 0.32, c.y + u * 0.02, u * 0.24, u * 0.36, wool)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.34, y: c.y - u * 0.52, width: u * 0.66, height: u * 0.26), u * 0.08, 0xf4efe6)
            AdventPaint.star(ctx, c.x - u * 0.02, c.y + u * 0.12, u * 0.12, 0xffffff)
        case 13:
            // A small snowman with a black hat and a carrot nose.
            AdventPaint.oval(ctx, c.x, c.y - u * 0.22, u * 0.62, u * 0.58, 0xffffff)
            AdventPaint.oval(ctx, c.x, c.y + u * 0.30, u * 0.42, u * 0.40, 0xffffff)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.16, y: c.y + u * 0.48, width: u * 0.32, height: u * 0.26), u * 0.03, 0x22262e)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.24, y: c.y + u * 0.46, width: u * 0.48, height: u * 0.06), u * 0.02, 0x22262e)
            AdventPaint.stroke(ctx, [CGPoint(x: c.x, y: c.y + u * 0.28), CGPoint(x: c.x + u * 0.2, y: c.y + u * 0.25)], 0xe8822e, max(0.6, u * 0.07))
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.24, y: c.y + u * 0.06, width: u * 0.48, height: u * 0.08), u * 0.03, 0xc8322b)
        case 14:
            // A wooden sled with curled runners.
            let wood: UInt32 = 0xa8743f
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.42, y: c.y, width: u * 0.84, height: u * 0.14), u * 0.04, wood)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.42, y: c.y + u * 0.16, width: u * 0.84, height: u * 0.10), u * 0.04, blend(wood, 0xffffff, 0.15))
            for side: CGFloat in [-0.28, 0.28] {
                AdventPaint.stroke(ctx, [CGPoint(x: c.x + side * u, y: c.y), CGPoint(x: c.x + side * u, y: c.y - u * 0.22)], 0x5a3a22, max(0.5, u * 0.06))
            }
            AdventPaint.stroke(ctx, [CGPoint(x: c.x - u * 0.5, y: c.y - u * 0.24), CGPoint(x: c.x + u * 0.44, y: c.y - u * 0.24),
                                     CGPoint(x: c.x + u * 0.56, y: c.y - u * 0.10)], 0x3a2a20, max(0.5, u * 0.06))
        case 15:
            // A pine cone with overlapping scales.
            let cone: UInt32 = 0x8a5a32
            AdventPaint.oval(ctx, c.x, c.y + u * 0.04, u * 0.50, u * 0.86, blend(cone, 0x000000, 0.2))
            for row in 0..<5 {
                let y = c.y - u * 0.30 + CGFloat(row) * u * 0.16
                let span = u * (0.20 - abs(CGFloat(row) - 2) * 0.03)
                for k in -1...1 {
                    AdventPaint.oval(ctx, c.x + CGFloat(k) * span * 0.8, y, span * 0.9, u * 0.16, blend(cone, 0xd9a86a, 0.25 + CGFloat(row) * 0.06))
                }
            }
            AdventPaint.stroke(ctx, [CGPoint(x: c.x, y: c.y + u * 0.46), CGPoint(x: c.x + u * 0.06, y: c.y + u * 0.62)], 0x4a3020, max(0.5, u * 0.06))
        case 16:
            // A cinnamon star biscuit with white icing.
            AdventPaint.star(ctx, c.x, c.y + u * 0.04, u * 0.56, 0xa0662e)
            AdventPaint.star(ctx, c.x, c.y + u * 0.07, u * 0.46, 0xfbf6ee)
        case 17:
            // A mug of hot chocolate with curling steam.
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.30, y: c.y - u * 0.36, width: u * 0.56, height: u * 0.62), u * 0.08, 0xc8322b)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.30, y: c.y - u * 0.02, width: u * 0.56, height: u * 0.08), 0, 0xffffff)
            ctx.setStrokeColor(AdventPaint.color(0xc8322b))
            ctx.setLineWidth(max(0.6, u * 0.08))
            ctx.addArc(center: CGPoint(x: c.x + u * 0.30, y: c.y - u * 0.06), radius: u * 0.14, startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: false)
            ctx.strokePath()
            AdventPaint.oval(ctx, c.x - u * 0.02, c.y + u * 0.26, u * 0.50, u * 0.10, 0x5a3420)
            for k in 0..<2 {
                let x = c.x - u * 0.10 + CGFloat(k) * u * 0.18
                let sway = sin(time * 2 + CGFloat(k) * 2) * u * 0.05
                AdventPaint.stroke(ctx, [CGPoint(x: x, y: c.y + u * 0.36), CGPoint(x: x + sway, y: c.y + u * 0.52), CGPoint(x: x - sway, y: c.y + u * 0.68)],
                                   0xffffff, max(0.4, u * 0.04), alpha: 0.7)
            }
        case 18:
            // A little tin lantern with a candle glowing inside.
            AdventPaint.glow(ctx, at: CGPoint(x: c.x, y: c.y), radius: u * 0.9, 0xffd27a, 0.45 + 0.1 * sin(time * 7))
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.26, y: c.y - u * 0.36, width: u * 0.52, height: u * 0.62), u * 0.04, 0x3a3f48)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.18, y: c.y - u * 0.28, width: u * 0.36, height: u * 0.46), u * 0.02, 0xffd890)
            AdventPaint.oval(ctx, c.x, c.y - u * 0.04, u * 0.10, u * 0.18, 0xfff6c8)
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: c.x - u * 0.32, y: c.y + u * 0.26)); roof.addLine(to: CGPoint(x: c.x, y: c.y + u * 0.48))
            roof.addLine(to: CGPoint(x: c.x + u * 0.32, y: c.y + u * 0.26)); roof.closeSubpath()
            ctx.setFillColor(AdventPaint.color(0x3a3f48)); ctx.addPath(roof); ctx.fillPath()
            ctx.setStrokeColor(AdventPaint.color(0x3a3f48)); ctx.setLineWidth(max(0.4, u * 0.04))
            ctx.addArc(center: CGPoint(x: c.x, y: c.y + u * 0.54), radius: u * 0.08, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()
        case 19:
            // A sprig of holly: two spiky leaves and three red berries.
            for side: CGFloat in [-1, 1] {
                ctx.saveGState()
                ctx.translateBy(x: c.x, y: c.y)
                ctx.rotate(by: side * 0.6)
                let leaf = CGMutablePath()
                leaf.move(to: .zero)
                for k in 0...4 {
                    let y = -u * 0.12 * CGFloat(k) - u * 0.04
                    leaf.addLine(to: CGPoint(x: side * u * (k % 2 == 0 ? 0.20 : 0.12), y: y + u * 0.03))
                }
                leaf.addLine(to: CGPoint(x: 0, y: -u * 0.62))
                for k in (0...4).reversed() {
                    let y = -u * 0.12 * CGFloat(k) - u * 0.04
                    leaf.addLine(to: CGPoint(x: -side * u * (k % 2 == 0 ? 0.06 : 0.02), y: y))
                }
                leaf.closeSubpath()
                ctx.scaleBy(x: 1, y: -1)
                ctx.setFillColor(AdventPaint.color(0x2f6b45)); ctx.addPath(leaf); ctx.fillPath()
                ctx.restoreGState()
            }
            for (dx, dy) in [(-0.08, 0.02), (0.08, 0.02), (0.0, -0.10)] as [(CGFloat, CGFloat)] {
                AdventPaint.oval(ctx, c.x + u * dx, c.y + u * dy, u * 0.16, u * 0.16, 0xc8322b)
                AdventPaint.oval(ctx, c.x + u * dx - u * 0.03, c.y + u * dy + u * 0.03, u * 0.05, u * 0.05, 0xffb0a0)
            }
        case 20:
            // A gingerbread house with white icing on the roof.
            let dough: UInt32 = 0xb06b32
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.34, y: c.y - u * 0.36, width: u * 0.68, height: u * 0.46), u * 0.03, dough)
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: c.x - u * 0.46, y: c.y + u * 0.08)); roof.addLine(to: CGPoint(x: c.x, y: c.y + u * 0.48))
            roof.addLine(to: CGPoint(x: c.x + u * 0.46, y: c.y + u * 0.08)); roof.closeSubpath()
            ctx.setFillColor(AdventPaint.color(blend(dough, 0x000000, 0.15))); ctx.addPath(roof); ctx.fillPath()
            AdventPaint.stroke(ctx, [CGPoint(x: c.x - u * 0.46, y: c.y + u * 0.08), CGPoint(x: c.x, y: c.y + u * 0.48), CGPoint(x: c.x + u * 0.46, y: c.y + u * 0.08)],
                               0xffffff, max(0.5, u * 0.07))
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.08, y: c.y - u * 0.36, width: u * 0.16, height: u * 0.24), u * 0.06, 0xf4efe6)
            for side: CGFloat in [-1, 1] { AdventPaint.oval(ctx, c.x + side * u * 0.20, c.y - u * 0.06, u * 0.10, u * 0.10, [0xc8322b, 0x3f8a5a][side < 0 ? 0 : 1]) }
        case 21:
            // A small teddy bear.
            let fur: UInt32 = 0x9a6a3c
            AdventPaint.oval(ctx, c.x, c.y - u * 0.18, u * 0.52, u * 0.56, fur)
            AdventPaint.oval(ctx, c.x, c.y + u * 0.30, u * 0.42, u * 0.40, fur)
            for side: CGFloat in [-1, 1] {
                AdventPaint.oval(ctx, c.x + side * u * 0.17, c.y + u * 0.48, u * 0.16, u * 0.16, fur)
                AdventPaint.oval(ctx, c.x + side * u * 0.30, c.y - u * 0.12, u * 0.18, u * 0.30, fur)
                AdventPaint.oval(ctx, c.x + side * u * 0.08, c.y + u * 0.34, u * 0.05, u * 0.05, 0x22262e)
            }
            AdventPaint.oval(ctx, c.x, c.y + u * 0.24, u * 0.18, u * 0.13, blend(fur, 0xffffff, 0.4))
            AdventPaint.oval(ctx, c.x, c.y + u * 0.26, u * 0.06, u * 0.05, 0x22262e)
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.16, y: c.y + u * 0.06, width: u * 0.32, height: u * 0.06), u * 0.03, 0xc8322b)
        case 22:
            // A knitted bobble hat in stripes.
            let hat = CGMutablePath()
            hat.move(to: CGPoint(x: c.x - u * 0.38, y: c.y - u * 0.20))
            hat.addQuadCurve(to: CGPoint(x: c.x + u * 0.38, y: c.y - u * 0.20), control: CGPoint(x: c.x, y: c.y + u * 0.62))
            hat.closeSubpath()
            ctx.setFillColor(AdventPaint.color(0x2f6fb0)); ctx.addPath(hat); ctx.fillPath()
            ctx.saveGState(); ctx.addPath(hat); ctx.clip()
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.4, y: c.y, width: u * 0.8, height: u * 0.08), 0, 0xffffff)
            ctx.restoreGState()
            AdventPaint.box(ctx, CGRect(x: c.x - u * 0.42, y: c.y - u * 0.36, width: u * 0.84, height: u * 0.18), u * 0.06, 0xf4efe6)
            AdventPaint.oval(ctx, c.x, c.y + u * 0.40, u * 0.24, u * 0.24, 0xf4efe6)
        case 23:
            // A tangerine with a green leaf, as in every Nikolaus boot.
            AdventPaint.oval(ctx, c.x, c.y, u * 0.66, u * 0.60, 0xf08a24)
            AdventPaint.oval(ctx, c.x - u * 0.12, c.y + u * 0.10, u * 0.18, u * 0.12, 0xffb45a)
            AdventPaint.oval(ctx, c.x + u * 0.16, c.y + u * 0.34, u * 0.26, u * 0.12, 0x3f8a5a)
            AdventPaint.oval(ctx, c.x, c.y + u * 0.29, u * 0.06, u * 0.06, 0x6a4a2a)
        default:
            // A lit tree with a star on top.
            AdventPaint.fir(ctx, x: rect.midX, y: rect.minY + rect.height * 0.08,
                            size: rect.height * 0.62, fill: 0x2f6a4a, snow: 0xffffff)
            for bauble in 0..<3 {
                let t = CGFloat(bauble)
                AdventPaint.oval(ctx, rect.midX + (t - 1) * u * 0.3, rect.minY + rect.height * (0.22 + t * 0.12),
                                 u * 0.12, u * 0.12, [0xc23b32, 0xe8b440, 0x4a7ac8][bauble])
            }
            AdventPaint.star(ctx, rect.midX, rect.minY + rect.height * 0.74, u * 0.22, 0xffd27a)
        }
    }

    private static func drawDoor(_ door: AdventDoor, season: AdventSeason, time: CGFloat,
                                 pointer: CGPoint?, dusk: CGFloat = 1, in ctx: CGContext) {
        let rect = door.rect
        let open = season.isOpen(door.day)
        let ready = season.canOpen(door.day)
        let fine = rect.width > 15
        // Painted doors and a pale frame: brown on brown logs disappears. The
        // doors are the calendar, so they have to stand out from the wall.
        let frame = UInt32(0xe6d6b4)
        let paint: UInt32 = door.day == 24 ? 0x8e2222 : [0xbf3030, 0x2f8a52, 0x2f5fa8, 0xc07a1e][door.day % 4]

        // The doorway itself, cut into the log wall, with an arched head.
        let arch = CGMutablePath()
        arch.move(to: CGPoint(x: rect.minX, y: rect.minY))
        arch.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - rect.width * 0.42))
        arch.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY - rect.width * 0.42),
                          control: CGPoint(x: rect.midX, y: rect.maxY + rect.width * 0.18))
        arch.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        arch.closeSubpath()
        ctx.setFillColor(AdventPaint.color(frame))
        ctx.addPath(arch)
        ctx.fillPath()

        if open {
            // Standing open on a warm room. The light pours out onto the snow
            // in front, so an opened door reads from across the valley.
            let spill = CGMutablePath()
            spill.move(to: CGPoint(x: rect.minX, y: rect.minY))
            spill.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            spill.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.9, y: rect.minY - rect.height * 0.55))
            spill.addLine(to: CGPoint(x: rect.minX - rect.width * 0.9, y: rect.minY - rect.height * 0.55))
            spill.closeSubpath()
            ctx.saveGState()
            ctx.addPath(spill)
            ctx.clip()
            let pool = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(0xffcf86, 0.25 + 0.45 * dusk),
                                           AdventPaint.color(0xffcf86, 0)] as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(pool, start: CGPoint(x: 0, y: rect.minY),
                                   end: CGPoint(x: 0, y: rect.minY - rect.height * 0.55), options: [])
            ctx.restoreGState()
            // A warm halo round the doorway; small enough that the snow
            // between the houses stays cool blue at night.
            AdventPaint.glow(ctx, at: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width * 2.0,
                             0xffc072, 0.24 + 0.14 * dusk)
            if door.day == 24 {
                // Christmas Eve: candles either side of the church portal.
                for side: CGFloat in [-1, 1] {
                    let c = CGPoint(x: rect.midX + side * rect.width * 0.85, y: rect.minY + rect.height * 0.15)
                    AdventPaint.box(ctx, CGRect(x: c.x - rect.width * 0.06, y: c.y, width: rect.width * 0.12,
                                                height: rect.height * 0.32), 0.6, 0xf3ead8)
                    let flame = CGPoint(x: c.x, y: c.y + rect.height * 0.38)
                    let flicker = 0.85 + 0.15 * sin(time * 9 + side * 2)
                    AdventPaint.glow(ctx, at: flame, radius: rect.width * 0.5, 0xffc060, 0.6 * flicker)
                    AdventPaint.oval(ctx, flame.x, flame.y, rect.width * 0.07, rect.width * 0.12 * flicker, 0xffe9a0)
                }
            }
            ctx.saveGState()
            ctx.addPath(arch)
            ctx.clip()
            let room = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                  colors: [AdventPaint.color(0xffcf86), AdventPaint.color(0xfff2d6)] as CFArray,
                                  locations: [0, 1])!
            ctx.drawLinearGradient(room, start: CGPoint(x: 0, y: rect.minY),
                                   end: CGPoint(x: 0, y: rect.maxY), options: [.drawsAfterEndLocation])
            if rect.width > 12 {
                // A little room behind the door: boards on the back wall,
                // shade in the reveal and under the arch, a shelf to stand on.
                ctx.setStrokeColor(AdventPaint.color(0xc99a5c, 0.35))
                ctx.setLineWidth(max(0.4, rect.width * 0.02))
                for board in 1..<4 {
                    let x = rect.minX + rect.width * CGFloat(board) / 4
                    ctx.move(to: CGPoint(x: x, y: rect.minY))
                    ctx.addLine(to: CGPoint(x: x, y: rect.maxY))
                }
                ctx.strokePath()
                let reveal = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                        colors: [AdventPaint.color(0x6a3e1c, 0.35), AdventPaint.color(0x6a3e1c, 0)] as CFArray,
                                        locations: [0, 1])!
                ctx.drawLinearGradient(reveal, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.minX + rect.width * 0.22, y: 0), options: [])
                ctx.drawLinearGradient(reveal, start: CGPoint(x: rect.maxX, y: 0), end: CGPoint(x: rect.maxX - rect.width * 0.14, y: 0), options: [])
                ctx.drawLinearGradient(reveal, start: CGPoint(x: 0, y: rect.maxY), end: CGPoint(x: 0, y: rect.maxY - rect.height * 0.25), options: [])
                AdventPaint.box(ctx, CGRect(x: rect.minX, y: rect.minY + rect.height * 0.06, width: rect.width, height: rect.height * 0.05),
                                0, 0x9a6a3c, alpha: 0.85)
                AdventPaint.box(ctx, CGRect(x: rect.minX, y: rect.minY + rect.height * 0.105, width: rect.width, height: rect.height * 0.015),
                                0, 0xe0b27a, alpha: 0.8)
            }
            if rect.width > 7 {
                // Every door hides something of its own, even far away.
                // Behind the church door on Christmas Eve: the star.
                drawTreasure(treasureKind(door.day),
                             in: door.day == 24 ? rect.insetBy(dx: -rect.width * 0.25, dy: 0) : rect, time: time, ctx: ctx)
            }
            ctx.restoreGState()
            // The leaf swung back against the wall.
            ctx.saveGState()
            ctx.translateBy(x: rect.minX, y: rect.minY)
            ctx.scaleBy(x: 0.30, y: 1)
            // The leaf has the doorway's own arched head, so it would fit
            // back into it; everything on it stays inside that outline.
            let leafRect = CGRect(x: -rect.width * 1.05, y: 0, width: rect.width, height: rect.height)
            let leaf = CGMutablePath()
            leaf.move(to: CGPoint(x: leafRect.minX, y: 0))
            leaf.addLine(to: CGPoint(x: leafRect.minX, y: rect.height - rect.width * 0.42))
            leaf.addQuadCurve(to: CGPoint(x: leafRect.maxX, y: rect.height - rect.width * 0.42),
                              control: CGPoint(x: leafRect.midX, y: rect.height + rect.width * 0.18))
            leaf.addLine(to: CGPoint(x: leafRect.maxX, y: 0))
            leaf.closeSubpath()
            ctx.setFillColor(AdventPaint.color(blend(paint, 0x20150f, 0.25)))
            ctx.addPath(leaf)
            ctx.fillPath()
            ctx.addPath(leaf)
            ctx.clip()
            if rect.width > 12 {
                // The inside of the leaf: two sunk panels, a lit edge, a knob.
                for panel in 0..<2 {
                    AdventPaint.box(ctx, CGRect(x: -rect.width * 0.92, y: rect.height * (0.10 + CGFloat(panel) * 0.44),
                                                width: rect.width * 0.74, height: rect.height * 0.36), 1, blend(paint, 0x20150f, 0.42))
                }
                AdventPaint.box(ctx, CGRect(x: -rect.width * 1.05, y: 0, width: rect.width * 0.08, height: rect.height), 0,
                                blend(paint, 0xffffff, 0.25))
                AdventPaint.oval(ctx, -rect.width * 0.85, rect.height * 0.5, rect.width * 0.12, rect.width * 0.40, 0xd9a43a)
            }
            ctx.restoreGState()
            ctx.setStrokeColor(AdventPaint.color(frame, 0.9))
            ctx.setLineWidth(max(0.7, rect.width * 0.08))
            ctx.addPath(arch)
            ctx.strokePath()
            // The number stays, so the calendar still reads as a calendar.
            let plaque = CGRect(x: rect.midX - rect.width * 0.42, y: rect.maxY + rect.width * 0.10,
                                width: rect.width * 0.84, height: max(8, rect.height * 0.32))
            AdventPaint.box(ctx, plaque, 1.2, 0xf3e6c8, alpha: 0.9)
            ctx.setStrokeColor(AdventPaint.color(0xc8963a, 0.7))
            ctx.setLineWidth(max(0.6, plaque.height * 0.07))
            ctx.addPath(CGPath(roundedRect: plaque, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil))
            ctx.strokePath()
            let label = NSAttributedString(string: "\(door.day)", attributes: [
                .font: NSFont.systemFont(ofSize: max(6, min(15, plaque.height * 0.84)), weight: .bold),
                .foregroundColor: NSColor(cgColor: AdventPaint.color(0x8a6a4a))!
            ])
            let size = label.size()
            label.draw(at: CGPoint(x: plaque.midX - size.width / 2, y: plaque.midY - size.height / 2))
            return
        }

        let pulse = ready ? 0.5 + 0.5 * sin(time * 2.4) : 0
        // A small lantern beside every door, always lit.
        let lantern = CGPoint(x: rect.maxX + rect.width * 0.32, y: rect.minY + rect.height * 0.72)
        AdventPaint.glow(ctx, at: lantern, radius: rect.width * 1.3, 0xffcf8a, 0.34)
        AdventPaint.box(ctx, CGRect(x: lantern.x - rect.width * 0.1, y: lantern.y - rect.width * 0.13,
                                    width: rect.width * 0.2, height: rect.width * 0.26), 0.6, 0xffe2ab)
        if ready {
            // Today's door has to be found, also on the far road: a warm
            // golden halo that breathes, and sparkles circling it.
            let centre = CGPoint(x: rect.midX, y: rect.midY + rect.height * 0.1)
            // Near doors are big enough on their own: the halo hugs the door
            // there instead of washing the whole house in gold.
            let reach = max(rect.width * (fine ? 1.5 : 2.8), 24)
            AdventPaint.glow(ctx, at: centre, radius: reach * (1.1 + pulse * 0.25), 0xffc455, (fine ? 0.30 : 0.40) + pulse * 0.25)
            AdventPaint.glow(ctx, at: centre, radius: reach * 0.55, 0xfff0c0, 0.55 + pulse * 0.3)
            for spark in 0..<5 {
                let angle = time * 0.9 + CGFloat(spark) * .pi * 2 / 5
                let orbit = reach * (fine ? 0.62 : 0.75) * (1 + 0.12 * sin(time * 2 + CGFloat(spark)))
                let point = CGPoint(x: centre.x + cos(angle) * orbit, y: centre.y + sin(angle) * orbit * 0.8)
                let twinkle = 0.5 + 0.5 * sin(time * 5 + CGFloat(spark) * 1.7)
                AdventPaint.star(ctx, point.x, point.y, max(2.2, reach * 0.09) * (0.6 + twinkle * 0.6), 0xffe08a,
                                 alpha: 0.5 + twinkle * 0.5)
            }
        }
        // The leaf: vertical boards with iron straps.
        ctx.saveGState()
        ctx.addPath(arch)
        ctx.clip()
        // Today's door is lit by its own glow; small far doors need more of it.
        let wood: UInt32 = ready ? blend(paint, 0xffffff, fine ? 0.16 : 0.30) : paint
        let boards = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                                colors: [AdventPaint.color(blend(wood, 0x20150f, 0.35)),
                                         AdventPaint.color(wood),
                                         AdventPaint.color(blend(wood, 0xe8cda8, 0.25))] as CFArray,
                                locations: [0, 0.5, 1])!
        ctx.drawLinearGradient(boards, start: CGPoint(x: rect.minX, y: 0), end: CGPoint(x: rect.maxX, y: 0),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        if fine {
            ctx.setStrokeColor(AdventPaint.color(0x2f2018, 0.5))
            ctx.setLineWidth(0.6)
            for plank in 1...2 {
                let x = rect.minX + rect.width * CGFloat(plank) / 3
                ctx.move(to: CGPoint(x: x, y: rect.minY))
                ctx.addLine(to: CGPoint(x: x, y: rect.maxY))
            }
            ctx.strokePath()
            ctx.setStrokeColor(AdventPaint.color(0x2b2420, 0.85))
            ctx.setLineWidth(max(0.8, rect.width * 0.07))
            for band: CGFloat in [0.26, 0.70] {
                let y = rect.minY + rect.height * band
                ctx.move(to: CGPoint(x: rect.minX + rect.width * 0.06, y: y))
                ctx.addLine(to: CGPoint(x: rect.minX + rect.width * 0.72, y: y))
            }
            ctx.strokePath()
        }
        ctx.restoreGState()
        // A broad pale frame with a fine gold line in it: the doors are the
        // calendar and have to catch the eye among logs, windows and snow.
        ctx.setStrokeColor(AdventPaint.color(blend(frame, 0xffffff, 0.3), 0.95))
        ctx.setLineWidth(max(1.0, rect.width * 0.14))
        ctx.addPath(arch)
        ctx.strokePath()
        ctx.setStrokeColor(AdventPaint.color(0xd4a23c, 0.85))
        ctx.setLineWidth(max(0.4, rect.width * 0.03))
        ctx.addPath(arch)
        ctx.strokePath()
        if ready {
            // A golden rim that breathes with the halo: this is the door.
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: rect.width * 0.25, color: AdventPaint.color(0xffd36a, 0.9))
            ctx.setStrokeColor(AdventPaint.color(0xffd977, 0.65 + pulse * 0.35))
            ctx.setLineWidth(max(0.9, rect.width * (0.07 + pulse * 0.03)))
            ctx.addPath(arch)
            ctx.strokePath()
            ctx.restoreGState()
        }
        if !fine && rect.width > 6 {
            // Far away the wreath is just a green ring with a red dot.
            ctx.setStrokeColor(AdventPaint.color(0x2f6a40, 0.95))
            ctx.setLineWidth(max(0.6, rect.width * 0.12))
            let wreath = CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.25)
            ctx.strokeEllipse(in: CGRect(x: wreath.x - rect.width * 0.2, y: wreath.y - rect.width * 0.2,
                                         width: rect.width * 0.4, height: rect.width * 0.4))
            AdventPaint.oval(ctx, wreath.x + rect.width * 0.15, wreath.y - rect.width * 0.1,
                             rect.width * 0.12, rect.width * 0.12, 0xc23b32)
        }
        if fine {
            AdventPaint.oval(ctx, rect.maxX - rect.width * 0.2, rect.minY + rect.height * 0.48,
                             rect.width * 0.12, rect.width * 0.12, 0x3a302a)
            // A wreath on every door — it is Advent, after all.
            let wreath = CGPoint(x: rect.midX, y: rect.maxY - rect.height * 0.22)
            ctx.setStrokeColor(AdventPaint.color(ready ? 0x2f6a40 : 0x27503a, 0.95))
            ctx.setLineWidth(max(0.9, rect.width * 0.09))
            ctx.strokeEllipse(in: CGRect(x: wreath.x - rect.width * 0.19, y: wreath.y - rect.width * 0.19,
                                         width: rect.width * 0.38, height: rect.width * 0.38))
            AdventPaint.oval(ctx, wreath.x + rect.width * 0.14, wreath.y - rect.width * 0.09,
                             rect.width * 0.11, rect.width * 0.11, 0xc23b32)
        }
        // The number on a little plaque over the door.
        let plaque = CGRect(x: rect.midX - rect.width * 0.58, y: rect.maxY + rect.width * 0.10,
                            width: rect.width * 1.16, height: max(10.5, rect.height * 0.45))
        // A pale halo lifts each number off the dark logs by day; after dark
        // it becomes the warm glow of a little lit sign, and a lamp over the
        // door throws light onto the snow in front. The doors are the
        // calendar: they have to be found at a glance, day and night.
        AdventPaint.glow(ctx, at: CGPoint(x: plaque.midX, y: plaque.midY), radius: plaque.width * 1.05,
                         dusk > 0.3 ? 0xffd890 : 0xfff6e0, dusk > 0.3 ? 0.42 * dusk : 0.30)
        if dusk > 0.3 {
            AdventPaint.pool(ctx, at: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.05), width: rect.width * 3.2, flat: 0.22,
                             0xffcf86, 0.38 * dusk)
            AdventPaint.glow(ctx, at: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width * 1.3, 0xffcf86, 0.18 * dusk)
        }
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -max(0.6, plaque.height * 0.06)), blur: max(1, plaque.height * 0.15),
                      color: AdventPaint.color(0x1a1210, 0.45))
        AdventPaint.box(ctx, plaque, 1.4, door.day == 24 ? (ready ? 0xffe08a : 0xe8c46a) : (ready ? 0xfff2cf : 0xfbf1d8))
        ctx.restoreGState()
        ctx.setStrokeColor(AdventPaint.color(0xc8963a, 0.95))
        ctx.setLineWidth(max(0.8, plaque.height * 0.09))
        ctx.addPath(CGPath(roundedRect: plaque, cornerWidth: 1.4, cornerHeight: 1.4, transform: nil))
        ctx.strokePath()
        let label = NSAttributedString(string: "\(door.day)", attributes: [
            .font: NSFont.systemFont(ofSize: max(7, min(17, plaque.height * 0.86)), weight: .heavy),
            .foregroundColor: NSColor(cgColor: AdventPaint.color(ready ? 0xb02a1e : 0x8e1c14))!
        ])
        let size = label.size()
        label.draw(at: CGPoint(x: plaque.midX - size.width / 2, y: plaque.midY - size.height / 2))
    }
}
