import AppKit

/// The pose of the whole rig — sleigh, team and driver — in one value.
/// The origin is the point where the runners meet the snow, facing right;
/// the caller mirrors the context for the other direction.
struct SleighPose {
    /// Nose up, in radians.
    var pitch: CGFloat = 0
    /// Phase of the gallop cycle.
    var gait: CGFloat = 0
    /// 0 standing still, 1 full stride.
    var gallop: CGFloat = 0
    /// Front legs stretched forward for touchdown.
    var reach: CGFloat = 0
    /// Height of the runners above the snow.
    var lift: CGFloat = 0
    /// Snow thrown up by braking runners, 0…1.
    var skid: CGFloat = 0
    /// Santa's raised arm.
    var wave: CGFloat = 0
    /// Jingle amplitude of the harness bells.
    var bells: CGFloat = 0
    /// Visible breath while the team stands in the cold.
    var breath: CGFloat = 0
    /// Lantern strength.
    var glow: CGFloat = 1
    /// Seconds of scene time, for details that keep moving on their own.
    var age: CGFloat = 0
}

/// A single reindeer, whether it is pulling the sleigh or out on its own.
struct ReindeerPose {
    var gait: CGFloat = 0
    /// 0 standing still, 1 full stride.
    var gallop: CGFloat = 0
    /// Forelegs stretched forward, for landing and leaping.
    var reach: CGFloat = 0
    /// 0 seen from the side, 1 looking out of the screen.
    var headTurn: CGFloat = 0
    /// Head tipped over while turning, in radians.
    var headTilt: CGFloat = 0
    /// Legs scrambling for a hold.
    var flail: CGFloat = 0
    var breath: CGFloat = 0
    var bells: CGFloat = 0
    var blink: CGFloat = 0
    var wobble: CGFloat = 0
    var redNose = false
    var noseGlow: CGFloat = 1
    var harnessed = true
    var age: CGFloat = 0
}

enum SleighArt {
    static let reindeerOffsets: [CGFloat] = [46, 84, 122]
    /// Nose of the lead reindeer and back of the sleigh, for fitting the rig.
    static let noseX: CGFloat = 150
    static let tailX: CGFloat = -36
    static var length: CGFloat { noseX - tailX }

    private static let fur = NSColor(srgbRed: 0.55, green: 0.34, blue: 0.20, alpha: 1)
    private static let furDark = NSColor(srgbRed: 0.38, green: 0.23, blue: 0.14, alpha: 1)
    private static let belly = NSColor(srgbRed: 0.80, green: 0.63, blue: 0.45, alpha: 1)
    private static let antler = NSColor(srgbRed: 0.35, green: 0.24, blue: 0.15, alpha: 1)
    private static let harness = NSColor(srgbRed: 0.62, green: 0.14, blue: 0.17, alpha: 1)
    private static let gold = NSColor(srgbRed: 1, green: 0.78, blue: 0.27, alpha: 1)
    private static let goldDark = NSColor(srgbRed: 0.76, green: 0.52, blue: 0.11, alpha: 1)
    private static let lacquer = NSColor(srgbRed: 0.69, green: 0.11, blue: 0.19, alpha: 1)
    private static let lacquerDark = NSColor(srgbRed: 0.44, green: 0.06, blue: 0.12, alpha: 1)
    private static let coat = NSColor(srgbRed: 0.78, green: 0.13, blue: 0.19, alpha: 1)
    private static let wool = NSColor(srgbRed: 1, green: 0.97, blue: 0.93, alpha: 1)
    private static let skin = NSColor(srgbRed: 0.98, green: 0.79, blue: 0.64, alpha: 1)
    private static let leather = NSColor(srgbRed: 0.27, green: 0.18, blue: 0.13, alpha: 1)

    private static func fill(_ ctx: CGContext, _ rect: CGRect, _ color: NSColor, _ radius: CGFloat = 0) {
        ctx.setFillColor(color.cgColor)
        if radius > 0 {
            ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.fillPath()
        } else { ctx.fill(rect) }
    }

