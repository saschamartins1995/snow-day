import AppKit

// Seasonal visitors live in the same coordinate system as the snow layer. They
// are deliberately sparse: a Christmas desktop should feel warm, not busy.
final class ChristmasScene {
    /// A visit is a short story: come in, flare, touch down, slide to a stop,
    /// stand a while, then dig in and climb away.
    enum SleighPhase { case cruise, approach, brake, rest, takeoff }

    private struct SantaFlight {
        let direction: CGFloat
        var phase: SleighPhase = .cruise
        var x: CGFloat
        var y: CGFloat
        var cruiseAltitude: CGFloat
        var speed: CGFloat
        var age: CGFloat = 0
        var phaseAge: CGFloat = 0
        var pitch: CGFloat = 0
        var gait: CGFloat = 0
        var gallop: CGFloat = 1
        var reach: CGFloat = 0
        var skid: CGFloat = 0
        var wave: CGFloat = 0
        var breath: CGFloat = 0
        var dropped = false
        var gaveGift = false
        var target: UInt32?
        var touchdownX: CGFloat = 0
        var restDuration: CGFloat = 6
        var climb: CGFloat = 0
    }

    /// Ten minutes between visits. The sleigh is a rare event, not a parade.
    private static let visitInterval: CGFloat = 600
    private static let visitSpread: CGFloat = 90

    /// How far out Rudolph starts his approach.
    private static let reindeerApproach: CGFloat = 210

    private static let descentRun: CGFloat = 165
    private static let brakeRun: CGFloat = 64
    /// Rudolph's visit: he flies in, lands, stands and looks at whoever is
    /// in front of the screen, then takes a run-up and jumps off the edge.
    enum ReindeerPhase { case arrive, land, stand, runup, leap, flop, climb }

    private struct Sparkle {
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var age: CGFloat = 0
        let life: CGFloat
        let size: CGFloat
    }

    private struct ReindeerVisit {
        var window: UInt32?
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat = 0
        var vy: CGFloat = 0
        var facing: CGFloat = 1
        var phase: ReindeerPhase = .arrive
        var phaseAge: CGFloat = 0
        var age: CGFloat = 0
        var anchorX: CGFloat = 0
        var standDuration: CGFloat = 10
        var clumsy = false
        /// Failed take-off attempts so far; a clumsy visit needs a few runs.
        var attempts = 0
        var maxAttempts = 0
        var headTurn: CGFloat = 0
        var headTilt: CGFloat = 0
        var lookAge: CGFloat = 0
        var blink: CGFloat = 0
        var gait: CGFloat = 0
        var gallop: CGFloat = 0
        var reach: CGFloat = 0
        var flail: CGFloat = 0
        var breath: CGFloat = 0
        var entryY: CGFloat = 0
        var landingX: CGFloat = 0
        var sparkles: [Sparkle] = []
    }

    struct Gift {
        let id: UUID
        var x: CGFloat
        var y: CGFloat
        var vy: CGFloat = -8
        var surface: UInt32?
        var anchorX: CGFloat = 0
        var landed = false
        var age: CGFloat = 0
        let look: Int
        let size: CGFloat
        let sway: CGFloat

        var reach: CGFloat { size * 0.5 + 7 }
        func contains(_ point: CGPoint) -> Bool {
            abs(point.x - x) <= reach && abs(point.y - y) <= reach
        }
    }

    private struct EmojiPop {
        let glyph: NSAttributedString
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var age: CGFloat = 0
        let duration: CGFloat
        let spin: CGFloat
    }

    private struct Burst {
        var x: CGFloat
        var y: CGFloat
        var age: CGFloat = 0
    }

    // Small, warm and recognizable at a glance. No faces, no text.
    private static let glyphs = ["🍬", "🍭", "❤️", "⭐️", "🎁", "🔔", "⛄️", "🎄", "🍪", "🧦", "🕯️", "🌟", "🎀", "🥨"]

    private var santa: SantaFlight?
    private var reindeer: ReindeerVisit?
    private(set) var gifts: [Gift] = []
    private var pops: [EmojiPop] = []
    private var bursts: [Burst] = []
    private var suspended: Set<UInt32> = []
    private var santaDelay: CGFloat = ChristmasScene.visitInterval
    private var reindeerDelay: CGFloat = 15
    private var randomState: UInt64 = 0xC0FFEE1234
    private var sparkleBudget: CGFloat = 0
    /// Gold dust streaming from the runners and the team's hooves while the
    /// sleigh is moving. Kept apart from the flight so it can fade out after
    /// the sleigh has gone.
    private var santaSparkles: [Sparkle] = []
    private var santaSparkleBudget: CGFloat = 0
    var santaSparkleCount: Int { santaSparkles.count }
    /// In Advent are the visitors unlocked yet? Outside the season both stay true.
    var allowSleigh = true
    var allowRudolph = true

    var hasSanta: Bool { santa != nil }
    var hasReindeer: Bool { reindeer != nil }
    var hasGift: Bool { !gifts.isEmpty }
    var popCount: Int { pops.count }
    var isAnimating: Bool { santa != nil || reindeer != nil || !gifts.isEmpty || !pops.isEmpty || !bursts.isEmpty || !santaSparkles.isEmpty }

    /// The seat of the sleigh, which is what the rest of the app asks about.
    func santaPosition(in bounds: CGRect) -> CGPoint? {
        guard let flight = santa else { return nil }
        return CGPoint(x: flight.x, y: flight.y + 14)
    }

    var sleighPhase: SleighPhase? { santa?.phase }
    var sleighSpeed: CGFloat { santa?.speed ?? 0 }
    var sleighDirection: CGFloat { santa?.direction ?? 0 }
    var reindeerPhase: ReindeerPhase? { reindeer?.phase }
    var reindeerHeadTurn: CGFloat { reindeer?.headTurn ?? 0 }
    var reindeerPoint: CGPoint? { reindeer.map { CGPoint(x: $0.x, y: $0.y) } }
    var reindeerIsClumsy: Bool { reindeer?.clumsy ?? false }
    var reindeerSparkles: Int { reindeer?.sparkles.count ?? 0 }
    /// Where the runners meet the snow.
    var sleighContact: CGPoint? { santa.map { CGPoint(x: $0.x, y: $0.y) } }
    var sleighIsGrounded: Bool {
        guard let phase = santa?.phase else { return false }
        return phase == .brake || phase == .rest
    }

