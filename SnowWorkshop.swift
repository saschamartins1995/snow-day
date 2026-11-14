import AppKit

struct PackedSnowball: Codable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    var mass: CGFloat
    var lastPush: CGFloat = -1000000
    var rotation: CGFloat = 0
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var surface: UInt32?
    var anchor: CGRect?
    var parent: UUID?
    var falling = false
    var supportVelocity: CGFloat?
    var edgeSurface: UInt32?
    var crowned: Bool?
    var radius: CGFloat { min(36, max(3, sqrt(mass * 8 / .pi))) }
}

struct PackedSnowImpact {
    let point: CGPoint
    let mass: CGFloat
    let radius: CGFloat
    let velocity: CGVector
}

final class SnowWorkshop {
    private(set) var balls: [PackedSnowball] = []
    private(set) var impacts: [PackedSnowImpact] = []
    private(set) var held: UUID?
    private var grip: CGPoint = .zero
    private var mouseStart: CGPoint = .zero
    private var dragged = false
    private var pickedOnDown = false
    private var heldSample: (point:CGPoint,time:CGFloat)?
    private var throwVelocity = CGVector.zero
    private var brushDistance: CGFloat = 0
    private var brushDuration: CGFloat = 0
    private var brushWindow: UInt32?
    private var lastBrush: CGFloat = -.infinity
    private var lastSave: CGFloat = 0
    private var dirty = false
    var storageKey: String?
    // Set from the display's physical size; this affects clicks only, never snow pressure.
    var grabMargin: CGFloat = 15
    var suspendedSurfaces = Set<UInt32>()

    func isSuspended(_ ball:PackedSnowball) -> Bool {
        let family = chain(ending:ball.id)
        guard let root = family.first, let surface = root.surface ?? root.edgeSurface,
              suspendedSurfaces.contains(surface) else { return false }
        return !family.contains { $0.id == held }
    }
    func suspendSurfaces(_ surfaces:Set<UInt32>) {
        let newlyHidden = surfaces.subtracting(suspendedSurfaces)
        suspendedSurfaces = surfaces
        for i in balls.indices where (balls[i].surface ?? balls[i].edgeSurface).map(newlyHidden.contains) == true && isSuspended(balls[i]) {
            balls[i].vx = 0; balls[i].vy = 0; balls[i].supportVelocity = 0
            balls[i].lastPush = -1000000
        }
    }

    func restore() {
        guard let storageKey, let data = UserDefaults.standard.data(forKey:storageKey),
              let saved = try? JSONDecoder().decode([PackedSnowball].self,from:data) else { return }
        balls = saved.filter { $0.mass.isFinite && $0.mass > 0 && $0.x.isFinite && $0.y.isFinite }.prefix(80).map {
            var ball = $0
            ball.lastPush = -1000000
            ball.supportVelocity = nil
            if !ball.falling { ball.vx = 0; ball.vy = 0 }
            return ball
        }
        // Older saves may contain deliberately offset stacks. Normalize them before their
        // first frame so the user never sees a crooked snowman after an update.
        arrangeStacks()
    }
    func save() {
        guard let storageKey, let data = try? JSONEncoder().encode(balls) else { return }
        UserDefaults.standard.set(data,forKey:storageKey)
        dirty = false
    }
    func clear() { balls.removeAll(); impacts.removeAll(); held = nil; dirty = true; save() }
    func takeImpacts() -> [PackedSnowImpact] {
        let pending = impacts
        impacts.removeAll(keepingCapacity:true)
        return pending
    }

