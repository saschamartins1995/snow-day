import AppKit

struct SnowmanLook {
    let hat:Int
    let palette:Int
    let expression:Int
    let branchWidth:CGFloat
    let carrotLength:CGFloat
    let carrotWidth:CGFloat
    let bend:CGFloat
    let tilt:CGFloat
    let crooked:Bool
    static func seed(for id:UUID) -> UInt64 {
        id.uuidString.utf8.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1)) &* 1099511628211 }
    }
    init(_ stack:[PackedSnowball]) {
        let base=stack[0],belly=stack[1],head=stack[2],seed=Self.seed(for:base.id)
        crooked = !(base.radius>belly.radius*1.08 && belly.radius>head.radius*1.08)
        let variant=Int(seed%6)
        if head.radius>base.radius*1.1 { hat=variant%2 == 0 ? 2 : 3 }
        else if belly.radius>base.radius*1.05 { hat=variant%2 == 0 ? 0 : 4 }
        else { hat=variant }
        palette=Int((seed>>8)%7)
        expression=Int((seed>>16)%4)
        branchWidth=max(0.85,belly.radius*(0.055+CGFloat((seed>>20)%5)*0.017))
        carrotLength=head.radius*(0.45+CGFloat((seed>>25)%6)*0.085)
        carrotWidth=max(1.1,head.radius*(0.15+CGFloat((seed>>29)%4)*0.025))
        bend=(crooked ? CGFloat(Int((seed>>33)%7)-3)*0.065 : 0.015)*head.radius
        tilt=crooked ? CGFloat(Int((seed>>38)%5)-2)*0.055 : 0
    }
}