    func reset() {
        santa = nil
        reindeer = nil
        gifts.removeAll()
        pops.removeAll()
        bursts.removeAll()
        santaDelay = Self.visitInterval
        reindeerDelay = 15
    }

    // The menu action is a gentle nudge. It keeps the naturally scheduled events
    // rare, while giving the person using the app a way to see the details now.
    func inviteNextMoment() {
        santaDelay = min(santaDelay, 0.05)
        reindeerDelay = min(reindeerDelay, 1.15)
    }

    private func random() -> CGFloat {
        randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(randomState >> 32) / CGFloat(UInt32.max)
    }

    // MARK: - Interaction

    /// A gift only answers the pointer where it is actually drawn: on a visible
    /// sill, never under a working window and never while its window is hidden.
    func gift(at point: CGPoint, visible: (CGPoint) -> Bool) -> UUID? {
        gifts.last { gift in
            if let id = gift.surface, suspended.contains(id) { return false }
            return gift.contains(point) && visible(CGPoint(x: gift.x, y: gift.y))
        }?.id
    }

    @discardableResult func open(_ id: UUID) -> Bool {
        guard let index = gifts.firstIndex(where: { $0.id == id }) else { return false }
        let gift = gifts.remove(at: index)
        bursts.append(Burst(x: gift.x, y: gift.y))
        let count = 5 + Int(random() * 3)
        for item in 0..<count {
            let spread = (CGFloat(item) + 0.5) / CGFloat(count)
            let angle = (.pi * 0.18) + spread * (.pi * 0.64) + (random() - 0.5) * 0.22
            let speed = 125 + random() * 95
            let size = 15 + random() * 11
            let glyph = NSAttributedString(string: Self.glyphs[Int(random() * CGFloat(Self.glyphs.count)) % Self.glyphs.count],
                                           attributes: [.font: NSFont.systemFont(ofSize: size)])
            pops.append(EmojiPop(glyph: glyph, x: gift.x + (random() - 0.5) * 6, y: gift.y + 2,
                                 vx: cos(angle) * speed * (random() < 0.5 ? -1 : 1), vy: sin(angle) * speed,
                                 duration: 1.25 + random() * 0.55, spin: (random() - 0.5) * 4.2))
        }
        return true
    }

    // MARK: - Simulation

    func step(_ dt: CGFloat, bounds: CGRect, ledges: [UInt32:Ledge], suspended: Set<UInt32>,
              groundHeight: (CGFloat) -> CGFloat = { _ in 0.5 }) {
        guard dt > 0 else { return }
        self.suspended = suspended
        stepSanta(dt, bounds: bounds, ledges: ledges)
        stepSantaSparkles(dt, bounds: bounds)
        stepReindeer(dt, bounds: bounds, ledges: ledges)
        stepGifts(dt, bounds: bounds, ledges: ledges, groundHeight: groundHeight)
        stepPops(dt, bounds: bounds)
    }

