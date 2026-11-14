import AppKit

struct SnowFightPose {
    var aim:CGFloat = 1
    var throwing:CGFloat = 0
    /// -1 is the fully drawn back arm, +1 the fully extended follow-through.
    var swing:CGFloat = 0
    /// Body weight shifting with the throw: negative leans away from the target.
    var lean:CGFloat = 0
    /// Whether a snowball is still in the hand.
    var ballGrip:CGFloat = 0
    var hit:CGFloat = 0
    var damage:CGFloat = 0
    var celebrating:CGFloat = 0
    var crownAge:CGFloat = 100
    var offset:CGPoint = .zero
}

final class SnowballFight {
    struct Shot {
        let source:UUID
        let origin:CGPoint
        let destination:CGPoint
        let duration:CGFloat
        let rise:CGFloat
        let mass:CGFloat
        let radius:CGFloat
        var age:CGFloat = 0
        func point(at age:CGFloat) -> CGPoint {
            let p=min(1,max(0,age/duration))
            return CGPoint(x:origin.x+(destination.x-origin.x)*p,
                           y:origin.y+(destination.y-origin.y)*p+4*rise*p*(1-p))
        }
    }
    private struct Fighter {
        var health:Int
        let maximum:Int
        var nextThrow:CGFloat
        var target:UUID?
        var windup:CGFloat = -100
        var lastThrow:CGFloat = -100
        var lastHit:CGFloat = -100
        var facing:CGFloat = 1
    }
    /// How long a fighter reaches back before the ball leaves the hand.
    static let windupTime:CGFloat = 0.32
    /// How long the arm keeps swinging after the release.
    static let followThrough:CGFloat = 0.42
    private var fighters:[UUID:Fighter]=[:]
    private(set) var shots:[Shot]=[]
    private(set) var fighting=false
    private(set) var winner:UUID?
    private(set) var clock:CGFloat=0
    private var victoryAt:CGFloat = -100
    private var randomState:UInt64=1
    var isRunning:Bool { fighting || (winner != nil && clock-victoryAt<5.5) }
    var remaining:Int { fighters.count }

