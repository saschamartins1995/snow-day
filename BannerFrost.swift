import AppKit
import QuartzCore

struct FrostBanner {
    let id: UInt32
    let frame: CGRect
    let level: Int
    let opacity: CGFloat

    static func fits(_ frame: CGRect, on screen: CGRect) -> Bool {
        (230...470).contains(frame.width) && (46...310).contains(frame.height)
            && abs(screen.maxX - frame.maxX) <= 56
            && (0...530).contains(screen.maxY - frame.maxY)
            && screen.intersects(frame)
    }
}

final class FrostView: NSView {
    static let padding: CGFloat = 12
    private static let glaze = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [
            NSColor(srgbRed: 0.64, green: 0.81, blue: 0.95, alpha: 0.95).cgColor,
            NSColor(srgbRed: 0.89, green: 0.96, blue: 1, alpha: 0.98).cgColor,
            NSColor.white.cgColor
        ] as CFArray, locations: [0, 0.52, 1])!

    var growth: CGFloat = 1 {
        didSet { if oldValue != growth { needsDisplay = true } }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.clear(dirtyRect)
        guard growth > 0 else { return }
        let banner = bounds.insetBy(dx: Self.padding, dy: Self.padding)
        let left = banner.minX + 12
        let right = banner.maxX - 12
        let top = banner.maxY
        ctx.setAlpha(growth)

        let cap = CGMutablePath()
        cap.move(to: CGPoint(x: left, y: top))
        let ridge: [CGFloat] = [3, 5, 3, 6, 8, 5, 3, 7, 4]
        for (i, height) in ridge.enumerated() {
            let x = left + (right - left) * CGFloat(i + 1) / CGFloat(ridge.count + 1)
            let step = (right - left) / CGFloat(ridge.count + 1)
            cap.addQuadCurve(to: CGPoint(x: x, y: top + height * growth),
                             control: CGPoint(x: x - step * 0.57, y: top + (height + 1) * growth))
        }
        cap.addQuadCurve(to: CGPoint(x: right, y: top),
                         control: CGPoint(x: right - 10, y: top + 3 * growth))
        cap.closeSubpath()
        ctx.saveGState()
        ctx.addPath(cap)
        ctx.clip()
        ctx.drawLinearGradient(Self.glaze, start: CGPoint(x: 0, y: top),
                               end: CGPoint(x: 0, y: top + 7 * growth), options: [.drawsAfterEndLocation])
        ctx.restoreGState()

        let frost = NSColor(srgbRed: 0.70, green: 0.86, blue: 0.99, alpha: 0.80)
        ctx.setFillColor(frost.cgColor)
        for (index, length) in [7.0, 4.0, 9.0, 5.0].enumerated() {
            let x = right - CGFloat(index) * 7
            ctx.move(to: CGPoint(x: x - 2, y: top + 1))
            ctx.addLine(to: CGPoint(x: x + 2, y: top + 1))
            ctx.addLine(to: CGPoint(x: x + 1, y: top - CGFloat(length) * growth))
            ctx.closePath()
            ctx.fillPath()
        }

        ctx.setStrokeColor(frost.withAlphaComponent(0.64).cgColor)
        ctx.setLineWidth(0.9)
        let edge = banner.maxX - 0.6
        for (index, height) in [4.0, 7.0, 3.0, 5.0].enumerated() {
            let y = top - 15 - CGFloat(index) * 6
            let tip = edge - CGFloat(height) * growth
            ctx.move(to: CGPoint(x: edge, y: y))
            ctx.addLine(to: CGPoint(x: tip, y: y + 2 * growth))
            ctx.move(to: CGPoint(x: tip + 2, y: y + 1))
            ctx.addLine(to: CGPoint(x: tip + 1, y: y + 4 * growth))
        }
        ctx.strokePath()
    }
}

final class BannerFrost {
    private struct Decoration {
        let panel: Overlay
        let view: FrostView
        let appearedAt: TimeInterval
    }

    private struct PendingShed {
        let frame: CGRect
        let growth: CGFloat
        let appearedAt: TimeInterval
        let disappearedAt: TimeInterval
    }

    private var decorations: [UInt32: Decoration] = [:]
    private var pending: [UInt32: PendingShed] = [:]
    private(set) var systemPIDs: Set<pid_t> = []
    private var refreshedAt: TimeInterval = -.infinity

    func updateOwners(at now: TimeInterval) {
        guard now - refreshedAt > 3 else { return }
        refreshedAt = now
        systemPIDs = Set(["com.apple.notificationcenterui", "com.apple.UserNotificationCenter"].flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0).map(\.processIdentifier)
        })
    }

    func update(_ banners: [FrostBanner], at now: TimeInterval, makePanel: (CGRect) -> Overlay,
                onDismiss: (CGRect, CGFloat) -> Void = { _, _ in }) {
        let current = Set(banners.map(\.id))
        for id in Array(decorations.keys) where !current.contains(id) {
            guard let decoration = decorations.removeValue(forKey: id) else { continue }
            let frame = decoration.panel.frame.insetBy(dx: FrostView.padding, dy: FrostView.padding)
            pending[id] = PendingShed(frame: frame, growth: decoration.view.growth,
                                      appearedAt: decoration.appearedAt, disappearedAt: now)
            decoration.panel.close()
        }
        for banner in banners {
            let returning = pending.removeValue(forKey: banner.id)
            let frame = banner.frame.insetBy(dx: -FrostView.padding, dy: -FrostView.padding)
            let level = NSWindow.Level(rawValue: banner.level + 1)
            if let decoration = decorations[banner.id] {
                if decoration.panel.frame != frame { decoration.panel.setFrame(frame, display: true) }
                if decoration.panel.level != level { decoration.panel.level = level }
                decoration.panel.alphaValue = banner.opacity
                decoration.view.growth = min(1, (now - decoration.appearedAt) / 1.15)
            } else {
                let panel = makePanel(frame)
                let view = FrostView(frame: CGRect(origin: .zero, size: frame.size))
                view.autoresizingMask = [.width, .height]
                view.growth = returning?.growth ?? 0
                panel.contentView = view
                panel.level = level
                panel.alphaValue = banner.opacity
                panel.orderFrontRegardless()
                decorations[banner.id] = Decoration(panel: panel, view: view, appearedAt: returning?.appearedAt ?? now)
            }
        }
        for id in Array(pending.keys) {
            guard let item = pending[id], now - item.disappearedAt >= 0.12 else { continue }
            pending.removeValue(forKey: id)
            if item.growth >= 0.065 { onDismiss(item.frame, item.growth) }
        }
    }

    func clear() {
        for decoration in decorations.values { decoration.panel.close() }
        decorations.removeAll()
        pending.removeAll()
    }
}