    private func stepSanta(_ dt: CGFloat, bounds: CGRect, ledges: [UInt32:Ledge]) {
        guard var flight = santa else {
            santaDelay -= dt
            guard allowSleigh else { santaDelay = max(santaDelay, 20); return }
            guard santaDelay <= 0, bounds.width >= 180, bounds.height >= 160 else { return }
            // Rudolph leads the team, so the sleigh waits while he is out alone.
            guard reindeer == nil else { santaDelay = 8; return }
            let direction: CGFloat = random() < 0.5 ? 1 : -1
            var altitude = bounds.height * (0.56 + random() * 0.22)
            var target: (UInt32, CGFloat)?
            // Pick the sill first and then come in above it. Choosing a height
            // at random would leave the sleigh below most window edges.
            if let fit = landingFit(direction: direction, ledges: ledges) {
                let approachHeight = fit.lip + 88 + random() * 36
                if approachHeight <= bounds.height - 24 {
                    altitude = approachHeight
                    target = (fit.id, fit.touchdownX)
                }
            }
            var next = SantaFlight(direction: direction,
                                   x: direction > 0 ? -SleighArt.noseX - 30 : bounds.maxX + SleighArt.noseX + 30,
                                   y: altitude, cruiseAltitude: altitude, speed: 118 + random() * 26)
            next.restDuration = 5.5 + random() * 3
            next.target = target?.0
            next.touchdownX = target?.1 ?? 0
            santa = next
            santaDelay = Self.visitInterval - Self.visitSpread / 2 + random() * Self.visitSpread
            return
        }
        flight.age += dt
        flight.phaseAge += dt
        flight.gait += dt * (6 + flight.gallop * 13)

        // A sill that disappears or gets covered ends the visit early.
        if let id = flight.target, flight.phase != .cruise, flight.phase != .takeoff,
           ledges[id] == nil || suspended.contains(id) {
            flight.target = nil
            enter(.takeoff, &flight)
        }
        let groundY = flight.target.flatMap { ledges[$0] }.map { $0.height(at: flight.x) }

        switch flight.phase {
        case .cruise:
            flight.x += flight.direction * flight.speed * dt
            flight.y = flight.cruiseAltitude + sin(flight.age * 1.55) * 7
            flight.pitch += (0 - flight.pitch) * min(1, dt * 4)
            flight.reach += (0 - flight.reach) * min(1, dt * 4)
            flight.gallop = 1
            if flight.target != nil, (flight.touchdownX - flight.x) * flight.direction <= Self.descentRun {
                enter(.approach, &flight)
            }
        case .approach:
            flight.x += flight.direction * flight.speed * dt
            flight.speed += (88 - flight.speed) * min(1, dt * 1.6)
            let remaining = max(0, (flight.touchdownX - flight.x) * flight.direction)
            let progress = 1 - min(1, remaining / Self.descentRun)
            if let groundY {
                // Ease down, then flare: the last stretch is nearly level.
                let drop = flight.cruiseAltitude - groundY
                flight.y = groundY + drop * pow(1 - progress, 1.9)
                if progress >= 0.995 || flight.y <= groundY + 0.4 {
                    flight.y = groundY
                    enter(.brake, &flight)
                    flight.skid = 1
                    flight.pitch = -0.09
                }
            } else {
                flight.target = nil
                enter(.cruise, &flight)
            }
            flight.pitch += (0.17 + 0.12 * progress - flight.pitch) * min(1, dt * 5)
            flight.reach += (min(1, progress * 1.5) - flight.reach) * min(1, dt * 6)
        case .brake:
            flight.speed = max(0, flight.speed - 210 * dt) * exp(-1.2 * dt)
            flight.x += flight.direction * flight.speed * dt
            if let groundY { flight.y = groundY }
            flight.skid = min(1, flight.speed / 70)
            // The body rocks once on its runners and settles.
            flight.pitch = -0.085 * exp(-flight.phaseAge * 3.1) * cos(flight.phaseAge * 15)
            flight.gallop += (0.42 - flight.gallop) * min(1, dt * 5)
            flight.reach += (0 - flight.reach) * min(1, dt * 3.5)
            if flight.speed < 5 {
                flight.speed = 0
                enter(.rest, &flight)
            }
        case .rest:
            flight.speed = 0
            flight.skid = max(0, flight.skid - dt * 2.5)
            if let groundY { flight.y = groundY }
            flight.gallop += (0.07 - flight.gallop) * min(1, dt * 3)
            flight.pitch += (0 - flight.pitch) * min(1, dt * 4)
            flight.breath += (1 - flight.breath) * min(1, dt * 1.5)
            let waving = flight.phaseAge > 1.1 && flight.phaseAge < 3.4
            flight.wave += ((waving ? 1 : 0) - flight.wave) * min(1, dt * 4.5)
            if !flight.gaveGift, flight.phaseAge > 1.3, gifts.count < 3 {
                flight.gaveGift = true
                // Set down clear of the sleigh's back, not half inside it.
                dropGift(at: CGPoint(x: flight.x + flight.direction * (SleighArt.tailX - 26), y: flight.y + 30))
            }
            if flight.phaseAge > flight.restDuration { enter(.takeoff, &flight) }
        case .takeoff:
            flight.breath += (0 - flight.breath) * min(1, dt * 3)
            flight.wave += (0 - flight.wave) * min(1, dt * 6)
            flight.gallop += (1 - flight.gallop) * min(1, dt * 6)
            // Dig in first, then pull away.
            if flight.phaseAge < 0.65 {
                flight.pitch += (-0.06 - flight.pitch) * min(1, dt * 6)
                flight.skid = max(flight.skid, (0.65 - flight.phaseAge) * 0.9)
            } else {
                flight.speed = min(310, flight.speed + 250 * dt)
                flight.x += flight.direction * flight.speed * dt
                flight.skid = max(0, flight.skid - dt * 2.2)
                let climbRate = max(0, flight.speed - 80) * 0.78
                flight.climb += climbRate * dt
                flight.pitch += (0.30 - flight.pitch) * min(1, dt * 3)
            }
            if let groundY { flight.y = groundY + flight.climb } else { flight.y += flight.climb * 0 }
            if flight.target == nil { flight.y += max(0, flight.speed - 80) * 0.78 * dt }
        }

        if !flight.dropped, flight.phase == .cruise || flight.phase == .approach, gifts.count < 3 {
            // The sack rides behind the sleigh, so a present leaves from there.
            let sack = CGPoint(x: flight.x - flight.direction * 32, y: flight.y + 24)
            if hasDropTarget(under: sack, ledges: ledges) {
                flight.dropped = true
                dropGift(at: sack)
            }
        }

        let gone = flight.direction > 0 ? flight.x + SleighArt.tailX > bounds.maxX + 40
                                        : flight.x - SleighArt.tailX < bounds.minX - 40
        santa = gone || flight.y > bounds.maxY + 160 ? nil : flight
    }

    private func stepSantaSparkles(_ dt: CGFloat, bounds: CGRect) {
        if let flight = santa, flight.speed > 25,
           flight.x > bounds.minX - 200, flight.x < bounds.maxX + 200, flight.y < bounds.maxY + 60 {
            santaSparkleBudget += dt * min(130, 45 + flight.speed * 0.4)
            while santaSparkleBudget >= 1, santaSparkles.count < 280 {
                santaSparkleBudget -= 1
                // Half from the runners, half from the hooves of the team.
                let fromHooves = random() < 0.55
                let localX: CGFloat = fromHooves
                    ? SleighArt.reindeerOffsets[Int(random() * 3) % 3] + (random() - 0.5) * 16
                    : -30 + random() * 52
                let localY: CGFloat = fromHooves ? 1 + random() * 4 : 0.5 + random() * 2
                let lift = sin(flight.pitch) * localX
                santaSparkles.append(Sparkle(x: flight.x + flight.direction * localX, y: flight.y + localY + lift,
                                             vx: -flight.direction * (10 + random() * 30),
                                             vy: -8 + random() * 24,
                                             life: 0.7 + random() * 1.0,
                                             size: 0.9 + random() * 1.9))
            }
        } else {
            santaSparkleBudget = 0
        }
        for index in santaSparkles.indices {
            santaSparkles[index].age += dt
            santaSparkles[index].vy -= 38 * dt
            santaSparkles[index].x += santaSparkles[index].vx * dt
            santaSparkles[index].y += santaSparkles[index].vy * dt
            santaSparkles[index].vx *= exp(-1.4 * dt)
        }
        santaSparkles.removeAll { $0.age >= $0.life }
    }

    private func enter(_ phase: SleighPhase, _ flight: inout SantaFlight) {
        flight.phase = phase
        flight.phaseAge = 0
    }