    func brush(on window: UInt32?, distance: CGFloat, duration: CGFloat, at time: CGFloat) -> Bool {
        if brushWindow != window || time-lastBrush > 0.18 {
            brushDistance = 0
            brushDuration = 0
        }
        brushWindow = window
        lastBrush = time
        brushDistance += min(18,distance)
        brushDuration += duration
        return brushDistance > 74 && brushDuration > 0.5 && balls.count < 80
    }
    func form(at point: CGPoint, mass: CGFloat, surface: UInt32?, frame: CGRect) {
        guard mass >= 9, !balls.contains(where: { !isSuspended($0) && hypot($0.x-point.x,$0.y-point.y) < $0.radius+20 }) else { return }
        let ball = PackedSnowball(id:UUID(),x:point.x,y:point.y,mass:mass,surface:surface,anchor:frame)
        balls.append(ball)
        brushDistance = 0
        brushDuration = 0
        dirty = true
    }
    func canForm(at point: CGPoint) -> Bool {
        balls.count < 80 && !balls.contains { !isSuspended($0) && hypot($0.x-point.x,$0.y-point.y) < $0.radius+20 }
    }
    func hit(at point: CGPoint, shape: CursorShape? = CursorShape.arrow, visible: (CGPoint) -> Bool) -> UUID? {
        guard visible(point) else { return nil }
        let candidates = balls.filter { ball in
            guard !isSuspended(ball), visible(CGPoint(x:ball.x,y:ball.y)) else { return false }
            if hypot(ball.x-point.x,ball.y-point.y) <= ball.radius+grabMargin { return true }
            // Clicking works at the same contact as pushing, even when only the arrow's shoulder touches.
            return shape?.rows.contains { row in
                let rect = row.offsetBy(dx:point.x,dy:point.y)
                let x = min(rect.maxX,max(rect.minX,ball.x))
                let y = min(rect.maxY,max(rect.minY,ball.y))
                return hypot(x-ball.x,y-ball.y) <= ball.radius+3
            } ?? false
        }
        // Prefer the nearest visible surface when several generous grab zones overlap.
        return candidates.min { max(0,hypot($0.x-point.x,$0.y-point.y)-$0.radius)
            < max(0,hypot($1.x-point.x,$1.y-point.y)-$1.radius) }?.id
    }
    func down(at point: CGPoint, shape: CursorShape? = CursorShape.arrow, time:CGFloat? = nil, visible: (CGPoint) -> Bool) {
        mouseStart = point
        dragged = false
        pickedOnDown = held == nil
        if held != nil { release(at:point,time:time); return }
        guard let id = hit(at:point,shape:shape,visible:visible), let i = balls.firstIndex(where:{$0.id==id}) else { return }
        held = id
        heldSample = time.map { (point,$0) }
        throwVelocity = .zero
        grip = CGPoint(x:balls[i].x-point.x,y:balls[i].y-point.y)
        balls[i].parent = nil
        balls[i].edgeSurface = nil
        balls[i].vx = 0
        balls[i].vy = 0
        dirty = true
    }
    func drag(at point: CGPoint, time:CGFloat? = nil) {
        dragged = dragged || hypot(point.x-mouseStart.x,point.y-mouseStart.y) > 4
        moveHeld(to:point,time:time)
    }
    func up(at point: CGPoint, time:CGFloat? = nil) {
        if held != nil, dragged, pickedOnDown { release(at:point,time:time) }
    }
    func moveHeld(to point: CGPoint, time:CGFloat? = nil) {
        guard let held, let i = balls.firstIndex(where:{$0.id==held}) else { return }
        if let time {
            if let previous = heldSample {
                let elapsed = time-previous.time
                if elapsed >= 1/480 {
                    if elapsed < 0.12 {
                        let blend = 1-exp(-elapsed*28)
                        let vx = min(900,max(-900,(point.x-previous.point.x)/elapsed))
                        let vy = min(900,max(-900,(point.y-previous.point.y)/elapsed))
                        throwVelocity.dx += (vx-throwVelocity.dx)*blend
                        throwVelocity.dy += (vy-throwVelocity.dy)*blend
                    } else { throwVelocity = .zero }
                    heldSample = (point,time)
                }
            } else { heldSample = (point,time) }
        }
        balls[i].x = point.x+grip.x
        balls[i].y = point.y+grip.y
        arrangeStacks()
        dirty = true
    }
    func release(at point: CGPoint, time:CGFloat? = nil) {
        guard let id = held, let i = balls.firstIndex(where:{$0.id==id}) else { return }
        moveHeld(to:point,time:time)
        balls[i].edgeSurface = nil
        let moving = descendants(of:id)
        let candidate = balls.filter { other in
            !isSuspended(other) && !moving.contains(other.id) && other.id != id && !balls.contains(where:{$0.parent==other.id})
                && abs(other.x-balls[i].x) < max(10,other.radius*0.85)
                && abs(balls[i].y-(other.y+other.radius+balls[i].radius)) < max(22,balls[i].radius*1.5)
                && chain(ending:other.id).count + moving.count + 1 <= 3
        }.min { abs($0.x-balls[i].x) < abs($1.x-balls[i].x) }
        if let candidate {
            balls[i].parent = candidate.id
            balls[i].falling = false
        } else {
            balls[i].parent = nil
            balls[i].surface = nil
            balls[i].anchor = nil
            balls[i].falling = true
            balls[i].vx = throwVelocity.dx*0.75
            balls[i].vy = throwVelocity.dy*0.85
        }
        held = nil
        heldSample = nil
        throwVelocity = .zero
        arrangeStacks()
        dirty = true
        save()
    }
    func descendants(of id: UUID) -> Set<UUID> {
        var found = Set<UUID>()
        var current = id
        while let child = balls.first(where:{$0.parent==current}), !found.contains(child.id), child.id != id {
            found.insert(child.id)
            current = child.id
        }
        return found
    }
    func chain(ending id: UUID) -> [PackedSnowball] {
        var result: [PackedSnowball] = []
        var next: UUID? = id
        while let current = next, let ball = balls.first(where:{$0.id==current}),
              !result.contains(where:{$0.id==current}) {
            result.insert(ball,at:0)
            next = ball.parent
        }
        return result
    }
    var snowmen: [[PackedSnowball]] {
        balls.compactMap { ball in
            let stack = chain(ending:ball.id)
            return stack.count == 3 ? stack : nil
        }
    }
    private func arrangeStacks() {
        for _ in 0..<3 {
            for i in balls.indices {
                guard let parent = balls[i].parent, let base = balls.first(where:{$0.id==parent}) else { continue }
                let reach = max(1,base.radius+balls[i].radius-1)
                // A snowman is a tidy vertical stack. Personality belongs in its clothes and face,
                // never in a visually unstable column of balls.
                balls[i].x = base.x
                balls[i].y = base.y + reach
                balls[i].surface = base.surface
                balls[i].edgeSurface = base.edgeSurface
                balls[i].falling = false
            }
        }
    }