    private static func dot(_ ctx: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: NSColor) {
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    private static func shade(_ ctx: CGContext, _ path: CGPath, _ color: NSColor, angle: CGFloat = 1) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let box = path.boundingBox
        let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
            colors: [color.blended(withFraction: 0.30, of: .black)!.cgColor,
                     color.cgColor,
                     color.blended(withFraction: 0.26, of: .white)!.cgColor] as CFArray,
            locations: [0, 0.55, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: box.minX, y: box.minY),
                               end: CGPoint(x: box.minX + box.width * (1 - angle), y: box.maxY),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    // MARK: - Rig

    static func draw(_ pose: SleighPose, in ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: 0, y: pose.lift)
        if pose.skid > 0.02 { drawSkid(pose, in: ctx) }
        ctx.saveGState()
        ctx.rotate(by: pose.pitch)
        drawTraces(pose, in: ctx)
        for (index, offset) in reindeerOffsets.enumerated() {
            drawReindeer(pose, index: index, at: offset, in: ctx)
        }
        drawSleigh(pose, in: ctx)
        drawSanta(pose, in: ctx)
        ctx.restoreGState()
        ctx.restoreGState()
    }

    /// Snow curling away from the runners while the sleigh brakes.
    private static func drawSkid(_ pose: SleighPose, in ctx: CGContext) {
        let strength = min(1, pose.skid)
        for index in 0..<9 {
            let fraction = (CGFloat(index) + 0.5) / 9
            let drift = (pose.age * 3.1 + fraction * 2.7).truncatingRemainder(dividingBy: 1)
            let x = -14 - fraction * 30 - drift * 22
            let y = 1.5 + sin(fraction * .pi) * 11 * strength + drift * 7
            let radius = (1.1 + fraction * 2.1) * (1 - drift * 0.5) * strength
            guard radius > 0.2 else { continue }
            dot(ctx, x, y, radius, NSColor(srgbRed: 0.95, green: 0.98, blue: 1,
                                           alpha: (1 - drift) * 0.72 * strength))
        }
        for index in 0..<4 {
            let fraction = (CGFloat(index) + 0.5) / 4
            let x = 16 + fraction * 16
            dot(ctx, x, 1.6 + fraction * 5 * strength, 1.1 + fraction * 1.4,
                NSColor(srgbRed: 0.95, green: 0.98, blue: 1, alpha: 0.5 * strength))
        }
    }

    /// Reins and traces, sagging when the team is not pulling.
    private static func drawTraces(_ pose: SleighPose, in ctx: CGContext) {
        let slack = (1 - pose.gallop) * 3.4
        ctx.setStrokeColor(leather.withAlphaComponent(0.92).cgColor)
        ctx.setLineWidth(1.15)
        ctx.setLineCap(.round)
        var from = CGPoint(x: 20, y: 22)
        for offset in reindeerOffsets {
            let to = CGPoint(x: offset - 11, y: 18.5)
            let mid = CGPoint(x: (from.x + to.x) / 2, y: (from.y + to.y) / 2 - slack)
            ctx.move(to: from)
            ctx.addQuadCurve(to: to, control: mid)
            from = CGPoint(x: offset + 13, y: 18.5)
        }
        ctx.strokePath()
    }

    // MARK: - Reindeer

    private static func drawReindeer(_ pose: SleighPose, index: Int, at dx: CGFloat, in ctx: CGContext) {
        var deer = ReindeerPose()
        // Each deer a fifth of a stride behind the one in front, so a wave
        // runs through the team instead of three legs moving as one.
        deer.gait = pose.gait - CGFloat(index) * 1.25
        deer.gallop = pose.gallop
        deer.reach = pose.reach
        deer.breath = pose.breath
        deer.bells = pose.bells
        deer.redNose = index == reindeerOffsets.count - 1
        deer.age = pose.age
        deer.wobble = sin(pose.age * 2.2 + CGFloat(index)) * 0.25
        ctx.saveGState()
        ctx.translateBy(x: dx, y: 0)
        drawReindeer(deer, in: ctx)
        ctx.restoreGState()
    }