    /// A sill can hold the rig only if the whole team fits on it with room to
    /// slide out the landing.
    private func landingFit(direction: CGFloat,
                            ledges: [UInt32:Ledge]) -> (id: UInt32, touchdownX: CGFloat, lip: CGFloat)? {
        let margin: CGFloat = 12
        let candidates = ledges.compactMap { id, ledge -> (id: UInt32, touchdownX: CGFloat, lip: CGFloat)? in
            guard !suspended.contains(id),
                  ledge.exposed.filter({ $0 }).count >= max(6, ledge.exposed.count * 3 / 4) else { return nil }
            let low: CGFloat
            let high: CGFloat
            if direction > 0 {
                low = ledge.frame.minX + margin - SleighArt.tailX
                high = ledge.frame.maxX - margin - SleighArt.noseX - Self.brakeRun
            } else {
                low = ledge.frame.minX + margin + SleighArt.noseX + Self.brakeRun
                high = ledge.frame.maxX - margin + SleighArt.tailX
            }
            guard low <= high else { return nil }
            return (id, (low + high) / 2, ledge.lip)
        }
        // The highest sill that fits: landing on the front window looks right.
        return candidates.max { $0.lip < $1.lip }
    }

    /// A present is only let go where it can land in plain sight: on an exposed
    /// window edge below the sleigh, wide enough to actually hold it.
    private func hasDropTarget(under point: CGPoint, ledges: [UInt32:Ledge]) -> Bool {
        guard !gifts.contains(where: { abs($0.x - point.x) < 34 }) else { return false }
        return ledges.contains { id, ledge in
            guard !suspended.contains(id), ledge.frame.width >= 58, ledge.lip < point.y - 24,
                  point.x >= ledge.frame.minX + 14, point.x <= ledge.frame.maxX - 14,
                  !ledge.exposed.isEmpty else { return false }
            let index = min(ledge.exposed.count - 1, max(0, Int((point.x - ledge.frame.minX) / 8)))
            return ledge.exposed[index]
        }
    }

    /// Santa no longer drops presents: on request they were taken out, the
    /// window edges stay clear. The gift code stays for the tests.
    var dropsGifts = false

    private func dropGift(at point: CGPoint) {
        guard dropsGifts else { return }
        gifts.append(Gift(id: UUID(), x: point.x, y: point.y, surface: nil,
                          look: Int(random() * 4) % 4, size: 17 + random() * 4, sway: random() * 6.2))
    }

    private func stepReindeer(_ dt: CGFloat, bounds: CGRect, ledges: [UInt32:Ledge]) {
        guard var visit = reindeer else {
            reindeerDelay -= dt
            guard allowRudolph else { reindeerDelay = max(reindeerDelay, 12); return }
            guard reindeerDelay <= 0 else { return }
            // He cannot visit alone while he is pulling the sleigh.
            guard santa == nil else { reindeerDelay = 12; return }
            guard let spot = reindeerSpot(in: bounds, ledges: ledges) else {
                reindeerDelay = 12
                return
            }
            reindeer = spot
            return
        }
        visit.age += dt
        visit.phaseAge += dt
        visit.gait += dt * (3 + visit.gallop * 15)

        let grounded = visit.phase == .land || visit.phase == .stand || visit.phase == .runup
        let ledge = visit.window.flatMap { ledges[$0] }
        if visit.window.map(suspended.contains) == true || (grounded && ledge == nil) {
            // The sill vanished from under him: off he goes, right now.
            visit.window = nil
            visit.vy = 150
            visit.vx = visit.facing * 120
            enterReindeer(.leap, &visit)
        }

        switch visit.phase {
        case .arrive:
            visit.x += visit.vx * dt
            visit.gallop = 0.85
            let remaining = max(0, (visit.landingX - visit.x) * visit.facing)
            let progress = 1 - min(1, remaining / Self.reindeerApproach)
            visit.reach = min(1, progress * 1.6)
            if let ledge {
                let target = ledge.height(at: visit.x)
                visit.y = target + (visit.entryY - target) * pow(1 - progress, 1.8)
                if progress >= 0.995 {
                    visit.y = target
                    visit.anchorX = visit.x - ledge.frame.minX
                    enterReindeer(.land, &visit)
                }
            }
            emitSparkles(&visit, rate: 34 * dt, spread: 26, in: bounds)
        case .land:
            visit.vx = 0
            if let ledge {
                visit.x = ledge.frame.minX + visit.anchorX
                visit.y = ledge.height(at: visit.x)
            }
            visit.gallop += (0.08 - visit.gallop) * min(1, dt * 6)
            visit.reach += (0 - visit.reach) * min(1, dt * 7)
            // A clumsy arrival skids and scrambles before it settles.
            visit.flail = visit.clumsy ? max(0, 1 - visit.phaseAge / 0.55) : 0
            if visit.phaseAge > (visit.clumsy ? 0.75 : 0.3) { enterReindeer(.stand, &visit) }
        case .stand:
            if let ledge {
                visit.x = ledge.frame.minX + visit.anchorX
                visit.y = ledge.height(at: visit.x)
            }
            visit.gallop += (0.06 - visit.gallop) * min(1, dt * 3)
            visit.flail = 0
            visit.breath += (1 - visit.breath) * min(1, dt * 1.6)
            // Look out of the screen for most of the stop. The turn eases in and
            // out and the head tips over as it comes round, which is what makes
            // it read as a look rather than a slide.
            let looking = visit.phaseAge > 1.5 && visit.phaseAge < visit.standDuration - 1.9
            visit.lookAge += looking ? dt : -dt * 1.6
            visit.lookAge = min(1, max(0, visit.lookAge))
            let eased = visit.lookAge * visit.lookAge * (3 - 2 * visit.lookAge)
            visit.headTurn = eased
            // The tilt peaks while he is turning and settles once he is looking.
            let turning = 1 - abs(eased * 2 - 1)
            visit.headTilt = turning * 0.19 + eased * 0.07
            let beat = visit.age.truncatingRemainder(dividingBy: 2.4)
            visit.blink = beat < 0.12 || (eased > 0.8 && beat > 1.1 && beat < 1.2) ? 1 : 0
            if visit.phaseAge > visit.standDuration { enterReindeer(.runup, &visit) }
        case .runup:
            visit.headTurn += (0 - visit.headTurn) * min(1, dt * 8)
            visit.headTilt += (0 - visit.headTilt) * min(1, dt * 8)
            visit.breath += (0 - visit.breath) * min(1, dt * 3)
            visit.gallop += (1 - visit.gallop) * min(1, dt * 7)
            visit.vx += visit.facing * 300 * dt
            visit.vx = min(215, max(-215, visit.vx))
            visit.x += visit.vx * dt
            if let ledge {
                visit.y = ledge.height(at: visit.x)
                visit.anchorX = visit.x - ledge.frame.minX
                let failing = visit.attempts < visit.maxAttempts
                // A doomed attempt never reaches the edge: he gives it everything
                // halfway along the sill and comes straight back down.
                let edge = visit.facing > 0 ? ledge.frame.maxX - 8 : ledge.frame.minX + 8
                let reachedEdge = (visit.x - edge) * visit.facing >= 0
                if failing ? (visit.phaseAge > 0.72 || reachedEdge) : (reachedEdge || visit.phaseAge > 1.5) {
                    visit.vy = failing ? 118 : 178
                    visit.reach = 1
                    enterReindeer(.leap, &visit)
                }
            }
            emitSparkles(&visit, rate: 26 * dt, spread: 20, in: bounds)
        case .leap:
            let failing = visit.attempts < visit.maxAttempts
            visit.vy -= 300 * dt
            visit.x += visit.vx * dt
            visit.y += visit.vy * dt
            visit.gallop = 0.7
            visit.reach += (0.35 - visit.reach) * min(1, dt * 3)
            emitSparkles(&visit, rate: 30 * dt, spread: 30, in: bounds)
            if failing, let ledge {
                // Gravity wins: back down onto the sill he came from.
                let surface = ledge.height(at: visit.x)
                if visit.vy < 0, visit.y <= surface {
                    visit.y = surface
                    visit.vx *= 0.2
                    enterReindeer(.flop, &visit)
                }
            } else if visit.phaseAge > 0.45 {
                enterReindeer(.climb, &visit)
            }
        case .flop:
            // Landed short, scrambles, shakes it off and turns for another run.
            visit.vx *= exp(-6 * dt)
            visit.x += visit.vx * dt
            if let ledge {
                visit.y = ledge.height(at: visit.x)
                visit.anchorX = visit.x - ledge.frame.minX
            }
            visit.flail = max(0, 1 - visit.phaseAge / 0.45)
            visit.gallop += (0.25 - visit.gallop) * min(1, dt * 5)
            visit.reach += (0 - visit.reach) * min(1, dt * 5)
            if visit.phaseAge > 0.85 {
                visit.attempts += 1
                visit.vx = 0
                // Turn around if there is no room left ahead.
                if let ledge {
                    let ahead = visit.facing > 0 ? ledge.frame.maxX - visit.x : visit.x - ledge.frame.minX
                    if ahead < 110 { visit.facing = -visit.facing }
                }
                enterReindeer(.runup, &visit)
            }
        case .climb:
            visit.flail += (0 - visit.flail) * min(1, dt * 6)
            visit.gallop = 1
            visit.vy = min(230, visit.vy + 150 * dt)
            visit.vx += visit.facing * 110 * dt
            visit.x += visit.vx * dt
            visit.y += visit.vy * dt
            emitSparkles(&visit, rate: 30 * dt, spread: 26, in: bounds)
        }

        stepSparkles(&visit, dt)
        let offscreen = visit.x < bounds.minX - 90 || visit.x > bounds.maxX + 90 || visit.y > bounds.maxY + 90
        if offscreen, visit.sparkles.isEmpty {
            reindeer = nil
            reindeerDelay = 30 + random() * 38
        } else {
            reindeer = visit
        }
    }