    private func supportedCenter(_ ball:PackedSnowball, height:(CGFloat)->CGFloat) -> CGFloat {
        var support = height(ball.x)+ball.radius
        for fraction:CGFloat in [-0.8,-0.4,0.4,0.8] {
            let offset = ball.radius*fraction
            support = max(support,height(ball.x+offset)+sqrt(ball.radius*ball.radius-offset*offset))
        }
        return support
    }

    func displace(by movements:[(UInt32,WindowSweep)], order:[UInt32], ledges:[UInt32:Ledge], interval:CGFloat) {
        let carried = held.map { descendants(of:$0).union([$0]) } ?? []
        for i in balls.indices where balls[i].parent == nil && !carried.contains(balls[i].id) && !isSuspended(balls[i]) {
            let support = balls[i].surface ?? balls[i].edgeSurface
            let depth = support.flatMap { order.firstIndex(of:$0) } ?? order.count
            for (window,sweep) in movements {
                guard let level = order.firstIndex(of:window), level < depth,
                      window != support else { continue }
                let radius = balls[i].radius
                let inflated = WindowSweep(from:sweep.previous.insetBy(dx:-radius,dy:-radius),
                                           to:sweep.current.insetBy(dx:-radius,dy:-radius))!
                let position = CGPoint(x:balls[i].x,y:balls[i].y)
                guard let hit = inflated.impact(at:position,edgeOnly:true) else { continue }
                if hit.dy > 0, let ledge = ledges[window],
                   balls[i].x >= ledge.frame.minX, balls[i].x <= ledge.frame.maxX {
                    balls[i].y = ledge.lip+radius
                    balls[i].surface = window
                    balls[i].edgeSurface = nil
                    balls[i].anchor = CGRect(x:ledge.frame.minX,y:ledge.lip,width:ledge.frame.width,height:1)
                    balls[i].supportVelocity = ledge.windowVelocity
                    balls[i].falling = false
                    balls[i].vy = 0
                } else if hit.dx != 0 {
                    let direction:CGFloat = hit.dx < 0 ? -1 : 1
                    balls[i].x = direction < 0 ? sweep.current.minX-radius-0.5 : sweep.current.maxX+radius+0.5
                    balls[i].vx = direction*min(260,abs(hit.dx)/max(1/120,interval)*0.30)
                } else {
                    balls[i].surface = nil
                    balls[i].anchor = nil
                    balls[i].falling = true
                    balls[i].y = sweep.current.minY-radius-0.5
                    balls[i].vy = -min(400,abs(hit.dy)/max(1/120,interval)*0.4)
                }
                dirty = true
                break
            }
        }
        arrangeStacks()
    }