    /// One reindeer, standing on its own hooves at the origin and facing right.
    static func drawReindeer(_ pose: ReindeerPose, in ctx: CGContext) {
        let phase = pose.gait
        let bob = sin(phase * 2) * 1.5 * pose.gallop + pose.wobble
        ctx.saveGState()
        ctx.translateBy(x: 0, y: bob)

        // Hind legs first, then the body, then the front legs: a simple depth order.
        // The far legs stand a little apart from the near ones, so a standing
        // deer shows four legs and not two.
        drawLeg(ctx, hip: CGPoint(x: -5.6, y: 15), phase: phase + .pi, pose: pose, front: false, far: true)
        drawLeg(ctx, hip: CGPoint(x: 11.6, y: 15.5), phase: phase + .pi * 0.35, pose: pose, front: true, far: true)

        // A deer stands tall: short back, deep chest, long legs.
        let body = CGMutablePath()
        body.move(to: CGPoint(x: -12.5, y: 16))
        body.addCurve(to: CGPoint(x: 11.5, y: 17.5),
                      control1: CGPoint(x: -11, y: 25.5), control2: CGPoint(x: 4, y: 25.5))
        body.addQuadCurve(to: CGPoint(x: 12.5, y: 13.4), control: CGPoint(x: 14.5, y: 15.6))
        body.addQuadCurve(to: CGPoint(x: -12.5, y: 16), control: CGPoint(x: 0, y: 10.6))
        body.closeSubpath()
        shade(ctx, body, fur)
        ctx.setFillColor(belly.withAlphaComponent(0.72).cgColor)
        ctx.addPath(CGPath(ellipseIn: CGRect(x: -7.5, y: 12.6, width: 14, height: 4.2), transform: nil))
        ctx.fillPath()

        // Tail.
        ctx.setFillColor(furDark.cgColor)
        ctx.fillEllipse(in: CGRect(x: -15.8, y: 17.6, width: 4.4, height: 5.4))
        dot(ctx, -14.8, 19.6, 1.4, wool.withAlphaComponent(0.85))

        drawLeg(ctx, hip: CGPoint(x: -8, y: 15.5), phase: phase + .pi * 1.25, pose: pose, front: false, far: false)
        drawLeg(ctx, hip: CGPoint(x: 9, y: 16), phase: phase, pose: pose, front: true, far: false)

        // Neck and head, carried high.
        let neck = CGMutablePath()
        neck.move(to: CGPoint(x: 6.5, y: 17.5))
        neck.addQuadCurve(to: CGPoint(x: 16.5, y: 30), control: CGPoint(x: 14.6, y: 21))
        neck.addLine(to: CGPoint(x: 11.4, y: 31))
        neck.addQuadCurve(to: CGPoint(x: 3.6, y: 18.6), control: CGPoint(x: 7.4, y: 23.4))
        neck.closeSubpath()
        shade(ctx, neck, fur)
        // The pale shaggy ruff that hangs from a reindeer's throat.
        let ruff = CGMutablePath()
        ruff.move(to: CGPoint(x: 15.2, y: 26.5))
        ruff.addQuadCurve(to: CGPoint(x: 14.2, y: 20.5), control: CGPoint(x: 16.6, y: 23.2))
        // Shaggy points hanging down the throat.
        ruff.addLine(to: CGPoint(x: 13.2, y: 18.6))
        ruff.addLine(to: CGPoint(x: 12.6, y: 20.4))
        ruff.addLine(to: CGPoint(x: 11.4, y: 19.2))
        ruff.addLine(to: CGPoint(x: 11.4, y: 21.6))
        ruff.addQuadCurve(to: CGPoint(x: 13.0, y: 27.0), control: CGPoint(x: 12.4, y: 24.6))
        ruff.closeSubpath()
        ctx.setFillColor(belly.blended(withFraction: 0.30, of: .white)!.withAlphaComponent(0.9).cgColor)
        ctx.addPath(ruff)
        ctx.fillPath()

        // Collar and harness sit on the neck, behind the head.
        if pose.harnessed {
            ctx.setStrokeColor(harness.cgColor)
            ctx.setLineWidth(2.1)
            ctx.move(to: CGPoint(x: 4.6, y: 15.6))
            ctx.addQuadCurve(to: CGPoint(x: 11.2, y: 28.4), control: CGPoint(x: 10.6, y: 19.6))
            ctx.strokePath()
            let jingle = sin(pose.age * 17) * pose.bells
            for point in [CGPoint(x: 6.4, y: 18.4), CGPoint(x: 9, y: 23.6)] {
                dot(ctx, point.x + jingle * 0.5, point.y - abs(jingle) * 0.3, 1.5, gold)
                dot(ctx, point.x + jingle * 0.5 - 0.4, point.y + 0.4, 0.5, wool.withAlphaComponent(0.9))
            }
        } else {
            // A free reindeer wears a collar with one bell, nothing more.
            ctx.setStrokeColor(harness.cgColor)
            ctx.setLineWidth(1.9)
            ctx.move(to: CGPoint(x: 7.4, y: 19.4))
            ctx.addQuadCurve(to: CGPoint(x: 12.6, y: 27.4), control: CGPoint(x: 12.2, y: 22.2))
            ctx.strokePath()
            let jingle = sin(pose.age * 15) * pose.bells
            dot(ctx, 10.4 + jingle * 0.5, 23.4, 1.6, gold)
            dot(ctx, 10 + jingle * 0.5, 23.8, 0.55, wool.withAlphaComponent(0.9))
        }

        // Turning to look out of the screen. Only the snout foreshortens — the
        // skull keeps its width — and the far eye, ear and antler come round.
        let turn = min(1, max(0, pose.headTurn))
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * turn }
        // The whole head tips at the neck joint while it comes round.
        ctx.saveGState()
        ctx.translateBy(x: 11.5, y: 27.5)
        ctx.rotate(by: -pose.headTilt)
        ctx.translateBy(x: -11.5, y: -27.5)
        let head = CGMutablePath()
        head.addEllipse(in: CGRect(x: 10.6 - turn * 1.2, y: 26.6 - turn * 0.5,
                                   width: 11.5 + turn * 1.4, height: 9 + turn * 1.1))
        shade(ctx, head, fur)

