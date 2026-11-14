import AppKit

final class HeavyPlow {
    private struct Spray {
        var origin: CGPoint
        var age: CGFloat = 0
        let duration: CGFloat
        let targetX: CGFloat
        let rise: CGFloat
        let radius: CGFloat
    }
    var enabled = true
    func absorb(_ amount: CGFloat) { removed += amount; sprayBudget += amount }
    private(set) var x: CGFloat = -190
    private(set) var active = false
    private(set) var removed: CGFloat = 0
    private var pressure: CGFloat = 0
    private var cooldown: CGFloat = 0
    private var sprayBudget: CGFloat = 0
    private var sprays: [Spray] = []
    private var rotor: CGFloat = 0
    private var metalPaints: [NSColor:CGGradient] = [:]
    var mouth: CGFloat { x + 139 }

    func clear() {
        x = -190
        active = false
        removed = 0
        pressure = 0
        cooldown = 0
        sprayBudget = 0
        sprays.removeAll()
    }

    func step(_ dt: CGFloat, ground: inout [CGFloat], cell: CGFloat, width: CGFloat, smallLoad: CGFloat) {
        guard enabled else { return }
        cooldown = max(0, cooldown - dt)
        let total = ground.reduce(0,+)
        let deep = ground.filter { $0 >= 10 }.count
        var longest = 0, stretch = 0
        for height in ground {
            stretch = height >= 18 ? stretch+1 : 0
            longest = max(longest,stretch)
        }
        let broadBacklog = total >= max(520,width/cell*6) && deep >= max(20,Int(width/cell*0.16))
        let deepBacklog = total >= 420 && CGFloat(longest)*cell >= max(48,width*0.06)
        let backedUp = broadBacklog || deepBacklog
        pressure = !active && backedUp ? pressure+dt : max(0,pressure-dt*2)
        if !active, cooldown == 0, pressure >= 3.5 {
            active = true
            x = -190
            pressure = 0
        }
        if active {
            let start = mouth
            x += dt * 98
            let end = mouth
            var gathered: CGFloat = 0
            if end >= 0, start-24 < width, !ground.isEmpty {
                // The rotating intake keeps collecting across its full width. Snow that
                // settles behind the leading edge is still inside the auger, not left as a ridge.
                let first = min(ground.count-1, Int(max(0,start-24)/cell))
                let last = min(ground.count-1, Int(min(width.nextDown,end)/cell))
                for index in first...last {
                    let left = max(CGFloat(index)*cell,start)
                    let right = min(CGFloat(index+1)*cell,width)
                    let fraction:CGFloat = right <= end ? 1 : max(0,end-left)/max(0.001,right-left)
                    let amount = ground[index] * min(1,fraction)
                    ground[index] -= amount
                    gathered += amount
                }
                removed += gathered
                sprayBudget += gathered
            }
            rotor += dt * (gathered > 0 ? 14 : 7)
            if sprayBudget >= 1.2, sprays.count < 100 {
                let count = min(5,max(1,Int(sprayBudget/1.2)))
                for index in 0..<count {
                    sprays.append(Spray(origin:CGPoint(x:x+106,y:58),
                        duration:min(3.3,max(0.8,(width-x-87)/260)), targetX:width+20+CGFloat(index)*9,
                        rise:85+CGFloat.random(in:0...75),radius:CGFloat.random(in:1.0...2.6)))
                }
                sprayBudget = 0
            }
            if x > width + 30 {
                active = false
                cooldown = 30
                sprayBudget = 0
            }
        }
        for i in sprays.indices { sprays[i].age += dt }
        sprays.removeAll { $0.age >= $0.duration }
    }