    func step(_ dt: CGFloat, time: CGFloat, sweep: CursorSweep?, ledges: [UInt32:Ledge], bounds: CGRect,
              groundHeight: (CGFloat)->CGFloat, visible: (CGPoint)->Bool,
              collect: (UInt32?, CGFloat, CGFloat, CGFloat)->CGFloat) {
        let carried = held.map { descendants(of:$0).union([$0]) } ?? []
        var broken = Set<UUID>()
        for i in balls.indices {
            if carried.contains(balls[i].id) || balls[i].parent != nil || isSuspended(balls[i]) { continue }
            var ball = balls[i]
            if let edge = ball.edgeSurface {
                if let ledge = ledges[edge] {
                    if let anchor = ball.anchor, anchor.width == ledge.frame.width {
                        ball.x += ledge.frame.minX-anchor.minX
                        ball.y += ledge.lip-anchor.minY
                    }
                    ball.anchor = CGRect(x:ledge.frame.minX,y:ledge.lip,width:ledge.frame.width,height:1)
                } else { ball.edgeSurface = nil }
            }
            if let surface = ball.surface {
                if let ledge = ledges[surface] {
                    if let anchor = ball.anchor, anchor.width == ledge.frame.width {
                        ball.x += ledge.frame.minX-anchor.minX
                        ball.y += ledge.lip-anchor.minY
                    }
                    ball.anchor = CGRect(x:ledge.frame.minX,y:ledge.lip,width:ledge.frame.width,height:1)
                    // Snow follows the sill, with a short slip when the support accelerates or stops.
                    let previousVelocity = ball.supportVelocity ?? ledge.windowVelocity
                    ball.vx = min(260,max(-260,ball.vx + (previousVelocity-ledge.windowVelocity)*0.38))
                    ball.supportVelocity = ledge.windowVelocity
                    if ball.x < ledge.frame.minX || ball.x > ledge.frame.maxX {
                        ball.falling = true; ball.edgeSurface = surface; ball.surface = nil
                    }
                } else { ball.surface = nil; ball.falling = true }
            }
            let motionOriginX = ball.x
            let movedOnSurface = !ball.falling
            let followsPressure: Bool
            if let sweep {
                let direction: CGFloat = sweep.dx < 0 ? -1 : 1
                let front = sweep.leadingX(direction: direction < 0 ? -1 : 1, margin: 1) + direction * ball.radius
                followsPressure = time-ball.lastPush < 0.06 && ball.vx * direction > 0
                    && abs(front-ball.x) < max(12,ball.radius+sweep.shape.bounds.width+sweep.speed)
                    && abs(sweep.end.y-ball.y) < ball.radius+16
            } else { followsPressure = false }
            if !ball.falling, let sweep, sweep.normalizedSpeed > 0.08,
               abs(sweep.dx) > max(0.01,abs(sweep.dy)*0.35), visible(CGPoint(x:ball.x,y:ball.y)),
               followsPressure || sweep.impact(at:CGPoint(x:ball.x,y:ball.y),radius:ball.radius,forgiveness:2) != nil {
                ball.lastPush = time
                let direction: CGFloat = sweep.dx < 0 ? -1 : 1
                let front = sweep.leadingX(direction:direction < 0 ? -1 : 1,margin:1) + direction*ball.radius
                let travel = front-ball.x
                ball.vx = direction * min(650, abs(sweep.dx)/max(0.001,sweep.duration) + max(0,travel*direction-2)*12)
                if travel*direction > 0 { ball.x += min(abs(travel),abs(ball.vx)*dt)*direction }
                if ball.radius < 34, descendants(of:ball.id).isEmpty {
                    ball.mass += collect(ball.surface,ball.x,ball.radius*0.8,min(1.0,abs(ball.vx)*dt*0.12))
                }
                dirty = true
            } else if !ball.falling {
                ball.x += ball.vx*dt
                ball.vx *= exp(-15*dt)
            }
            if !ball.falling {
                if let surface = ball.surface, let ledge = ledges[surface] {
                    if ball.x < ledge.frame.minX || ball.x > ledge.frame.maxX {
                        ball.surface = nil
                        ball.edgeSurface = surface
                        ball.falling = true
                    } else { ball.y = supportedCenter(ball,height:ledge.height) }
                } else { ball.y = supportedCenter(ball,height:groundHeight) }
            }
            if ball.falling {
                let priorBottom = ball.y-ball.radius
                ball.vy -= 1050*dt
                if !movedOnSurface { ball.x += ball.vx*dt }
                ball.y += ball.vy*dt
                if let edge = ball.edgeSurface, let ledge = ledges[edge] {
                    let right = ball.x > ledge.frame.midX
                    let corner = right ? ledge.windowFrame.maxX-ledge.frame.maxX : ledge.frame.minX-ledge.windowFrame.minX
                    let center = CGPoint(x:right ? ledge.frame.maxX : ledge.frame.minX,y:ledge.lip-corner)
                    let reach = corner+ball.radius
                    let offset = ball.x-center.x
                    if corner > 0, abs(offset) < reach, ball.y >= center.y {
                        let height = sqrt(max(0,reach*reach-offset*offset))
                        if ball.y < center.y+height {
                            ball.y = center.y+height
                            let nx = offset/reach, ny = height/reach
                            let intoCorner = ball.vx*nx+ball.vy*ny
                            if intoCorner < 0 {
                                ball.vx -= intoCorner*nx
                                ball.vy -= intoCorner*ny
                            }
                        }
                    } else { ball.edgeSurface = nil }
                }
                let bottom = ball.y-ball.radius
                let family = descendants(of:ball.id).union([ball.id])
                let stackLanding = balls.filter { other in
                    let top = other.y+other.radius+ball.radius-1
                    return !broken.contains(other.id) && !isSuspended(other) && !family.contains(other.id) && other.id != held && !other.falling
                        && !balls.contains(where:{$0.parent==other.id})
                        && chain(ending:other.id).count+family.count <= 3
                        && abs(other.x-ball.x) < max(8,other.radius*0.72)
                        && priorBottom+ball.radius >= top && ball.y <= top
                        && visible(CGPoint(x:other.x,y:other.y))
                }.max { $0.y+$0.radius < $1.y+$1.radius }
                let platforms = ledges.filter { _,ledge in
                    ball.x >= ledge.frame.minX && ball.x <= ledge.frame.maxX
                        && priorBottom >= ledge.height(at:ball.x) && bottom <= ledge.height(at:ball.x)
                        && visible(CGPoint(x:ball.x,y:ledge.lip+0.8))
                }
                let landing = platforms.max(by:{$0.value.lip<$1.value.lip})
                if let stackLanding, stackLanding.y+stackLanding.radius >= (landing?.value.height(at:ball.x) ?? -.infinity) {
                    ball.parent = stackLanding.id
                    ball.edgeSurface = nil
                    ball.surface = stackLanding.surface
                    ball.falling = false
                    ball.vx = 0
                    ball.vy = 0
                } else if let landing {
                    ball.surface = landing.key
                    ball.edgeSurface = nil
                    ball.supportVelocity = landing.value.windowVelocity
                    ball.anchor = CGRect(x:landing.value.frame.minX,y:landing.value.lip,width:landing.value.frame.width,height:1)
                    ball.y = supportedCenter(ball,height:landing.value.height)
                    ball.falling = false
                    ball.vy = 0
                    ball.vx *= 0.35
                } else if ball.y <= supportedCenter(ball,height:groundHeight) {
                    if ball.vy < -240 {
                        impacts.append(PackedSnowImpact(point:CGPoint(x:ball.x,y:groundHeight(ball.x)),mass:ball.mass,
                                                       radius:ball.radius,velocity:CGVector(dx:ball.vx,dy:ball.vy)))
                        broken.insert(ball.id)
                        if let child = balls.firstIndex(where:{$0.parent==ball.id}) {
                            balls[child].parent = nil
                            balls[child].surface = nil
                            balls[child].edgeSurface = nil
                            balls[child].falling = true
                            balls[child].vx = ball.vx*0.45
                            balls[child].vy = ball.vy*0.5
                        }
                    }
                    ball.edgeSurface = nil
                    ball.y = supportedCenter(ball,height:groundHeight)
                    ball.falling = false
                    ball.vy = 0
                    ball.vx *= 0.35
                }
                dirty = true
            }
            ball.x = min(bounds.maxX-ball.radius,max(bounds.minX+ball.radius,ball.x))
            ball.rotation -= (ball.x-motionOriginX)/max(3,ball.radius)
            balls[i] = ball
        }
        balls.removeAll { broken.contains($0.id) }
        arrangeStacks()
        resolveContacts(in:bounds,excluding:carried)
        if dirty, time-lastSave > 2 { save(); lastSave=time }
    }