    private func random() -> CGFloat {
        randomState = randomState &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat(randomState >> 32)/CGFloat(UInt32.max)
    }
    private func canFight(_ stack:[PackedSnowball],in workshop:SnowWorkshop,visible:(CGPoint)->Bool) -> Bool {
        !workshop.isSuspended(stack[0]) && !stack[0].falling && stack[0].edgeSurface == nil
            && !stack.contains(where:{$0.id==workshop.held})
            && stack.allSatisfy { visible(CGPoint(x:$0.x,y:$0.y)) }
    }
    func eligible(in workshop:SnowWorkshop,visible:(CGPoint)->Bool) -> [[PackedSnowball]] {
        workshop.snowmen.filter { canFight($0,in:workshop,visible:visible) }
    }
    @discardableResult func start(in workshop:SnowWorkshop,visible:(CGPoint)->Bool) -> Bool {
        let stacks=eligible(in:workshop,visible:visible)
        guard stacks.count>=2,!isRunning else { return false }
        fighters.removeAll();shots.removeAll();winner=nil;clock=0;victoryAt = -100
        for stack in stacks {
            randomState ^= SnowmanLook.seed(for:stack[0].id)
            let health=min(5,max(3,Int(stack.reduce(0,{$0+$1.radius})/19)+1))
            fighters[stack[0].id]=Fighter(health:health,maximum:health,nextThrow:0.45+random()*1.1)
        }
        workshop.removeCrowns(from:Set(fighters.keys))
        fighting=true
        return true
    }
    func stop(emit:(PackedSnowImpact)->Void) {
        for shot in shots { spill(shot,emit:emit) }
        shots.removeAll();fighters.removeAll();fighting=false;winner=nil
    }
    private func spill(_ shot:Shot,emit:(PackedSnowImpact)->Void) {
        emit(PackedSnowImpact(point:shot.point(at:shot.age),mass:shot.mass,radius:shot.radius,
                              velocity:CGVector(dx:0,dy:-100)))
    }
    func pose(for id:UUID) -> SnowFightPose {
        var result=SnowFightPose()
        if let fighter=fighters[id] {
            result.aim=fighter.facing
            let wind=clock-fighter.windup
            let since=clock-fighter.lastThrow
            if fighter.target != nil, wind>=0, wind<Self.windupTime {
                // Reach back, slowing into the moment of release.
                let draw=sin(min(1,wind/Self.windupTime) * .pi*0.5)
                result.swing = -draw
                result.lean = -draw*0.62
                result.ballGrip = 1
            } else if since<Self.followThrough {
                let t=since/Self.followThrough
                // A fast snap forward, then the arm swings out and settles.
                let snap=min(1,t/0.22)
                let settle=t<0.22 ? 1 : 1-(t-0.22)/0.78
                result.swing=(-1+2*snap)*settle
                result.lean=0.78*snap*settle
            }
            result.throwing=max(0,result.swing)
            result.hit=max(0,1-(clock-fighter.lastHit)/0.5)
            result.damage=1-CGFloat(fighter.health)/CGFloat(fighter.maximum)
            result.offset.x=sin((clock-fighter.lastHit)*32)*result.hit*2.2
                + result.lean*fighter.facing*2.8
        }
        if winner==id {
            result.crownAge=max(0,clock-victoryAt)
            result.celebrating=max(0,1-result.crownAge/5.5)
            result.offset.y=abs(sin(result.crownAge*6))*3*result.celebrating
        }
        return result
    }
    func step(_ dt:CGFloat,workshop:SnowWorkshop,visible:(CGPoint)->Bool,
              emit:(PackedSnowImpact)->Void) {
        guard dt>0 else { return }
        if !fighting,winner == nil { clock+=dt;return }
        let stacks=Dictionary(uniqueKeysWithValues:workshop.snowmen.map { ($0[0].id,$0) })
        if let winner,stacks[winner] == nil { self.winner=nil }
        guard fighting else { clock+=dt;return }
        fighters=fighters.filter { stacks[$0.key] != nil }
        if fighters.count<=1 { finish(workshop:workshop,emit:emit);return }
        // Hidden or carried sculptures keep their place in the round, without being hit invisibly.
        guard fighters.keys.allSatisfy({ canFight(stacks[$0]!,in:workshop,visible:visible) }) else { return }
        clock+=dt
        for id in fighters.keys.sorted(by:{$0.uuidString<$1.uuidString}) {
            guard var fighter=fighters[id],let stack=stacks[id] else { continue }
            if let target=fighter.target,clock-fighter.windup>=Self.windupTime {
                if let targetStack=stacks[target],fighters[target] != nil {
                    let belly=stack[1],destination=targetStack[1]
                    let direction:CGFloat=destination.x>=belly.x ? 1 : -1
                    let origin=CGPoint(x:belly.x+direction*belly.radius*1.7,y:belly.y+belly.radius*0.8)
                    let targetPoint=CGPoint(x:destination.x,y:destination.y+destination.radius*0.15)
                    let mass=workshop.shaveStack(id,fraction:0.006).reduce(0,{$0+$1.mass})
                    if mass>0 {
                        let distance=hypot(targetPoint.x-origin.x,targetPoint.y-origin.y)
                        shots.append(Shot(source:id,origin:origin,destination:targetPoint,
                                          duration:min(2.4,max(0.5,distance/340)),
                                          rise:min(125,max(34,abs(targetPoint.x-origin.x)*0.20)),
                                          mass:mass,radius:min(4.8,max(2.5,sqrt(mass)))))
                    }
                }
                fighter.target=nil;fighter.lastThrow=clock;fighter.nextThrow=clock+1.25+random()*1.2
            } else if fighter.target == nil,clock>=fighter.nextThrow {
                let others=fighters.keys.filter { $0 != id }.sorted { $0.uuidString<$1.uuidString }
                if !others.isEmpty {
                    let target=others[min(others.count-1,Int(random()*CGFloat(others.count)))]
                    fighter.target=target;fighter.windup=clock
                    fighter.facing=(stacks[target]![1].x>=stack[1].x) ? 1 : -1
                }
            }
            fighters[id]=fighter
        }
        var remainingShots:[Shot]=[]
        var collisionStacks=Dictionary(uniqueKeysWithValues:workshop.snowmen.map { ($0[0].id,$0) })
        for var shot in shots {
            if !fighting { spill(shot,emit:emit);continue }
            let previous=shot.point(at:shot.age)
            shot.age+=dt
            let point=shot.point(at:shot.age)
            var hit:(id:UUID,t:CGFloat)?
            for (id,_) in fighters where id != shot.source {
                guard let stack=collisionStacks[id] else { continue }
                for ball in stack {
                    let dx=point.x-previous.x,dy=point.y-previous.y
                    let t=min(1,max(0,((ball.x-previous.x)*dx+(ball.y-previous.y)*dy)/max(0.0001,dx*dx+dy*dy)))
                    if hypot(previous.x+dx*t-ball.x,previous.y+dy*t-ball.y)<=ball.radius+shot.radius,
                       t<(hit?.t ?? .infinity) { hit=(id,t) }
                }
            }
            if let hit,var fighter=fighters[hit.id] {
                spill(shot,emit:emit)
                fighter.health-=1;fighter.lastHit=clock
                let pieces:[PackedSnowball]
                if fighter.health<=0 {
                    pieces=workshop.breakStack(hit.id);fighters.removeValue(forKey:hit.id)
                    collisionStacks.removeValue(forKey:hit.id)
                } else { pieces=workshop.shaveStack(hit.id,fraction:0.10);fighters[hit.id]=fighter }
                if fighter.health>0 { collisionStacks[hit.id]=workshop.snowmen.first(where:{$0[0].id==hit.id}) }
                for piece in pieces {
                    emit(PackedSnowImpact(point:CGPoint(x:piece.x,y:piece.y),mass:piece.mass,
                        radius:min(18,piece.radius),velocity:CGVector(dx:shot.destination.x>shot.origin.x ? 65 : -65,dy:-230)))
                }
            } else if shot.age>=shot.duration { spill(shot,emit:emit) }
            else { remainingShots.append(shot) }
            if fighters.count<=1 {
                // Finish immediately; an already airborne reply must not erase the last survivor.
                fighting=false
            }
        }
        shots=remainingShots
        if !fighting || fighters.count<=1 { finish(workshop:workshop,emit:emit) }
    }
    private func finish(workshop:SnowWorkshop,emit:(PackedSnowImpact)->Void) {
        fighting=false;winner=fighters.keys.first;victoryAt=clock
        if let winner { workshop.crown(winner) }
        for shot in shots { spill(shot,emit:emit) }
        shots.removeAll()
    }
    func drawShots(in ctx:CGContext) {
        for shot in shots {
            let p=shot.point(at:shot.age)
            ctx.setFillColor(NSColor(srgbRed:0.76,green:0.88,blue:0.96,alpha:0.9).cgColor)
            ctx.fillEllipse(in:CGRect(x:p.x-shot.radius,y:p.y-shot.radius,width:shot.radius*2,height:shot.radius*2))
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fillEllipse(in:CGRect(x:p.x-shot.radius*0.72,y:p.y-shot.radius*0.35,width:shot.radius*1.4,height:shot.radius*1.3))
        }
    }
}