    private func enterReindeer(_ phase: ReindeerPhase, _ visit: inout ReindeerVisit) {
        visit.phase = phase
        visit.phaseAge = 0
    }

    /// Picks a sill and the side he comes in from.
    private func reindeerSpot(in bounds: CGRect, ledges: [UInt32:Ledge]) -> ReindeerVisit? {
        let identifiers = ledges.compactMap { id, ledge -> UInt32? in
            guard ledge.frame.width >= 150, !suspended.contains(id),
                  ledge.exposed.filter({ $0 }).count >= max(5, ledge.exposed.count / 2) else { return nil }
            return id
        }.sorted()
        guard !identifiers.isEmpty else { return nil }
        let id = identifiers[min(identifiers.count - 1, Int(random() * CGFloat(identifiers.count)))]
        guard let ledge = ledges[id] else { return nil }
        let facing: CGFloat = random() < 0.5 ? 1 : -1
        // Land far enough from the far edge to leave room for the run-up.
        let inset: CGFloat = 46
        let landingX = facing > 0 ? ledge.frame.minX + inset
                                  : ledge.frame.maxX - inset
        var visit = ReindeerVisit(window: id,
                                  x: landingX - facing * Self.reindeerApproach,
                                  y: ledge.lip + 96)
        visit.facing = facing
        visit.vx = facing * 132
        visit.entryY = ledge.lip + 96
        visit.landingX = landingX
        visit.standDuration = 9.5 + random() * 1.6
        visit.clumsy = random() < 0.42
        visit.maxAttempts = visit.clumsy ? (random() < 0.5 ? 2 : 3) : 0
        return visit
    }

    private func emitSparkles(_ visit: inout ReindeerVisit, rate: CGFloat, spread: CGFloat, in bounds: CGRect) {
        // Off the screen he stops sparkling, otherwise the trail never drains
        // and the visit would never end.
        guard visit.x > bounds.minX - 50, visit.x < bounds.maxX + 50, visit.y < bounds.maxY + 50 else { return }
        sparkleBudget += rate
        while sparkleBudget >= 1, visit.sparkles.count < 70 {
            sparkleBudget -= 1
            let hoof = CGPoint(x: visit.x - visit.facing * (2 + random() * 9), y: visit.y + 0.5 + random() * 3)
            visit.sparkles.append(Sparkle(x: hoof.x, y: hoof.y,
                                          vx: -visit.facing * (8 + random() * spread),
                                          vy: -6 + random() * 26,
                                          life: 0.5 + random() * 0.65,
                                          size: 0.7 + random() * 1.5))
        }
    }