    private func resolveContacts(in bounds:CGRect, excluding:Set<UUID>) {
        let roots = balls.indices.filter { balls[$0].parent == nil && !balls[$0].falling
            && !isSuspended(balls[$0]) && !excluding.contains(balls[$0].id) }
        guard roots.count > 1 else { return }
        var members: [Int:[Int]] = [:]
        var masses: [Int:CGFloat] = [:]
        for root in roots {
            let ids = descendants(of:balls[root].id).union([balls[root].id])
            let group = balls.indices.filter { ids.contains(balls[$0].id) }
            members[root] = group
            masses[root] = group.reduce(0) { $0+balls[$1].mass }
        }
        func shift(_ group:[Int],by distance:CGFloat) {
            for index in group { balls[index].x += distance }
        }
        // Move whole stacks sideways. Their deliberately chosen proportions stay intact.
        for _ in 0..<4 {
            var changed = false
            for a in 0..<(roots.count-1) {
                for b in (a+1)..<roots.count {
                    let left = roots[a], right = roots[b]
                    guard balls[left].surface == balls[right].surface else { continue }
                    let first = members[left]!, second = members[right]!
                    let direction:CGFloat = balls[right].x >= balls[left].x ? 1 : -1
                    var overlap:CGFloat = 0
                    for i in first { for j in second {
                        let reach = balls[i].radius+balls[j].radius-0.35
                        let vertical = abs(balls[j].y-balls[i].y)
                        guard vertical < reach else { continue }
                        overlap = max(overlap,sqrt(reach*reach-vertical*vertical)-abs(balls[j].x-balls[i].x))
                    } }
                    guard overlap > 0.02 else { continue }
                    let massA = masses[left]!, massB = masses[right]!
                    let moveA = overlap*massB/(massA+massB)
                    let moveB = overlap-moveA
                    shift(first,by:-direction*moveA)
                    shift(second,by:direction*moveB)
                    // A screen edge supports the pile instead of letting a correction go offscreen.
                    for (root,group,other) in [(left,first,second),(right,second,first)] {
                        let x = min(bounds.maxX-balls[root].radius,max(bounds.minX+balls[root].radius,balls[root].x))
                        let correction = x-balls[root].x
                        shift(group,by:correction)
                        shift(other,by:correction)
                    }
                    let closing = (balls[left].vx-balls[right].vx)*direction
                    if closing > 0 {
                        let impulse = closing/(1/massA+1/massB)
                        balls[left].vx -= direction*impulse/massA
                        balls[right].vx += direction*impulse/massB
                    }
                    changed = true
                    dirty = true
                }
            }
            if !changed { break }
        }
    }