        ctx.saveGState()
        // The side-on snout fades out as he turns; a front-on muzzle, centred
        // under the eyes, fades in.
        ctx.setAlpha(1 - turn)
        ctx.translateBy(x: 18.6, y: 29.4)
        ctx.scaleBy(x: 1 - turn * 0.74, y: 1 + turn * 0.22)
        ctx.translateBy(x: -18.6, y: -29.4)
        let muzzle = CGMutablePath()
        muzzle.move(to: CGPoint(x: 18.6, y: 27.2))
        muzzle.addQuadCurve(to: CGPoint(x: 27, y: 28.8), control: CGPoint(x: 23.6, y: 26.6))
        muzzle.addQuadCurve(to: CGPoint(x: 18.6, y: 31.8), control: CGPoint(x: 23.6, y: 32))
        muzzle.closeSubpath()
        shade(ctx, muzzle, belly)
        ctx.restoreGState()
        if turn > 0.01 {
            ctx.saveGState()
            ctx.setAlpha(turn)
            let front = CGMutablePath()
            front.addEllipse(in: CGRect(x: 12.2, y: 26.4, width: 7.0, height: 5.4))
            shade(ctx, front, belly)
            // Nostrils and a small smile.
            if !pose.redNose {
                dot(ctx, 14.4, 29.2, 0.5, furDark); dot(ctx, 17.0, 29.2, 0.5, furDark)
            }
            ctx.setStrokeColor(furDark.cgColor)
            ctx.setLineWidth(0.5)
            ctx.move(to: CGPoint(x: 14.2, y: 27.6))
            ctx.addQuadCurve(to: CGPoint(x: 17.2, y: 27.6), control: CGPoint(x: 15.7, y: 26.8))
            ctx.strokePath()
            ctx.restoreGState()
        }
        let noseX = mix(26.1, 15.7), noseY = mix(29.4, 30.0)
        if pose.redNose {
            let pulse = 0.72 + 0.28 * sin(pose.age * 3.4)
            dot(ctx, noseX, noseY, 4.6, NSColor(srgbRed: 1, green: 0.28, blue: 0.26,
                                                alpha: 0.28 * pulse * pose.noseGlow))
            dot(ctx, noseX, noseY, 2.0 + turn * 0.6, NSColor(srgbRed: 0.95, green: 0.17, blue: 0.19, alpha: 1))
            dot(ctx, noseX - 0.7, noseY + 0.7, 0.65, NSColor(srgbRed: 1, green: 0.74, blue: 0.72, alpha: 0.9))
        } else {
            dot(ctx, noseX, noseY, 1.5, furDark)
        }