    func draw(in ctx: CGContext, festive: Bool) {
        for spray in sprays {
            let p = spray.age / spray.duration
            let x = spray.origin.x + (spray.targetX - spray.origin.x) * p
            let y = spray.origin.y + sin(p * .pi) * spray.rise - p * 23
            let radius = spray.radius * (1 - p * 0.35)
            ctx.setFillColor(NSColor(srgbRed:0.94,green:0.98,blue:1,alpha:min(0.92,(1-p)*3)).cgColor)
            ctx.fillEllipse(in:CGRect(x:x-radius,y:y-radius,width:radius*2,height:radius*2))
        }
        guard active else { return }
        ctx.saveGState()
        ctx.translateBy(x:x,y:0.5)
        func box(_ x: CGFloat,_ y: CGFloat,_ w: CGFloat,_ h: CGFloat,_ color:NSColor,_ r:CGFloat=2) {
            ctx.setFillColor(color.cgColor)
            ctx.addPath(CGPath(roundedRect:CGRect(x:x,y:y,width:w,height:h),cornerWidth:r,cornerHeight:r,transform:nil))
            ctx.fillPath()
        }
        let dark = NSColor(srgbRed:0.12,green:0.18,blue:0.24,alpha:1)
        let body = festive ? NSColor(srgbRed:0.65,green:0.12,blue:0.24,alpha:1) : NSColor(srgbRed:0.93,green:0.55,blue:0.16,alpha:1)
        let trim = festive ? NSColor(srgbRed:0.23,green:0.44,blue:0.35,alpha:1) : NSColor(srgbRed:0.31,green:0.43,blue:0.50,alpha:1)
        let cream = NSColor(srgbRed:1,green:0.9,blue:0.71,alpha:1)
        func metal(_ rect:CGRect,_ color:NSColor,_ radius:CGFloat) {
            let path = CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil)
            ctx.saveGState()
            ctx.addPath(path); ctx.clip()
            let gradient:CGGradient
            if let cached = metalPaints[color] { gradient = cached }
            else {
                gradient = CGGradient(colorsSpace:CGColorSpace(name:CGColorSpace.sRGB),
                    colors:[color.blended(withFraction:0.20,of:.black)!.cgColor,color.cgColor,
                            color.blended(withFraction:0.24,of:.white)!.cgColor] as CFArray,locations:[0,0.55,1])!
                metalPaints[color] = gradient
            }
            ctx.drawLinearGradient(gradient,start:CGPoint(x:0,y:rect.minY),end:CGPoint(x:0,y:rect.maxY),options:[])
            ctx.restoreGState()
            ctx.setStrokeColor(dark.withAlphaComponent(0.45).cgColor)
            ctx.setLineWidth(0.6); ctx.addPath(path); ctx.strokePath()
        }
        func hazardBand(_ rect:CGRect,_ light:NSColor,_ shade:NSColor) {
            ctx.saveGState()
            ctx.clip(to:rect)
            ctx.setFillColor(shade.cgColor)
            ctx.fill(rect)
            ctx.setFillColor(light.cgColor)
            var offset = rect.minX - rect.height
            while offset < rect.maxX {
                ctx.beginPath()
                ctx.addLines(between:[CGPoint(x:offset,y:rect.minY),CGPoint(x:offset+3.4,y:rect.minY),
                                      CGPoint(x:offset+3.4+rect.height,y:rect.maxY),CGPoint(x:offset+rect.height,y:rect.maxY)])
                ctx.closePath()
                ctx.fillPath()
                offset += 7
            }
            ctx.restoreGState()
        }
        func snowcap(_ rect:CGRect) {
            let path = CGMutablePath()
            path.move(to:CGPoint(x:rect.minX,y:rect.minY))
            path.addCurve(to:CGPoint(x:rect.maxX,y:rect.minY+1),
                          control1:CGPoint(x:rect.minX+rect.width*0.2,y:rect.maxY+2),
                          control2:CGPoint(x:rect.maxX-rect.width*0.25,y:rect.maxY-1))
            path.addQuadCurve(to:CGPoint(x:rect.maxX-3,y:rect.minY-1.3),control:CGPoint(x:rect.maxX+2,y:rect.minY-2))
            path.addLine(to:CGPoint(x:rect.minX+2,y:rect.minY-1)); path.closeSubpath()
            ctx.setFillColor(NSColor(srgbRed:0.94,green:0.98,blue:1,alpha:1).cgColor)
            ctx.addPath(path); ctx.fillPath()
        }
        ctx.setFillColor(dark.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in:CGRect(x:5,y:0,width:137,height:4))
        box(4,0.5,104,18,dark,8)
        box(10,7,91,6,trim,3)
        for wheel:CGFloat in [19,43,67,92] {
            ctx.setFillColor(trim.cgColor)
            ctx.fillEllipse(in:CGRect(x:wheel-5,y:5,width:10,height:10))
            ctx.setFillColor(dark.cgColor)
            ctx.fillEllipse(in:CGRect(x:wheel-1.5,y:8.5,width:3,height:3))
        }
        for index in 0..<13 {
            let offset = CGFloat(index)*7.2 - (x.truncatingRemainder(dividingBy:7.2))
            box(11+offset,1.2,2,3,NSColor(srgbRed:0.36,green:0.44,blue:0.48,alpha:1),0.5)
        }
        metal(CGRect(x:6,y:17,width:99,height:22),body,6)
        hazardBand(CGRect(x:9,y:18.5,width:93,height:5),cream,dark)
        snowcap(CGRect(x:8,y:39,width:95,height:3))
        metal(CGRect(x:14,y:37,width:49,height:31),trim,6)
        metal(CGRect(x:20,y:43,width:35,height:20),NSColor(srgbRed:0.58,green:0.8,blue:0.86,alpha:1),3)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.28).cgColor)
        ctx.setLineWidth(2)
        ctx.move(to:CGPoint(x:24,y:46)); ctx.addLine(to:CGPoint(x:32,y:60))
        ctx.move(to:CGPoint(x:42,y:46)); ctx.addLine(to:CGPoint(x:50,y:60)); ctx.strokePath()
        box(36,43,2,20,dark,0)
        box(13,65,51,4,trim,2)
        snowcap(CGRect(x:12,y:68,width:53,height:3.4))
        box(55,35,4,1.6,cream,0.8)
        for vent in 0..<3 { box(73+CGFloat(vent)*5,23,2,8,dark.withAlphaComponent(0.45),1) }
        box(74,30,11,29,dark,4)
        metal(CGRect(x:77,y:52,width:26,height:12),trim,4)
        box(98,51,8,14,cream,2)
        box(104,53,3,10,dark,1)
        metal(CGRect(x:100,y:8,width:32,height:25),body,5)
        // Auger housing: a lit intake mouth instead of a flat black box.
        metal(CGRect(x:111,y:3,width:28,height:29),trim,4)
        box(113.5,5,23,25,NSColor(srgbRed:0.07,green:0.10,blue:0.14,alpha:1),3)
        ctx.setStrokeColor(cream.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1)
        ctx.strokeEllipse(in:CGRect(x:114,y:5.5,width:22,height:23))
        snowcap(CGRect(x:112,y:32,width:26,height:2.6))
        ctx.saveGState()
        ctx.translateBy(x:125,y:17)
        ctx.rotate(by:rotor)
        ctx.setStrokeColor(cream.cgColor)
        ctx.setLineWidth(2.3)
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 2
            ctx.move(to:CGPoint(x:cos(angle)*3,y:sin(angle)*3))
            ctx.addQuadCurve(to:CGPoint(x:cos(angle+0.5)*11,y:sin(angle+0.5)*11),
                             control:CGPoint(x:cos(angle-0.3)*8,y:sin(angle-0.3)*8))
        }
        ctx.strokePath()
        ctx.setFillColor(trim.cgColor)
        ctx.fillEllipse(in:CGRect(x:-2.3,y:-2.3,width:4.6,height:4.6))
        ctx.restoreGState()
        box(108,1,33,3,cream,1)
        box(93,27,7,4,cream,1)
        // Working light, warning beacon and a steady plume from the stack.
        ctx.setFillColor(NSColor(srgbRed:1,green:0.93,blue:0.66,alpha:0.22).cgColor)
        ctx.fillEllipse(in:CGRect(x:98,y:28,width:13,height:13))
        ctx.setFillColor(NSColor(srgbRed:1,green:0.95,blue:0.76,alpha:1).cgColor)
        ctx.fillEllipse(in:CGRect(x:101.6,y:31.6,width:5.8,height:5.8))
        let flash = 0.5 + 0.5 * sin(rotor * 2.4)
        ctx.setFillColor(NSColor(srgbRed:1,green:0.72,blue:0.18,alpha:flash*0.32).cgColor)
        ctx.fillEllipse(in:CGRect(x:31,y:63,width:14,height:14))
        metal(CGRect(x:35,y:68,width:6,height:4.6),flash>0.4 ? NSColor(srgbRed:1,green:0.95,blue:0.76,alpha:1)
              : NSColor(srgbRed:0.93,green:0.68,blue:0.17,alpha:1),2)
        for index in 0..<3 {
            let life = (rotor*0.09 + CGFloat(index)*0.34).truncatingRemainder(dividingBy:1)
            let radius = 2.0 + life*4.6
            ctx.setFillColor(NSColor(srgbRed:0.84,green:0.88,blue:0.93,alpha:(1-life)*0.24).cgColor)
            ctx.fillEllipse(in:CGRect(x:70-life*15-radius,y:60+life*13-radius,width:radius*2,height:radius*2))
        }
        if festive {
            box(12,23,86,3,cream,1)
            for index in 0..<9 { box(14+CGFloat(index)*9,26,2,2,cream,1) }
            ctx.setStrokeColor(NSColor(srgbRed:0.16,green:0.39,blue:0.27,alpha:1).cgColor)
            ctx.setLineWidth(3.5)
            ctx.strokeEllipse(in:CGRect(x:25,y:25,width:12,height:12))
            ctx.setFillColor(cream.cgColor)
            for point:CGPoint in [CGPoint(x:26,y:29),CGPoint(x:31,y:36),CGPoint(x:36,y:29)] {
                ctx.fillEllipse(in:CGRect(x:point.x-0.8,y:point.y-0.8,width:1.6,height:1.6))
            }
            box(27,23,8,3,body,1)
            box(30,21,2,5,body,1)
            snowcap(CGRect(x:65,y:38,width:29,height:2))
            // Candy bands on the chute echo the pointer's red-and-white palette.
            for index in 0..<3 { box(75,38+CGFloat(index)*7,9,3,cream,1) }
        }
        ctx.restoreGState()
    }
}