    func crown(_ id:UUID) {
        guard let i=balls.firstIndex(where:{$0.id==id}) else { return }
        balls[i].crowned=true;dirty=true;save()
    }

    func removeCrowns(from ids:Set<UUID>) {
        for i in balls.indices where ids.contains(balls[i].id) { balls[i].crowned=nil }
        dirty=true;save()
    }

    // Battle snow is taken from the actual sculpture and returned as loose snow on impact.
    func shaveStack(_ root:UUID, fraction:CGFloat) -> [PackedSnowball] {
        let ids=descendants(of:root).union([root])
        var removed:[PackedSnowball]=[]
        for i in balls.indices where ids.contains(balls[i].id) {
            let amount=min(max(0,balls[i].mass-4),balls[i].mass*min(0.25,max(0,fraction)))
            guard amount>0 else { continue }
            var piece=balls[i];piece.mass=amount
            removed.append(piece);balls[i].mass-=amount
        }
        arrangeStacks();dirty=true
        return removed
    }

    func breakStack(_ root:UUID) -> [PackedSnowball] {
        let ids=descendants(of:root).union([root])
        let pieces=balls.filter { ids.contains($0.id) }
        balls.removeAll { ids.contains($0.id) }
        if let held,ids.contains(held) { self.held=nil;heldSample=nil;throwVelocity = .zero }
        dirty=true;save()
        return pieces
    }

    func crush(from start:CGFloat,to end:CGFloat, emit:(CGPoint,CGFloat)->Void) {
        let struck = balls.filter { $0.parent == nil && $0.surface == nil && !$0.falling && $0.id != held
            && end >= $0.x-$0.radius && start <= $0.x+$0.radius }
        var ids = Set<UUID>()
        for ball in struck { ids.insert(ball.id); ids.formUnion(descendants(of:ball.id)) }
        for ball in balls where ids.contains(ball.id) {
            emit(CGPoint(x:ball.x,y:ball.y),ball.mass)
        }
        balls.removeAll { ids.contains($0.id) }
        if !ids.isEmpty { dirty=true; save() }
    }
}