        let nearEye = mix(18.2, 18.6)
        let farEye = mix(18.2, 12.4)
        if pose.blink < 0.5 {
            dot(ctx, nearEye, 32.4, 1.5, NSColor(srgbRed: 0.18, green: 0.12, blue: 0.09, alpha: 1))
            dot(ctx, nearEye - 0.5, 32.9, 0.55, .white)
            if turn > 0.05 {
                dot(ctx, farEye, 32.4, 1.4, NSColor(srgbRed: 0.18, green: 0.12, blue: 0.09, alpha: turn))
                dot(ctx, farEye - 0.5, 32.9, 0.5, NSColor(white: 1, alpha: turn))
            }
        } else {
            ctx.setStrokeColor(NSColor(srgbRed: 0.18, green: 0.12, blue: 0.09, alpha: 1).cgColor)
            ctx.setLineWidth(0.85)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: nearEye - 1.3, y: 32.4)); ctx.addLine(to: CGPoint(x: nearEye + 1.3, y: 32.4))
            if turn > 0.05 {
                ctx.move(to: CGPoint(x: farEye - 1.3, y: 32.4)); ctx.addLine(to: CGPoint(x: farEye + 1.3, y: 32.4))
            }
            ctx.strokePath()
        }
        // Ears swing out to the sides as he comes round.
        ctx.setFillColor(furDark.cgColor)
        ctx.fillEllipse(in: CGRect(x: mix(11, 9.4), y: 33.2, width: 5, height: 3.2 + turn * 0.7))
        if turn > 0.05 {
            ctx.setFillColor(furDark.withAlphaComponent(turn).cgColor)
            ctx.fillEllipse(in: CGRect(x: mix(11, 20.4), y: 33.2, width: 5, height: 3.2 + turn * 0.7))
        }
        drawAntler(ctx, at: CGPoint(x: mix(16, 18.4), y: 35.2), scale: 1)
        drawAntler(ctx, at: CGPoint(x: mix(12.8, 11.6), y: mix(34.6, 35.2)), scale: mix(0.78, 0.95))
        ctx.restoreGState()

        if pose.breath > 0.02 {
            let puff = min(1, max(0, sin(pose.age * 2.1)))
            if puff > 0.3 {
                let strength = puff * pose.breath
                // Side on, the breath streams ahead of the muzzle; looking out of
                // the screen, it puffs from the nose and sinks below the chin
                // instead of hanging beside the face.
                dot(ctx, mix(15.5 + 14 + puff * 3, 15.7), mix(28.8, 25.2 - puff * 2), 2.2 + puff * 2.2,
                    NSColor(srgbRed: 0.9, green: 0.96, blue: 1, alpha: 0.20 * strength * (1 - turn * 0.4)))
                dot(ctx, mix(15.5 + 19 + puff * 4, 15.7), mix(29.8, 22.0 - puff * 2.5), 1.4 + puff * 1.5,
                    NSColor(srgbRed: 0.9, green: 0.96, blue: 1, alpha: 0.14 * strength * (1 - turn * 0.4)))
            }
        }
        ctx.restoreGState()
    }

    private static func drawAntler(_ ctx: CGContext, at base: CGPoint, scale: CGFloat) {
        ctx.setStrokeColor(antler.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(1.5 * scale)
        ctx.move(to: base)
        ctx.addQuadCurve(to: CGPoint(x: base.x - 1.6 * scale, y: base.y + 9 * scale),
                         control: CGPoint(x: base.x + 2.6 * scale, y: base.y + 5 * scale))
        ctx.strokePath()
        ctx.setLineWidth(1.1 * scale)
        for (dx, dy, tipX, tipY): (CGFloat, CGFloat, CGFloat, CGFloat) in
            [(1.1, 3.4, 5.2, 5.4), (0.4, 6.0, -4.4, 8.2), (-1.2, 8.2, 2.6, 11.6)] {
            ctx.move(to: CGPoint(x: base.x + dx * scale, y: base.y + dy * scale))
            ctx.addQuadCurve(to: CGPoint(x: base.x + tipX * scale, y: base.y + tipY * scale),
                             control: CGPoint(x: base.x + (dx + tipX) * 0.5 * scale,
                                              y: base.y + (dy + tipY) * 0.62 * scale))
        }
        ctx.strokePath()
    }

    /// Hip, knee and hoof. The hoof traces an ellipse so a walk, a gallop and a
    /// braced landing all come out of the same three numbers.
    private static func drawLeg(_ ctx: CGContext, hip: CGPoint, phase: CGFloat,
                                pose: ReindeerPose, front: Bool, far: Bool) {
        let stride = 7.4 * pose.gallop
        let reach = pose.reach * (front ? 8.5 : 3.4)
        // A scramble throws the legs out of the cycle entirely.
        let scramble = pose.flail * sin(pose.age * 23 + phase * 1.7)
        let hoofX = hip.x + sin(phase) * stride + reach + scramble * 5.5
        let swingUp = max(0, cos(phase)) * 5.8 * pose.gallop
        let hoofY = max(pose.flail > 0.05 ? -6 : 0.5,
                        hip.y - 15.2 + swingUp - pose.reach * 1.4 + abs(scramble) * 4)
        // The knee breaks forward on the front legs and backward on the hind
        // ones, which is what makes a four-legged walk read at all.
        let mid = CGPoint(x: (hip.x + hoofX) / 2 + (front ? 2.4 : -2.6),
                          y: (hip.y + hoofY) / 2 + 0.8)
        ctx.setStrokeColor((far ? furDark : fur).cgColor)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(far ? 2.0 : 2.4)
        ctx.move(to: hip)
        ctx.addLine(to: mid)
        ctx.addLine(to: CGPoint(x: hoofX, y: hoofY))
        ctx.strokePath()
        ctx.setStrokeColor(leather.cgColor)
        ctx.setLineWidth(far ? 1.5 : 1.8)
        ctx.move(to: CGPoint(x: hoofX, y: hoofY + 1.4))
        ctx.addLine(to: CGPoint(x: hoofX, y: hoofY))
        ctx.strokePath()
    }

    // MARK: - Sleigh

    private static func drawSleigh(_ pose: SleighPose, in ctx: CGContext) {
        // Runners: a long blade with a scrolled front and two struts.
        func runner(_ offset: CGFloat, _ color: NSColor, _ width: CGFloat) {
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(width)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: -34 + offset, y: 2.6 + offset * 0.3))
            ctx.addLine(to: CGPoint(x: 14 + offset, y: 1.3 + offset * 0.3))
            ctx.addQuadCurve(to: CGPoint(x: 25 + offset, y: 9 + offset * 0.3),
                             control: CGPoint(x: 25 + offset, y: 1.6 + offset * 0.3))
            ctx.addQuadCurve(to: CGPoint(x: 18.5 + offset, y: 8 + offset * 0.3),
                             control: CGPoint(x: 20 + offset, y: 12 + offset * 0.3))
            ctx.strokePath()
        }
        runner(2.6, goldDark, 1.7)
        ctx.setStrokeColor(lacquerDark.cgColor)
        ctx.setLineWidth(1.6)
        for strut: CGFloat in [-24, -6, 10] {
            ctx.move(to: CGPoint(x: strut, y: 2))
            ctx.addLine(to: CGPoint(x: strut + 1.5, y: 9))
        }
        ctx.strokePath()
        runner(0, gold, 1.9)

        // Body: a single swoop from the high back to the curled front.
        let body = CGMutablePath()
        body.move(to: CGPoint(x: -33, y: 8))
        body.addQuadCurve(to: CGPoint(x: -30, y: 31), control: CGPoint(x: -35, y: 24))
        body.addQuadCurve(to: CGPoint(x: -16, y: 20), control: CGPoint(x: -22, y: 27))
        body.addLine(to: CGPoint(x: 2, y: 19))
        body.addQuadCurve(to: CGPoint(x: 19, y: 29), control: CGPoint(x: 15, y: 19))
        body.addQuadCurve(to: CGPoint(x: 21, y: 12), control: CGPoint(x: 26, y: 20))
        body.addQuadCurve(to: CGPoint(x: -33, y: 8), control: CGPoint(x: -6, y: 3))
        body.closeSubpath()
        shade(ctx, body, lacquer)
        ctx.setStrokeColor(lacquerDark.withAlphaComponent(0.65).cgColor)
        ctx.setLineWidth(0.7)
        ctx.addPath(body)
        ctx.strokePath()

        // Gold trim along the top edge and a swirl on the side panel.
        ctx.setStrokeColor(gold.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: -29.5, y: 29))
        ctx.addQuadCurve(to: CGPoint(x: -16.5, y: 19.4), control: CGPoint(x: -21.5, y: 25.6))
        ctx.addLine(to: CGPoint(x: 2, y: 18.4))
        ctx.addQuadCurve(to: CGPoint(x: 18.4, y: 28), control: CGPoint(x: 14.6, y: 18.4))
        ctx.strokePath()
        ctx.setLineWidth(1.1)
        ctx.move(to: CGPoint(x: -20, y: 12))
        ctx.addCurve(to: CGPoint(x: -6, y: 12.5),
                     control1: CGPoint(x: -17, y: 17.5), control2: CGPoint(x: -9, y: 17))
        ctx.addCurve(to: CGPoint(x: -1, y: 15.5),
                     control1: CGPoint(x: -3.5, y: 8.5), control2: CGPoint(x: 1, y: 11.5))
        ctx.strokePath()

        // The sack rides at the back, with a few parcels looking out.
        let sack = CGMutablePath()
        sack.addEllipse(in: CGRect(x: -31, y: 17, width: 20, height: 17))
        shade(ctx, sack, NSColor(srgbRed: 0.24, green: 0.44, blue: 0.31, alpha: 1))
        ctx.setStrokeColor(NSColor(srgbRed: 0.14, green: 0.28, blue: 0.20, alpha: 0.8).cgColor)
        ctx.setLineWidth(0.8)
        ctx.addPath(sack)
        ctx.strokePath()
        fill(ctx, CGRect(x: -27.5, y: 30, width: 7, height: 6), NSColor(srgbRed: 0.84, green: 0.30, blue: 0.33, alpha: 1), 1.2)
        fill(ctx, CGRect(x: -25.2, y: 30, width: 2, height: 6), gold)
        fill(ctx, CGRect(x: -21, y: 31.5, width: 6, height: 5), NSColor(srgbRed: 0.33, green: 0.52, blue: 0.78, alpha: 1), 1.2)
        fill(ctx, CGRect(x: -19, y: 31.5, width: 1.8, height: 5), wool)

        // Lantern on the front post.
        ctx.setStrokeColor(goldDark.cgColor)
        ctx.setLineWidth(1.3)
        ctx.move(to: CGPoint(x: 17, y: 27))
        ctx.addQuadCurve(to: CGPoint(x: 23.5, y: 31), control: CGPoint(x: 22, y: 28.5))
        ctx.strokePath()
        let flame = 0.55 + 0.45 * sin(pose.age * 5.5)
        dot(ctx, 23.5, 27.6, 5.4, NSColor(srgbRed: 1, green: 0.82, blue: 0.42,
                                          alpha: 0.20 * pose.glow * (0.7 + 0.3 * flame)))
        fill(ctx, CGRect(x: 21.4, y: 24.6, width: 4.4, height: 5.4), gold, 1.2)
        fill(ctx, CGRect(x: 22.2, y: 25.6, width: 2.8, height: 3.4),
             NSColor(srgbRed: 1, green: 0.93, blue: 0.70, alpha: 0.65 + 0.35 * flame), 0.8)
    }

    // MARK: - Driver

    private static func drawSanta(_ pose: SleighPose, in ctx: CGContext) {
        let lean = pose.gallop * 1.2
        ctx.saveGState()
        ctx.translateBy(x: -8 + lean, y: 17)

        // Far arm holds the reins, drawn before the coat.
        ctx.setStrokeColor(coat.blended(withFraction: 0.22, of: .black)!.cgColor)
        ctx.setLineCap(.round)
        ctx.setLineWidth(3.4)
        ctx.move(to: CGPoint(x: 3, y: 9))
        ctx.addLine(to: CGPoint(x: 11, y: 5.4))
        ctx.strokePath()

        let torso = CGMutablePath()
        torso.move(to: CGPoint(x: -7, y: 0))
        torso.addQuadCurve(to: CGPoint(x: -5.5, y: 13), control: CGPoint(x: -9.5, y: 8))
        torso.addQuadCurve(to: CGPoint(x: 5.5, y: 12.5), control: CGPoint(x: 0, y: 16))
        torso.addQuadCurve(to: CGPoint(x: 7, y: 0), control: CGPoint(x: 9, y: 7))
        torso.closeSubpath()
        shade(ctx, torso, coat)
        fill(ctx, CGRect(x: -7.4, y: 3.4, width: 14.8, height: 3), leather, 0.6)
        fill(ctx, CGRect(x: -1.6, y: 3.2, width: 3.6, height: 3.6), gold, 0.6)
        dot(ctx, 0.2, 5, 0.75, goldDark)

        // Beard and face.
        dot(ctx, 0.6, 16.4, 5.2, skin)
        let beard = CGMutablePath()
        beard.move(to: CGPoint(x: -4.8, y: 18))
        beard.addQuadCurve(to: CGPoint(x: 0.4, y: 9.4), control: CGPoint(x: -5.4, y: 10.6))
        beard.addQuadCurve(to: CGPoint(x: 5.4, y: 17.6), control: CGPoint(x: 5.8, y: 11.2))
        beard.addQuadCurve(to: CGPoint(x: -4.8, y: 18), control: CGPoint(x: 0.4, y: 15.2))
        beard.closeSubpath()
        ctx.setFillColor(wool.cgColor)
        ctx.addPath(beard)
        ctx.fillPath()
        dot(ctx, 3.4, 17.6, 1.05, NSColor(srgbRed: 0.22, green: 0.15, blue: 0.12, alpha: 1))
        dot(ctx, 3.1, 17.9, 0.38, .white)
        dot(ctx, 4.9, 16.2, 1.5, NSColor(srgbRed: 0.93, green: 0.58, blue: 0.48, alpha: 1))
        dot(ctx, 1.4, 15.3, 1.9, skin.blended(withFraction: 0.18, of: .systemPink)!)
        ctx.setFillColor(wool.cgColor)
        ctx.addPath(CGPath(ellipseIn: CGRect(x: 1.2, y: 13.4, width: 5.2, height: 2.4), transform: nil))
        ctx.fillPath()

        // Hat: a bent cone with a fur brim and a pompom.
        let hat = CGMutablePath()
        hat.move(to: CGPoint(x: -5.4, y: 19.4))
        hat.addQuadCurve(to: CGPoint(x: -9.6, y: 29.6), control: CGPoint(x: -2.4, y: 29.4))
        hat.addQuadCurve(to: CGPoint(x: 5.6, y: 19.8), control: CGPoint(x: -1.4, y: 24.6))
        hat.closeSubpath()
        shade(ctx, hat, coat)
        fill(ctx, CGRect(x: -6.2, y: 18.2, width: 12.4, height: 3.2), wool, 1.5)
        dot(ctx, -10, 29.8, 2.3, wool)

        // Near arm: holds the reins, or waves.
        let wave = pose.wave
        let shoulder = CGPoint(x: 4.2, y: 10.6)
        let elbow = CGPoint(x: 8.4 - wave * 3.4, y: 8.2 + wave * 7.6)
        let flutter = wave > 0 ? sin(pose.age * 9) * 1.6 * wave : 0
        let hand = CGPoint(x: 12.4 - wave * 3.2 + flutter, y: 5.6 + wave * 15.6)
        ctx.setStrokeColor(coat.cgColor)
        ctx.setLineWidth(3.8)
        ctx.move(to: shoulder)
        ctx.addLine(to: elbow)
        ctx.addLine(to: hand)
        ctx.strokePath()
        ctx.setStrokeColor(wool.cgColor)
        ctx.setLineWidth(3.9)
        ctx.move(to: CGPoint(x: hand.x - (hand.x - elbow.x) * 0.22, y: hand.y - (hand.y - elbow.y) * 0.22))
        ctx.addLine(to: CGPoint(x: hand.x - (hand.x - elbow.x) * 0.08, y: hand.y - (hand.y - elbow.y) * 0.08))
        ctx.strokePath()
        dot(ctx, hand.x, hand.y, 2.1, leather)
        // The reins run from his hand over the backs to every reindeer.
        if wave < 0.5 {
            ctx.setStrokeColor(leather.withAlphaComponent(0.9 * (1 - wave * 2)).cgColor)
            ctx.setLineWidth(0.7)
            for offset in reindeerOffsets.prefix(1) {
                let bit = CGPoint(x: offset + 17.5 + 8 - lean, y: 28.5 - 17)
                let sag = (1 - pose.gallop) * 2.5
                let control = CGPoint(x: (hand.x + bit.x) / 2, y: max(hand.y, bit.y) + 4 - sag)
                ctx.move(to: hand)
                ctx.addQuadCurve(to: bit, control: control)
            }
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
}