enum SnowmanArt {
    static let palette:[NSColor]=[
        NSColor(srgbRed:0.67,green:0.20,blue:0.31,alpha:1),
        NSColor(srgbRed:0.21,green:0.43,blue:0.36,alpha:1),
        NSColor(srgbRed:0.27,green:0.40,blue:0.64,alpha:1),
        NSColor(srgbRed:0.52,green:0.31,blue:0.57,alpha:1),
        NSColor(srgbRed:0.81,green:0.56,blue:0.22,alpha:1),
        NSColor(srgbRed:0.22,green:0.54,blue:0.57,alpha:1),
        NSColor(srgbRed:0.48,green:0.35,blue:0.29,alpha:1)]
    private static let wool=NSColor(srgbRed:1,green:0.95,blue:0.84,alpha:1)
    private static let coal=NSColor(srgbRed:0.15,green:0.20,blue:0.26,alpha:1)
    static let menuIcon:NSImage = {
        let image=NSImage(size:CGSize(width:18,height:18),flipped:false) { _ in
            guard let ctx=NSGraphicsContext.current?.cgContext else { return false }
            ctx.setLineWidth(1.15);ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.strokeEllipse(in:CGRect(x:5,y:0.8,width:8,height:6.2))
            ctx.strokeEllipse(in:CGRect(x:5.7,y:6,width:6.6,height:5.4))
            ctx.strokeEllipse(in:CGRect(x:6.6,y:10.2,width:4.8,height:4.6))
            ctx.move(to:CGPoint(x:6,y:8));ctx.addLine(to:CGPoint(x:2.4,y:11.8))
            ctx.move(to:CGPoint(x:12,y:8));ctx.addLine(to:CGPoint(x:15.6,y:11.8));ctx.strokePath()
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.fill(CGRect(x:5.8,y:14,width:6.4,height:1.2))
            ctx.fill(CGRect(x:7.1,y:15,width:3.8,height:2))
            return true
        }
        image.isTemplate=true
        return image
    }()
    private static func dot(_ c:CGContext,_ x:CGFloat,_ y:CGFloat,_ r:CGFloat,_ color:NSColor) {
        c.setFillColor(color.cgColor);c.fillEllipse(in:CGRect(x:x-r,y:y-r,width:r*2,height:r*2))
    }
    private static func box(_ c:CGContext,_ rect:CGRect,_ color:NSColor,_ radius:CGFloat=1) {
        c.setFillColor(color.cgColor)
        c.addPath(CGPath(roundedRect:rect,cornerWidth:radius,cornerHeight:radius,transform:nil));c.fillPath()
    }
    private static func polygon(_ c:CGContext,_ points:[CGPoint],_ color:NSColor) {
        c.beginPath();c.addLines(between:points);c.closePath();c.setFillColor(color.cgColor);c.fillPath()
    }
    static func draw(_ stack:[PackedSnowball],in ctx:CGContext,scarf:NSColor,festive:Bool,pose:SnowFightPose) {
        guard stack.count==3 else { return }
        let look=SnowmanLook(stack),base=stack[0],belly=stack[1],head=stack[2]
        let r=head.radius,x=head.x,y=head.y,eye=max(0.65,r*0.085)
        let color=palette[look.palette]
        let dark=color.blended(withFraction:0.27,of:.black)!
        let cheek=NSColor(srgbRed:0.95,green:0.49,blue:0.46,alpha:0.27)
        let wonky:CGFloat=look.crooked ? r*0.10 : 0
        ctx.saveGState();ctx.setLineCap(.round);ctx.setLineJoin(.round)
        for direction:CGFloat in [-1,1] {
            let ex=x+direction*r*0.27,ey=y+r*0.19-direction*wonky
            if pose.hit>0.35 || pose.celebrating>0 || look.expression==3 {
                ctx.setStrokeColor(coal.cgColor);ctx.setLineWidth(eye*0.85)
                ctx.move(to:CGPoint(x:ex-eye*1.4,y:ey))
                ctx.addQuadCurve(to:CGPoint(x:ex+eye*1.4,y:ey),control:CGPoint(x:ex,y:ey+eye*1.7))
                ctx.strokePath()
            } else {
                dot(ctx,ex,ey,eye*(look.expression==1 && direction>0 ? 1.25 : 1),coal)
                dot(ctx,ex-eye*0.22,ey+eye*0.3,eye*0.25,wool)
            }
            dot(ctx,x+direction*r*0.43,y-r*0.055,eye*1.6,cheek)
        }
        let carrot=NSColor(srgbRed:0.94,green:0.40+CGFloat(look.palette%3)*0.055,blue:0.12,alpha:1)
        let nose=CGMutablePath()
        nose.move(to:CGPoint(x:x-r*0.06,y:y+r*0.045))
        nose.addQuadCurve(to:CGPoint(x:x+look.carrotLength,y:y+look.bend),control:CGPoint(x:x+look.carrotLength*0.6,y:y+look.carrotWidth))
        nose.addQuadCurve(to:CGPoint(x:x-r*0.025,y:y-look.carrotWidth),control:CGPoint(x:x+look.carrotLength*0.56,y:y-look.carrotWidth*0.8))
        nose.closeSubpath();ctx.addPath(nose);ctx.setFillColor(carrot.cgColor);ctx.fillPath()
        ctx.setStrokeColor(NSColor(srgbRed:0.70,green:0.27,blue:0.10,alpha:0.55).cgColor);ctx.setLineWidth(0.55)
        for f:CGFloat in [0.23,0.46] {
            ctx.move(to:CGPoint(x:x+look.carrotLength*f,y:y-look.carrotWidth*0.48))
            ctx.addLine(to:CGPoint(x:x+look.carrotLength*f+0.5,y:y+look.carrotWidth*0.12))
        }
        ctx.strokePath()
        ctx.setStrokeColor(coal.cgColor);ctx.setLineWidth(max(0.65,eye*0.75))
        ctx.move(to:CGPoint(x:x-r*0.23,y:y-r*0.29))
        ctx.addQuadCurve(to:CGPoint(x:x+r*0.23,y:y-r*0.25),control:CGPoint(x:x+wonky,y:y-r*(pose.celebrating>0 ? 0.61 : 0.45)))
        ctx.strokePath()
        if look.expression==2 { dot(ctx,x+r*0.30,y-r*0.24,eye*0.48,coal) }
        let neck=y-r+1,scarfWidth=min(r*0.88,belly.radius*0.85)
        box(ctx,CGRect(x:x-scarfWidth,y:neck,width:scarfWidth*2,height:max(2,r*0.23)),scarf,1.4)
        let tail:CGFloat = look.palette%2 == 0 ? 1 : -1
        box(ctx,CGRect(x:x+tail*scarfWidth*0.42,y:neck-r*0.62,width:max(2,r*0.25),height:r*0.75),scarf,1)
        ctx.setStrokeColor(wool.withAlphaComponent(0.65).cgColor);ctx.setLineWidth(max(0.6,r*0.045))
        for f:CGFloat in [-0.55,-0.1,0.35] {
            ctx.move(to:CGPoint(x:x+scarfWidth*f,y:neck+0.5));ctx.addLine(to:CGPoint(x:x+scarfWidth*f,y:neck+r*0.20))
        }
        ctx.strokePath()
        for offset:CGFloat in [-0.35,0.12,0.48] {
            dot(ctx,belly.x+wonky*0.4,belly.y+belly.radius*offset,max(0.6,eye*0.78),look.expression==1 ? dark : coal)
        }
        let wood=NSColor(srgbRed:0.30+CGFloat(look.palette%3)*0.045,green:0.22,blue:0.18,alpha:1)
        for direction:CGFloat in [-1,1] {
            let throwing = direction==pose.aim && (pose.swing != 0 || pose.ballGrip>0)
            // The arm is an angle, not a pose table: reaching back, snapping
            // forward and settling all read as one continuous motion.
            // Shaping the swing makes the reach back read early instead of only
            // in the last instant before the ball leaves.
            let shaped = pose.swing<0 ? -pow(-pose.swing,0.68) : pow(pose.swing,0.94)
            let angle:CGFloat
            if pose.celebrating>0 { angle=1.18 }
            else if throwing { angle=0.24-shaped*2.05 }
            else { angle=0.24 }
            let pull = throwing ? max(0,-shaped) : 0
            let push = throwing ? max(0,shaped) : 0
            let shoulder=CGPoint(x:belly.x+direction*belly.radius*0.87,y:belly.y+belly.radius*0.04)
            let upper=belly.radius*1.04, fore=belly.radius*0.84
            let bend=angle*0.52
            var elbow=CGPoint(x:shoulder.x+direction*cos(bend)*upper,y:shoulder.y+sin(bend)*upper)
            var hand=CGPoint(x:elbow.x+direction*cos(angle)*fore,y:elbow.y+sin(angle)*fore)
            let drag=direction*belly.radius*(pull*0.78-push*0.34)
            elbow.x -= drag*0.45
            hand.x -= drag
            if look.crooked { hand.y += direction*belly.radius*0.09 }
            let branch=max(1.2,look.branchWidth*1.5)
            ctx.setStrokeColor(wood.cgColor);ctx.setLineWidth(branch)
            ctx.move(to:shoulder);ctx.addLine(to:elbow);ctx.addLine(to:hand);ctx.strokePath()
            let spread=atan2(hand.y-elbow.y,hand.x-elbow.x)
            ctx.setLineWidth(branch*0.63)
            for fan:CGFloat in [-0.58,0.52] {
                let twig=spread+fan
                ctx.move(to:hand)
                ctx.addLine(to:CGPoint(x:hand.x+cos(twig)*belly.radius*0.31,y:hand.y+sin(twig)*belly.radius*0.31))
            }
            ctx.strokePath()
            if pose.ballGrip>0, direction==pose.aim {
                let r=max(1.9,belly.radius*0.27)
                dot(ctx,hand.x,hand.y,r,wool)
                ctx.setStrokeColor(NSColor(srgbRed:0.52,green:0.70,blue:0.85,alpha:0.75).cgColor)
                ctx.setLineWidth(0.55)
                ctx.strokeEllipse(in:CGRect(x:hand.x-r,y:hand.y-r,width:r*2,height:r*2))
                dot(ctx,hand.x-r*0.32,hand.y+r*0.32,r*0.30,.white)
            }
        }
        if pose.damage>0 {
            ctx.setStrokeColor(NSColor(srgbRed:0.45,green:0.64,blue:0.72,alpha:pose.damage*0.6).cgColor)
            ctx.setLineWidth(0.75)
            ctx.move(to:CGPoint(x:belly.x-belly.radius*0.48,y:belly.y+belly.radius*0.3))
            ctx.addLine(to:CGPoint(x:belly.x-belly.radius*0.27,y:belly.y+belly.radius*0.05))
            ctx.addLine(to:CGPoint(x:belly.x-belly.radius*0.41,y:belly.y-belly.radius*0.16));ctx.strokePath()
        }
        ctx.saveGState();ctx.translateBy(x:x,y:y+r*0.77);ctx.rotate(by:look.tilt)
        if base.crowned==true {
            let drop=max(0,1-pose.crownAge/0.65)
            ctx.translateBy(x:0,y:drop*drop*18)
            drawCrown(in:ctx,radius:r)
        } else { drawHat(in:ctx,radius:r,kind:festive && look.hat%3==2 ? 5 : look.hat,color:color,dark:dark) }
        ctx.restoreGState()
        if pose.celebrating>0 {
            let age=pose.crownAge
            ctx.setStrokeColor(NSColor(srgbRed:1,green:0.78,blue:0.26,alpha:pose.celebrating).cgColor)
            ctx.setLineWidth(1)
            for i in 0..<6 {
                let a=CGFloat(i)*CGFloat.pi/3+age*0.5
                let sx=x+cos(a)*(r*1.5+6),sy=y+r*0.8+sin(a)*(r*1.3+8)
                let length:CGFloat=1.5+abs(sin(age*4+CGFloat(i)))*1.5
                ctx.move(to:CGPoint(x:sx-length,y:sy));ctx.addLine(to:CGPoint(x:sx+length,y:sy))
                ctx.move(to:CGPoint(x:sx,y:sy-length));ctx.addLine(to:CGPoint(x:sx,y:sy+length))
            }
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
    private static func drawHat(in c:CGContext,radius r:CGFloat,kind:Int,color:NSColor,dark:NSColor) {
        switch kind {
        case 1: // Felt top hat with a colored ribbon.
            box(c,CGRect(x:-r*0.57,y:0,width:r*1.14,height:r*0.83),dark,r*0.08)
            box(c,CGRect(x:-r*0.58,y:r*0.1,width:r*1.16,height:r*0.19),color)
            box(c,CGRect(x:-r*0.85,y:-r*0.04,width:r*1.7,height:max(2,r*0.15)),dark)
            dot(c,r*0.38,r*0.2,max(0.7,r*0.07),wool)
        case 2: // A little wonky upturned bucket.
            polygon(c,[CGPoint(x:-r*0.73,y:0),CGPoint(x:-r*0.48,y:r*0.77),CGPoint(x:r*0.48,y:r*0.77),CGPoint(x:r*0.73,y:0)],color)
            box(c,CGRect(x:-r*0.81,y:-r*0.03,width:r*1.62,height:r*0.13),dark)
            c.setStrokeColor(wool.withAlphaComponent(0.55).cgColor);c.setLineWidth(0.8)
            c.strokeEllipse(in:CGRect(x:-r*0.32,y:r*0.18,width:r*0.64,height:r*0.31))
        case 3: // Earflaps and soft trim.
            box(c,CGRect(x:-r*0.77,y:-r*0.03,width:r*1.54,height:r*0.62),color,r*0.3)
            box(c,CGRect(x:-r*0.86,y:-r*0.40,width:r*0.35,height:r*0.74),dark,r*0.1)
            box(c,CGRect(x:r*0.51,y:-r*0.40,width:r*0.35,height:r*0.74),dark,r*0.1)
            box(c,CGRect(x:-r*0.69,y:-r*0.04,width:r*1.38,height:r*0.20),wool,r*0.1)
        case 4: // Slouchy knitted cap.
            let p=CGMutablePath();p.move(to:CGPoint(x:-r*0.75,y:0))
            p.addCurve(to:CGPoint(x:r*1.0,y:r*0.65),control1:CGPoint(x:-r*0.8,y:r*1.15),control2:CGPoint(x:r*0.85,y:r*1.2))
            p.addQuadCurve(to:CGPoint(x:r*0.70,y:0),control:CGPoint(x:r*0.31,y:r*0.66));p.closeSubpath()
            c.addPath(p);c.setFillColor(color.cgColor);c.fillPath()
            dot(c,r*1.0,r*0.65,r*0.19,wool)
            box(c,CGRect(x:-r*0.78,y:-r*0.03,width:r*1.56,height:r*0.21),dark,r*0.09)
        case 5: // Pointed winter cap; colors remain personal outside Christmas.
            let p=CGMutablePath();p.move(to:CGPoint(x:-r*0.72,y:0))
            p.addQuadCurve(to:CGPoint(x:r*0.9,y:r*0.85),control:CGPoint(x:-r*0.36,y:r*1.65))
            p.addQuadCurve(to:CGPoint(x:r*0.72,y:0),control:CGPoint(x:r*0.33,y:r*0.7));p.closeSubpath()
            c.addPath(p);c.setFillColor(color.cgColor);c.fillPath()
            box(c,CGRect(x:-r*0.77,y:-r*0.03,width:r*1.54,height:r*0.22),wool,r*0.10)
            dot(c,r*0.9,r*0.85,r*0.2,wool)
        default: // Ribbed pom-pom beanie.
            c.setFillColor(color.cgColor);c.fillEllipse(in:CGRect(x:-r*0.76,y:-r*0.22,width:r*1.52,height:r*1.02))
            box(c,CGRect(x:-r*0.80,y:-r*0.06,width:r*1.6,height:r*0.25),dark,r*0.10)
            c.setLineWidth(max(0.6,r*0.04));c.setStrokeColor(wool.withAlphaComponent(0.45).cgColor)
            for f:CGFloat in [-0.55,-0.27,0,0.27,0.55] {
                c.move(to:CGPoint(x:r*f,y:r*0.25));c.addLine(to:CGPoint(x:r*f*0.72,y:r*0.60))
            }
            c.strokePath();dot(c,0,r*0.87,r*0.22,wool)
        }
    }
    private static func drawCrown(in c:CGContext,radius r:CGFloat) {
        let gold=NSColor(srgbRed:1,green:0.75,blue:0.21,alpha:1)
        polygon(c,[CGPoint(x:-r*0.66,y:0),CGPoint(x:-r*0.83,y:r*0.65),CGPoint(x:-r*0.35,y:r*0.35),
                   CGPoint(x:0,y:r*0.87),CGPoint(x:r*0.35,y:r*0.35),CGPoint(x:r*0.83,y:r*0.65),CGPoint(x:r*0.66,y:0)],gold)
        box(c,CGRect(x:-r*0.68,y:-r*0.04,width:r*1.36,height:r*0.17),NSColor(srgbRed:0.85,green:0.51,blue:0.15,alpha:1))
        for (x,y):(CGFloat,CGFloat) in [(-0.83,0.65),(0,0.87),(0.83,0.65)] { dot(c,r*x,r*y,max(0.8,r*0.075),wool) }
        dot(c,0,r*0.20,max(1,r*0.11),palette[0])
    }
}