    private func stepSparkles(_ visit: inout ReindeerVisit, _ dt: CGFloat) {
        for index in visit.sparkles.indices {
            visit.sparkles[index].age += dt
            visit.sparkles[index].vy -= 42 * dt
            visit.sparkles[index].x += visit.sparkles[index].vx * dt
            visit.sparkles[index].y += visit.sparkles[index].vy * dt
            visit.sparkles[index].vx *= exp(-1.6 * dt)
        }
        visit.sparkles.removeAll { $0.age >= $0.life }
    }

    private func stepGifts(_ dt: CGFloat, bounds: CGRect, ledges: [UInt32:Ledge],
                           groundHeight: (CGFloat) -> CGFloat) {
        guard !gifts.isEmpty else { return }
        for index in gifts.indices {
            var gift = gifts[index]
            gift.age += dt
            if let id = gift.surface {
                // A hidden window keeps its present frozen, exactly like its snow.
                if suspended.contains(id) { gifts[index] = gift; continue }
                guard let ledge = ledges[id] else {
                    gift.surface = nil
                    gift.landed = false
                    gift.vy = -12
                    gifts[index] = gift
                    continue
                }
                gift.x = min(ledge.frame.maxX, max(ledge.frame.minX, ledge.frame.minX + gift.anchorX))
                gift.y = ledge.height(at: gift.x) + gift.size * 0.5
                gifts[index] = gift
                continue
            }
            // Under its little parachute a present drifts rather than falls.
            gift.vy += (-36 - gift.vy) * min(1, dt * 3.2)
            gift.y += gift.vy * dt
            gift.x += sin(gift.age * 1.9 + gift.sway) * 17 * dt
            gift.x = min(bounds.maxX - gift.size, max(bounds.minX + gift.size, gift.x))
            let bottom = gift.y - gift.size * 0.5
            let landings = ledges.filter { id, ledge in
                !suspended.contains(id) && gift.x >= ledge.frame.minX && gift.x <= ledge.frame.maxX
                    && bottom <= ledge.height(at: gift.x) && ledge.lip >= bottom - 30
            }
            if let landing = landings.max(by: { $0.value.lip < $1.value.lip }) {
                gift.surface = landing.key
                gift.anchorX = gift.x - landing.value.frame.minX
                gift.y = landing.value.height(at: gift.x) + gift.size * 0.5
                gift.landed = true
                gift.vy = 0
                gift.age = 0
            } else if bottom <= groundHeight(gift.x) {
                gift.y = groundHeight(gift.x) + gift.size * 0.5
                gift.landed = true
                gift.vy = 0
                gift.age = 0
            }
            gifts[index] = gift
        }
    }

    private func stepPops(_ dt: CGFloat, bounds: CGRect) {
        for index in bursts.indices { bursts[index].age += dt }
        bursts.removeAll { $0.age >= 0.45 }
        guard !pops.isEmpty else { return }
        for index in pops.indices {
            pops[index].age += dt
            pops[index].vy -= 540 * dt
            pops[index].vx *= exp(-1.1 * dt)
            pops[index].x += pops[index].vx * dt
            pops[index].y += pops[index].vy * dt
        }
        pops.removeAll { $0.age >= $0.duration || $0.y < bounds.minY - 40 }
    }

    // MARK: - Drawing

    func draw(in ctx: CGContext, bounds: CGRect, ledges: [UInt32:Ledge]) {
        for sparkle in santaSparkles {
            let fade = 1 - sparkle.age / sparkle.life
            let twinkle = 0.7 + 0.3 * sin(sparkle.age * 22 + sparkle.size * 9)
            let radius = sparkle.size * (0.45 + fade * 0.75)
            // A soft glow that fades out, not a flat disc: flat discs read
            // as grey bubbles over a dark desktop.
            sparkleGlow(ctx, at: CGPoint(x: sparkle.x, y: sparkle.y), radius: radius * 2.4, strength: 0.35, fade: fade)
            dot(ctx, sparkle.x, sparkle.y, radius * twinkle,
                NSColor(srgbRed: 1, green: 0.93, blue: 0.62, alpha: 0.95 * fade))
            // Now and then a sparkle flashes as a little four-point star.
            if sparkle.size > 2.2, twinkle > 0.92 {
                ctx.setStrokeColor(NSColor(srgbRed: 1, green: 0.97, blue: 0.8, alpha: 0.8 * fade).cgColor)
                ctx.setLineWidth(0.6)
                let arm = radius * 2.4
                ctx.move(to: CGPoint(x: sparkle.x - arm, y: sparkle.y)); ctx.addLine(to: CGPoint(x: sparkle.x + arm, y: sparkle.y))
                ctx.move(to: CGPoint(x: sparkle.x, y: sparkle.y - arm)); ctx.addLine(to: CGPoint(x: sparkle.x, y: sparkle.y + arm))
                ctx.strokePath()
            }
        }
        if let flight = santa { drawSanta(flight, in: ctx, bounds: bounds) }
        if let visit = reindeer, visit.window.map(suspended.contains) != true { drawReindeer(visit, in: ctx) }
        for gift in gifts where !(gift.surface.map(suspended.contains) ?? false) { drawGift(gift, in: ctx) }
        for burst in bursts { drawBurst(burst, in: ctx) }
        for pop in pops { drawPop(pop, in: ctx) }
    }

    private func fill(_ ctx: CGContext, _ rect: CGRect, _ color: NSColor, radius: CGFloat = 0) {
        ctx.setFillColor(color.cgColor)
        if radius > 0 { ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.fillPath() }
        else { ctx.fill(rect) }
    }
    private func dot(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: x-radius, y: y-radius, width: radius*2, height: radius*2))
    }

    private func drawSanta(_ flight: SantaFlight, in ctx: CGContext, bounds: CGRect) {
        var pose = SleighPose()
        pose.pitch = flight.pitch
        pose.gait = flight.gait
        pose.gallop = flight.gallop
        pose.reach = flight.reach
        pose.skid = flight.skid
        pose.wave = flight.wave
        pose.breath = flight.breath
        pose.bells = min(1, 0.22 + flight.gallop * 0.9)
        pose.age = flight.age
        ctx.saveGState()
        ctx.translateBy(x: flight.x, y: flight.y)
        ctx.scaleBy(x: flight.direction, y: 1)
        SleighArt.draw(pose, in: ctx)
        ctx.restoreGState()
    }

    private func drawReindeer(_ visit: ReindeerVisit, in ctx: CGContext) {
        for sparkle in visit.sparkles {
            let fade = 1 - sparkle.age / sparkle.life
            let radius = sparkle.size * (0.45 + fade * 0.75)
            sparkleGlow(ctx, at: CGPoint(x: sparkle.x, y: sparkle.y), radius: radius * 2.2, strength: 0.3, fade: fade)
            dot(ctx, sparkle.x, sparkle.y, radius,
                NSColor(srgbRed: 1, green: 0.93, blue: 0.62, alpha: 0.92 * fade))
        }
        var pose = ReindeerPose()
        pose.gait = visit.gait
        pose.gallop = visit.gallop
        pose.reach = visit.reach
        pose.headTurn = visit.headTurn
        pose.headTilt = visit.headTilt
        pose.flail = visit.flail
        pose.breath = visit.breath
        pose.blink = visit.blink
        pose.bells = min(1, 0.3 + visit.gallop)
        pose.redNose = true
        pose.harnessed = false
        pose.age = visit.age
        pose.wobble = sin(visit.age * 2.4) * 0.3
        ctx.saveGState()
        ctx.translateBy(x: visit.x, y: visit.y)
        ctx.scaleBy(x: visit.facing, y: 1)
        SleighArt.drawReindeer(pose, in: ctx)
        ctx.restoreGState()
    }

    private static let wrappings: [(paper: NSColor, band: NSColor)] = [
        (NSColor(srgbRed: 0.74, green: 0.13, blue: 0.21, alpha: 1), NSColor(srgbRed: 1, green: 0.82, blue: 0.36, alpha: 1)),
        (NSColor(srgbRed: 0.16, green: 0.42, blue: 0.32, alpha: 1), NSColor(srgbRed: 1, green: 0.95, blue: 0.86, alpha: 1)),
        (NSColor(srgbRed: 0.20, green: 0.38, blue: 0.62, alpha: 1), NSColor(srgbRed: 0.88, green: 0.93, blue: 0.99, alpha: 1)),
        (NSColor(srgbRed: 0.49, green: 0.26, blue: 0.52, alpha: 1), NSColor(srgbRed: 1, green: 0.84, blue: 0.47, alpha: 1))
    ]

    private func drawGift(_ gift: Gift, in ctx: CGContext) {
        let wrapping = Self.wrappings[gift.look % Self.wrappings.count]
        let size = gift.size
        let half = size * 0.5
        let bob = gift.landed ? sin(gift.age * 2.3) * 0.7 : 0
        let tilt = gift.landed ? sin(gift.age * 1.7) * 0.015 : sin(gift.age * 1.9 + gift.sway) * 0.11
        ctx.saveGState()
        ctx.translateBy(x: gift.x, y: gift.y + bob)
        ctx.rotate(by: tilt)
        if !gift.landed { drawParachute(size: size, age: gift.age, in: ctx) }

        // A landed present quietly asks to be opened: two small sparkles, no
        // halo. A translucent disc only reads as a grey smudge on a desktop.
        if gift.landed {
            let pulse = 0.45 + 0.55 * (0.5 + 0.5 * sin(gift.age * 2.4))
            ctx.setStrokeColor(NSColor(srgbRed: 1, green: 0.92, blue: 0.66, alpha: pulse * 0.9).cgColor)
            ctx.setLineCap(.round)
            for (index, point) in [CGPoint(x: half * 1.16, y: half * 1.02),
                                   CGPoint(x: -half * 1.05, y: half * 0.24)].enumerated() {
                let arm = (index == 0 ? 3.0 : 2.1) * (0.6 + 0.4 * pulse)
                ctx.setLineWidth(index == 0 ? 1.15 : 0.9)
                ctx.move(to: CGPoint(x: point.x - arm, y: point.y)); ctx.addLine(to: CGPoint(x: point.x + arm, y: point.y))
                ctx.move(to: CGPoint(x: point.x, y: point.y - arm)); ctx.addLine(to: CGPoint(x: point.x, y: point.y + arm))
                ctx.strokePath()
            }
        }
        ctx.setFillColor(NSColor(srgbRed: 0.12, green: 0.19, blue: 0.30, alpha: 0.22).cgColor)
        ctx.fillEllipse(in: CGRect(x: -half * 1.05, y: -half - 2.2, width: size * 1.05, height: 4.4))

        let body = CGRect(x: -half, y: -half, width: size, height: size * 0.92)
        let paper = CGPath(roundedRect: body, cornerWidth: 2.2, cornerHeight: 2.2, transform: nil)
        ctx.saveGState()
        ctx.addPath(paper); ctx.clip()
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [wrapping.paper.blended(withFraction: 0.26, of: .black)!.cgColor,
                     wrapping.paper.cgColor,
                     wrapping.paper.blended(withFraction: 0.26, of: .white)!.cgColor] as CFArray,
            locations: [0, 0.58, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: -half, y: -half),
                               end: CGPoint(x: half, y: half), options: [.drawsAfterEndLocation, .drawsBeforeStartLocation])
        // Lid shadow gives the box a top instead of a flat square.
        fill(ctx, CGRect(x: -half, y: half * 0.62, width: size, height: half * 0.30),
             NSColor(white: 0, alpha: 0.13))
        ctx.restoreGState()

        fill(ctx, CGRect(x: -half * 0.19, y: -half, width: half * 0.38, height: size * 0.92), wrapping.band)
        fill(ctx, CGRect(x: -half, y: half * 0.10, width: size, height: half * 0.34), wrapping.band)
        ctx.setStrokeColor(NSColor(white: 0, alpha: 0.20).cgColor)
        ctx.setLineWidth(0.6)
        ctx.addPath(paper); ctx.strokePath()

        // Bow: two loops and a knot, drawn small enough to stay crisp.
        let loop = size * 0.30
        for direction: CGFloat in [-1, 1] {
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: half * 0.90))
            path.addCurve(to: CGPoint(x: direction * loop * 1.18, y: half * 1.06),
                          control1: CGPoint(x: direction * loop * 0.25, y: half * 1.72),
                          control2: CGPoint(x: direction * loop * 1.42, y: half * 1.62))
            path.addQuadCurve(to: CGPoint(x: 0, y: half * 0.90), control: CGPoint(x: direction * loop * 0.52, y: half * 0.78))
            ctx.addPath(path)
            ctx.setFillColor(wrapping.band.cgColor)
            ctx.fillPath()
        }
        dot(ctx, 0, half * 1.00, size * 0.11, wrapping.band.blended(withFraction: 0.22, of: .white)!)
        dot(ctx, -half * 0.42, half * 0.38, size * 0.055, NSColor(white: 1, alpha: 0.55))
        ctx.restoreGState()
    }

    private func drawParachute(size: CGFloat, age: CGFloat, in ctx: CGContext) {
        let span = size * 1.08
        let rise = size * 1.35
        let shoulder = size * 1.30
        let swing = sin(age * 1.9) * 0.05
        ctx.saveGState()
        ctx.rotate(by: swing)
        // Cords first, so the canopy sits on top of them.
        ctx.setStrokeColor(NSColor(srgbRed: 0.45, green: 0.30, blue: 0.24, alpha: 0.85).cgColor)
        ctx.setLineWidth(0.7)
        for dx: CGFloat in [-span * 0.88, -span * 0.32, span * 0.32, span * 0.88] {
            ctx.move(to: CGPoint(x: dx, y: shoulder))
            ctx.addLine(to: CGPoint(x: 0, y: size * 0.44))
        }
        ctx.strokePath()
        let canopy = CGMutablePath()
        canopy.move(to: CGPoint(x: -span, y: shoulder))
        canopy.addCurve(to: CGPoint(x: span, y: shoulder),
                        control1: CGPoint(x: -span * 0.92, y: shoulder + rise * 1.45),
                        control2: CGPoint(x: span * 0.92, y: shoulder + rise * 1.45))
        canopy.addQuadCurve(to: CGPoint(x: -span, y: shoulder),
                            control: CGPoint(x: 0, y: shoulder - rise * 0.24))
        canopy.closeSubpath()
        ctx.saveGState()
        ctx.addPath(canopy); ctx.clip()
        ctx.setFillColor(NSColor(srgbRed: 1, green: 0.97, blue: 0.93, alpha: 0.97).cgColor)
        ctx.fill(CGRect(x: -span, y: shoulder - rise, width: span * 2, height: rise * 3))
        ctx.setFillColor(NSColor(srgbRed: 0.80, green: 0.14, blue: 0.22, alpha: 0.92).cgColor)
        for index in 0..<2 {
            let left = -span * 0.78 + CGFloat(index) * span * 0.94
            ctx.fill(CGRect(x: left, y: shoulder - rise, width: span * 0.42, height: rise * 3))
        }
        ctx.setFillColor(NSColor(white: 0, alpha: 0.12).cgColor)
        ctx.fill(CGRect(x: -span, y: shoulder - rise, width: span * 2, height: rise * 1.18))
        ctx.restoreGState()
        ctx.setStrokeColor(NSColor(white: 0, alpha: 0.16).cgColor)
        ctx.setLineWidth(0.6)
        ctx.addPath(canopy); ctx.strokePath()
        ctx.restoreGState()
    }

    private func drawBurst(_ burst: Burst, in ctx: CGContext) {
        let progress = burst.age / 0.45
        let radius = 7 + progress * 26
        ctx.setStrokeColor(NSColor(srgbRed: 1, green: 0.90, blue: 0.62, alpha: (1 - progress) * 0.75).cgColor)
        ctx.setLineWidth(2.4 * (1 - progress) + 0.5)
        ctx.strokeEllipse(in: CGRect(x: burst.x - radius, y: burst.y - radius, width: radius * 2, height: radius * 2))
        ctx.setLineCap(.round)
        ctx.setLineWidth(1.6 * (1 - progress) + 0.4)
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 + progress
            let inner = radius * 0.72
            let outer = radius * (1.05 + progress * 0.25)
            ctx.move(to: CGPoint(x: burst.x + cos(angle) * inner, y: burst.y + sin(angle) * inner))
            ctx.addLine(to: CGPoint(x: burst.x + cos(angle) * outer, y: burst.y + sin(angle) * outer))
        }
        ctx.strokePath()
    }

    private func drawPop(_ pop: EmojiPop, in ctx: CGContext) {
        let progress = pop.age / pop.duration
        let alpha = min(1, (1 - progress) * 2.4)
        let scale = min(1.15, 0.45 + pop.age * 5.5)
        ctx.saveGState()
        ctx.translateBy(x: pop.x, y: pop.y)
        ctx.rotate(by: pop.spin * pop.age * 0.5)
        ctx.scaleBy(x: scale, y: scale)
        ctx.setAlpha(alpha)
        let size = pop.glyph.size()
        pop.glyph.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2))
        ctx.restoreGState()
    }
}


/// A sparkle's warm halo, from a stamp: one gradient a sparkle, drawn
/// live, made the renderer wait for the graphics chip every frame. The
/// size is kept in steps of half a point, the fading in the alpha.
func sparkleGlow(_ ctx: CGContext, at point: CGPoint, radius: CGFloat, strength: CGFloat, fade: CGFloat) {
    let reach = max(0.5, (radius * 2).rounded() / 2)
    AdventPaint.stamp(ctx, CGRect(x: point.x - reach, y: point.y - reach, width: reach * 2, height: reach * 2),
                      key: "sparkle-\(Int(strength * 100))-\(Int(reach * 2))", alpha: fade) { canvas, size in
        let glow = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [NSColor(srgbRed: 1, green: 0.85, blue: 0.4, alpha: strength).cgColor,
                                       NSColor(srgbRed: 1, green: 0.8, blue: 0.3, alpha: 0).cgColor] as CFArray,
                              locations: [0, 1])!
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        canvas.drawRadialGradient(glow, startCenter: centre, startRadius: 0, endCenter: centre, endRadius: reach, options: [])
    }
}
