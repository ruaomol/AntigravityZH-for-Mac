import AppKit
import SwiftUI

// MARK: - Inverted Official Antigravity Arch Silhouette (180×180 viewBox, Flipped Vertically)

struct AntigravityArchShape: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 180.0
        let sy = rect.height / 180.0
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.maxY - y * sy)
        }

        var p = Path()
        p.move(to: pt(144.248, 149.062))
        p.addCurve(
            to: pt(152.685, 140.625),
            control1: pt(151.748, 154.688),
            control2: pt(162.998, 150.938)
        )
        p.addCurve(
            to: pt(89.8727, 28.125),
            control1: pt(121.748, 110.625),
            control2: pt(128.31, 28.125)
        )
        p.addCurve(
            to: pt(27.0602, 140.625),
            control1: pt(51.4352, 28.125),
            control2: pt(57.9977, 110.625)
        )
        p.addCurve(
            to: pt(35.4977, 149.062),
            control1: pt(15.8102, 151.875),
            control2: pt(27.9977, 154.688)
        )
        p.addCurve(
            to: pt(89.8727, 94.6875),
            control1: pt(64.5602, 129.375),
            control2: pt(62.6852, 94.6875)
        )
        p.addCurve(
            to: pt(144.248, 149.062),
            control1: pt(117.06, 94.6875),
            control2: pt(115.185, 129.375)
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Full-Window Mouse Monitor (Zero Hit-Test Interference)

struct WindowMouseMonitor: NSViewRepresentable {
    var onMove: (CGPoint?) -> Void
    var onClick: (CGPoint) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onMove: onMove, onClick: onClick)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onMove = onMove
        context.coordinator.onClick = onClick
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator {
        var onMove: (CGPoint?) -> Void
        var onClick: (CGPoint) -> Void
        private weak var view: NSView?
        private var moveMonitor: Any?
        private var clickMonitor: Any?
        private var exitMonitor: Any?

        init(onMove: @escaping (CGPoint?) -> Void, onClick: @escaping (CGPoint) -> Void) {
            self.onMove = onMove
            self.onClick = onClick
        }

        func attach(to view: NSView) {
            self.view = view
            moveMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
                self?.dispatchMove(event)
                return event
            }
            clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                self?.dispatchClick(event)
                return event
            }
            exitMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseExited]) { [weak self] event in
                self?.onMove(nil)
                return event
            }
        }

        func detach() {
            if let m = moveMonitor { NSEvent.removeMonitor(m) }
            if let c = clickMonitor { NSEvent.removeMonitor(c) }
            if let e = exitMonitor { NSEvent.removeMonitor(e) }
            moveMonitor = nil
            clickMonitor = nil
            exitMonitor = nil
        }

        private func swiftUIPoint(from event: NSEvent) -> CGPoint? {
            guard let view, let win = view.window, event.window === win else { return nil }
            let local = view.convert(event.locationInWindow, from: nil)
            let bounds = view.bounds
            guard bounds.contains(local) else { return nil }
            // Convert AppKit bottom-left origin to SwiftUI top-left origin
            return CGPoint(x: local.x, y: bounds.height - local.y)
        }

        private func dispatchMove(_ event: NSEvent) {
            onMove(swiftUIPoint(from: event))
        }

        private func dispatchClick(_ event: NSEvent) {
            if let pt = swiftUIPoint(from: event) {
                onClick(pt)
            }
        }
    }
}

// MARK: - Live Physics Particle Field Simulation (Inverted V-Arch + Full-Window Starlight)

enum ParticleVisualMode: Equatable {
    case scanning
    case idle
    case needsSync
    case working
    case ready
    case attention
    case error
}

private struct SimArchParticle {
    let u: Double        // -1 (left wing) ... 0 (bottom apex) ... +1 (right wing)
    let v: Double        // 0 (outer edge) ... 1 (inner vault)
    let homeNX: Double   // Normalized inside archBox [0, 1]
    let homeNY: Double   // Normalized inside archBox [0, 1] (already vertically inverted!)
    let radius: Double
    let phase: Double
    let r: Double
    let g: Double
    let b: Double
    let baseAlpha: Double

    // Dynamic physics displacement (points from home) & velocity
    var ox: Double = 0
    var oy: Double = 0
    var vx: Double = 0
    var vy: Double = 0
    var excitation: Double = 0 // 0...1 glow boost when scattered by cursor
}

private struct SimStar {
    let homeNX: Double   // Full window normalized [0, 1]
    let homeNY: Double
    let radius: Double
    let phase: Double
    let driftSpeed: Double
    let depth: Double    // 0.3 ... 1.0 for subtle parallax
    let r: Double
    let g: Double
    let b: Double
    let baseAlpha: Double

    var ox: Double = 0
    var oy: Double = 0
    var vx: Double = 0
    var vy: Double = 0
    var excitation: Double = 0
}

@MainActor
final class ParticleFieldEngine {
    fileprivate var archParticles: [SimArchParticle] = []
    fileprivate var stars: [SimStar] = []

    // Mouse state
    var pointer: CGPoint? = nil
    private var prevPointer: CGPoint? = nil
    private var pointerVX: Double = 0
    private var pointerVY: Double = 0
    var ctaHovered: Bool = false

    // Smoothly interpolated visual parameters for silky state & theme transitions
    private var lastTime: TimeInterval = 0
    private var launchAlpha: Double = 0.0
    private var closingOut: Bool = false
    private var smoothDark: Double = 1.0
    private var hasInitializedTheme: Bool = false
    private var smoothIntensity: Double = 0.72
    private var smoothWorking: Double = 0.0
    private var smoothError: Double = 0.0
    private var smoothAttention: Double = 0.0
    private var smoothProgress: Double = 0.0
    private var celebrationUntil: TimeInterval = 0
    private var rippleOrigin: CGPoint = .zero
    private var rippleStartTime: TimeInterval = -100

    init() {
        archParticles = Self.buildInvertedArchLattice()
        stars = Self.buildStarfield()
        prepareLaunchScatter()
    }

    /// Initial scattered cosmic dust state so particles crisply coalesce into the inverted V on launch (~0.85s).
    private func prepareLaunchScatter() {
        for i in archParticles.indices {
            let p = archParticles[i]
            let angle = p.phase * 1.9 + p.u * 2.8
            let dist = 22.0 + (1.0 - p.v) * 26.0 + abs(p.u) * 18.0
            archParticles[i].ox = cos(angle) * dist
            archParticles[i].oy = sin(angle) * dist - 10.0
            archParticles[i].vx = -cos(angle) * 20.0
            archParticles[i].vy = -sin(angle) * 20.0
        }
    }

    /// Outward zero-gravity dispersion fired during window close choreography.
    func triggerCloseDisperse() {
        closingOut = true
        for i in archParticles.indices {
            let p = archParticles[i]
            let angle = atan2(p.homeNY - 0.5, p.homeNX - 0.5) + sin(p.phase) * 0.45
            let speed = 150.0 + (1.0 - p.v) * 110.0 + abs(p.u) * 80.0
            archParticles[i].vx += cos(angle) * speed
            archParticles[i].vy += sin(angle) * speed - 35.0
            archParticles[i].excitation = 0.55
        }
        for i in stars.indices {
            let s = stars[i]
            let angle = atan2(s.homeNY - 0.5, s.homeNX - 0.5)
            stars[i].vx += cos(angle) * 90.0 * s.depth
            stars[i].vy += sin(angle) * 90.0 * s.depth
        }
    }

    func updatePointer(_ pt: CGPoint?) {
        if let pt, let prev = prevPointer {
            pointerVX = max(-45, min(45, Double(pt.x - prev.x)))
            pointerVY = max(-45, min(45, Double(pt.y - prev.y)))
        } else {
            pointerVX *= 0.5
            pointerVY *= 0.5
        }
        prevPointer = pt
        pointer = pt
    }

    func triggerPulse(at point: CGPoint) {
        rippleOrigin = point
        rippleStartTime = Date().timeIntervalSinceReferenceDate
        // Gentle radial impulse to nearby particles on click
        for i in archParticles.indices {
            archParticles[i].excitation = min(1.0, archParticles[i].excitation + 0.15)
        }
    }

    func triggerCelebration() {
        celebrationUntil = Date().timeIntervalSinceReferenceDate + 1.25
        // Joyful zero-gravity micro-lift burst that settles smoothly back
        for i in archParticles.indices {
            let p = archParticles[i]
            archParticles[i].vx += p.u * 26.0
            archParticles[i].vy -= 28.0 + (1.0 - abs(p.u)) * 18.0
            archParticles[i].excitation = 0.75
        }
    }

    func triggerStateBurst() {
        // Subtle breathable expansion when switching into active work
        for i in archParticles.indices {
            let p = archParticles[i]
            archParticles[i].vx += p.u * 18.0
            archParticles[i].vy += (p.homeNY - 0.5) * 18.0
        }
    }

    func archRect(in size: CGSize) -> CGRect {
        let side = min(size.width * 0.62, 232.0)
        return CGRect(
            x: (size.width - side) * 0.5,
            y: 34.0,
            width: side,
            height: side
        )
    }

    func step(now: TimeInterval, size: CGSize, mode: ParticleVisualMode, progress: Double, isDark: Bool) {
        let dt: Double
        if lastTime == 0 {
            dt = 1.0 / 60.0
        } else {
            dt = min(max(now - lastTime, 0.004), 0.04)
        }
        lastTime = now

        let targetDark = isDark ? 1.0 : 0.0
        if !hasInitializedTheme {
            smoothDark = targetDark
            hasInitializedTheme = true
        } else {
            smoothDark += (targetDark - smoothDark) * min(1.0, dt * 6.5)
        }

        // Smooth launch fade-in / close fade-out
        if closingOut {
            launchAlpha = max(0.0, launchAlpha - dt * 4.2)
        } else {
            launchAlpha = min(1.0, launchAlpha + dt * 2.2)
        }

        // Decay pointer velocity smoothly
        pointerVX *= pow(0.08, dt * 6.0)
        pointerVY *= pow(0.08, dt * 6.0)

        // Smooth transitions between visual modes (no harsh cuts!)
        let lerpRate = min(1.0, dt * 4.5)
        let targetIntensity: Double = {
            switch mode {
            case .working: return 1.05
            case .ready: return 0.94
            case .needsSync: return 0.86
            case .idle: return ctaHovered ? 0.96 : 0.78
            case .scanning: return 0.75
            case .attention: return 0.84
            case .error: return 0.70
            }
        }()
        smoothIntensity += (targetIntensity - smoothIntensity) * lerpRate
        smoothWorking += ((mode == .working ? 1.0 : 0.0) - smoothWorking) * lerpRate
        smoothError += ((mode == .error ? 1.0 : 0.0) - smoothError) * lerpRate
        smoothAttention += ((mode == .attention ? 1.0 : 0.0) - smoothAttention) * lerpRate
        smoothProgress += (progress - smoothProgress) * min(1.0, dt * 6.0)

        let box = archRect(in: size)
        let hasPointer = pointer != nil
        let mx = Double(pointer?.x ?? -9999)
        let my = Double(pointer?.y ?? -9999)
        let pointerSpeed = hypot(pointerVX, pointerVY)

        // Click ripple wave
        let rippleAge = now - rippleStartTime
        let rippleActive = rippleAge > 0 && rippleAge < 0.85
        let rippleRadius = rippleAge * 260.0
        let rx = Double(rippleOrigin.x)
        let ry = Double(rippleOrigin.y)

        // Spring constants — snappy critically-damped zero-gravity recovery (~0.85s settle)
        let springK = 28.0 + smoothWorking * 8.0
        let damping = exp(-7.2 * dt)
        let scatterRadius = 88.0
        let scatterRadiusSq = scatterRadius * scatterRadius

        for i in archParticles.indices {
            var p = archParticles[i]
            let hx = Double(box.minX) + p.homeNX * Double(box.width)
            let hy = Double(box.minY) + p.homeNY * Double(box.height)
            let px = hx + p.ox
            let py = hy + p.oy

            // 1. Real mouse dispersion & fluid swirl force (点阵飘散!)
            if hasPointer {
                let dx = px - mx
                let dy = py - my
                let distSq = dx * dx + dy * dy
                if distSq < scatterRadiusSq && distSq > 0.01 {
                    let dist = sqrt(distSq)
                    let falloff = pow(1.0 - dist / scatterRadius, 1.65)
                    let nx = dx / dist
                    let ny = dy / dist

                    // Radial push + subtle tangential swirl + mouse sweep momentum
                    let push = (580.0 + pointerSpeed * 24.0) * falloff
                    let swirl = 155.0 * falloff * (p.u >= 0 ? 1.0 : -1.0)
                    p.vx += (nx * push - ny * swirl + pointerVX * 22.0 * falloff) * dt
                    p.vy += (ny * push + nx * swirl + pointerVY * 22.0 * falloff) * dt
                    p.excitation = min(1.0, max(p.excitation, falloff * 1.15))
                }
            }

            // 2. Click gravitational ripple
            if rippleActive {
                let dx = px - rx
                let dy = py - ry
                let dist = hypot(dx, dy)
                let band = abs(dist - rippleRadius)
                if band < 28.0 && dist > 1.0 {
                    let f = (1.0 - band / 28.0) * (1.0 - rippleAge / 0.85) * 320.0
                    p.vx += (dx / dist) * f * dt
                    p.vy += (dy / dist) * f * dt
                    p.excitation = min(1.0, max(p.excitation, (1.0 - band / 28.0) * 0.7))
                }
            }

            // 3. Critically-damped spring pull back to home lattice (disabled during close dispersion)
            if !closingOut {
                p.vx += (-p.ox * springK) * dt
                p.vy += (-p.oy * springK) * dt
                p.vx *= damping
                p.vy *= damping
            } else {
                p.vx *= exp(-1.6 * dt)
                p.vy *= exp(-1.6 * dt)
            }
            p.ox += p.vx * dt
            p.oy += p.vy * dt

            // Cap extreme displacement so particles stay gracefully on-canvas during normal hover
            if !closingOut {
                let disp = hypot(p.ox, p.oy)
                if disp > 120.0 {
                    p.ox = p.ox / disp * 120.0
                    p.oy = p.oy / disp * 120.0
                }
            }

            p.excitation = max(0.0, p.excitation - dt * 1.6)
            archParticles[i] = p
        }

        // 4. Full-Window Interactive Cosmic Starfield Physics
        let starRadius = 112.0
        let starRadiusSq = starRadius * starRadius
        let starDamping = exp(-2.6 * dt)

        for i in stars.indices {
            var s = stars[i]
            let hx = s.homeNX * Double(size.width)
            let hy = s.homeNY * Double(size.height)
            let sx = hx + s.ox
            let sy = hy + s.oy

            if hasPointer {
                let dx = sx - mx
                let dy = sy - my
                let distSq = dx * dx + dy * dy
                if distSq < starRadiusSq && distSq > 0.01 {
                    let dist = sqrt(distSq)
                    let falloff = pow(1.0 - dist / starRadius, 1.5)
                    let nx = dx / dist
                    let ny = dy / dist
                    let push = (220.0 + pointerSpeed * 12.0) * falloff * s.depth
                    s.vx += (nx * push + pointerVX * 10.0 * falloff * s.depth) * dt
                    s.vy += (ny * push + pointerVY * 10.0 * falloff * s.depth) * dt
                    s.excitation = min(1.0, max(s.excitation, falloff))
                }
            }

            s.vx += (-s.ox * 4.2) * dt
            s.vy += (-s.oy * 4.2) * dt
            s.vx *= starDamping
            s.vy *= starDamping
            s.ox += s.vx * dt
            s.oy += s.vy * dt
            s.excitation = max(0.0, s.excitation - dt * 1.1)
            stars[i] = s
        }
    }

    func draw(ctx: inout GraphicsContext, size: CGSize, now: TimeInterval, mode: ParticleVisualMode) {
        let box = archRect(in: size)
        let celebrate = max(0.0, min(1.0, (celebrationUntil - now) / 1.25))

        ctx.opacity = launchAlpha

        // Subtle cursor ambient starlight illumination across background
        if let pt = pointer {
            let r: CGFloat = 115
            let rect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        StudioTheme.prismBlue.opacity(0.055),
                        Color.clear,
                    ]),
                    center: pt,
                    startRadius: 0,
                    endRadius: r
                )
            )
        }

        // 1. Atmospheric 4-color Google aura behind the inverted V-arch
        drawAtmosphericGlow(ctx: &ctx, box: box, now: now, celebrate: celebrate)

        // 2. Full-window interactive cosmic starlight
        drawStarfield(ctx: &ctx, size: size, now: now)

        // 3. Crisp interactive inverted V particle lattice
        drawInvertedArchLattice(ctx: &ctx, box: box, now: now, mode: mode, celebrate: celebrate)
    }

    private func drawAtmosphericGlow(ctx: inout GraphicsContext, box: CGRect, now: TimeInterval, celebrate: Double) {
        let driftX = sin(now * (0.45 + smoothWorking * 1.0)) * 5.0
        let driftY = cos(now * (0.35 + smoothWorking * 0.8)) * 4.0
        let intensity = min(1.25, smoothIntensity + celebrate * 0.35)

        // Volumetric translucent light silhouette inside inverted V-arch
        let archPath = AntigravityArchShape().path(in: box.insetBy(dx: box.width * 0.05, dy: box.height * 0.03))
        let lightDim = 0.58 + 0.42 * smoothDark
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            layer.fill(
                archPath,
                with: .linearGradient(
                    Gradient(stops: [
                        .init(color: Color.clear, location: 0.0),
                        .init(color: Color(red: 0.22, green: 0.52, blue: 0.98).opacity(0.18 * intensity * lightDim), location: 0.24),
                        .init(color: Color(red: 0.22, green: 0.52, blue: 0.98).opacity(0.30 * intensity * lightDim), location: 0.56),
                        .init(color: Color(red: 0.98, green: 0.78, blue: 0.25).opacity(0.24 * intensity * lightDim), location: 1.0),
                    ]),
                    startPoint: CGPoint(x: box.midX, y: box.minY),
                    endPoint: CGPoint(x: box.midX, y: box.maxY - box.height * 0.12)
                )
            )
        }

        func glow(nx: Double, ny: Double, radiusFrac: Double, color: Color, alpha: Double) {
            let center = CGPoint(
                x: box.minX + box.width * nx + driftX,
                y: box.minY + box.height * ny + driftY
            )
            let radius = box.width * radiusFrac
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(alpha * intensity * lightDim), color.opacity(0.0)]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }

        if smoothError > 0.35 {
            glow(nx: 0.50, ny: 0.68, radiusFrac: 0.38, color: Color(red: 0.93, green: 0.35, blue: 0.35), alpha: 0.30 * smoothError)
        }

        // Golden-amber bottom apex aura (matching zh1111.png!)
        glow(nx: 0.50, ny: 0.83, radiusFrac: 0.26, color: Color(red: 0.98, green: 0.74, blue: 0.14), alpha: 0.28 + smoothAttention * 0.08)
        // Lower-left emerald-green aura
        glow(nx: 0.34, ny: 0.66, radiusFrac: 0.27, color: Color(red: 0.20, green: 0.72, blue: 0.40), alpha: 0.24)
        // Lower-right coral-red aura
        glow(nx: 0.66, ny: 0.67, radiusFrac: 0.27, color: Color(red: 0.93, green: 0.30, blue: 0.26), alpha: 0.26)
        // Upper-left & upper-right sweeping azure V-wing halos
        glow(nx: 0.27, ny: 0.31, radiusFrac: 0.30, color: Color(red: 0.24, green: 0.54, blue: 0.98), alpha: 0.30)
        glow(nx: 0.73, ny: 0.31, radiusFrac: 0.30, color: Color(red: 0.24, green: 0.54, blue: 0.98), alpha: 0.30)
        // Central deep azure saddle glow
        glow(nx: 0.50, ny: 0.52, radiusFrac: 0.32, color: Color(red: 0.24, green: 0.54, blue: 0.98), alpha: 0.25)
    }

    private func drawStarfield(ctx: inout GraphicsContext, size: CGSize, now: TimeInterval) {
        let pxNorm = pointer.map { Double($0.x / max(size.width, 1)) - 0.5 } ?? 0.0
        let pyNorm = pointer.map { Double($0.y / max(size.height, 1)) - 0.5 } ?? 0.0
        let lightMix = 1.0 - smoothDark

        for s in stars {
            let idleX = sin(now * s.driftSpeed + s.phase) * 3.8 - pxNorm * 9.0 * s.depth
            let idleY = cos(now * s.driftSpeed * 0.82 + s.phase) * 3.0 - pyNorm * 7.0 * s.depth
            let x = s.homeNX * Double(size.width) + s.ox + idleX
            let y = s.homeNY * Double(size.height) + s.oy + idleY

            // In Light Mode, map pale white stars into refined cool-slate specks so they remain crisp on porcelain
            let r = s.r * smoothDark + (s.r * 0.42 + 0.14) * lightMix
            let g = s.g * smoothDark + (s.g * 0.46 + 0.16) * lightMix
            let b = s.b * smoothDark + (s.b * 0.54 + 0.20) * lightMix

            let twinkle = 0.68 + 0.32 * sin(now * (s.driftSpeed * 2.3) + s.phase)
            let alpha = min(0.95, (s.baseAlpha * twinkle * (0.78 + 0.22 * smoothDark)) + s.excitation * 0.48)
            let rad = s.radius * (1.0 + s.excitation * 0.55)
            let rect = CGRect(x: x - rad, y: y - rad, width: rad * 2, height: rad * 2)
            ctx.fill(
                Path(ellipseIn: rect),
                with: .color(Color(red: r, green: g, blue: b).opacity(alpha))
            )
        }
    }

    private func drawInvertedArchLattice(ctx: inout GraphicsContext, box: CGRect, now: TimeInterval, mode: ParticleVisualMode, celebrate: Double) {
        let flowSpeed = 0.6 + smoothWorking * 2.4 + (mode == .needsSync ? 0.7 : 0.0)
        let scanWaveY = 0.14 + (1.0 - (now * 0.72).truncatingRemainder(dividingBy: 1.0)) * 0.74

        for p in archParticles {
            let amp = 0.55 + smoothWorking * 1.4
            let wave = sin(now * flowSpeed + p.phase - smoothWorking * (1.0 - p.homeNY) * 6.0)
            let idleX = cos(now * (flowSpeed * 0.7) + p.phase) * amp * 0.45
            let idleY = wave * amp

            let cx = Double(box.minX) + p.homeNX * Double(box.width) + p.ox + idleX
            let cy = Double(box.minY) + p.homeNY * Double(box.height) + p.oy + idleY

            var r = p.r
            var g = p.g
            var b = p.b
            var alpha = p.baseAlpha
            var dotScale = 1.0

            // Smooth state modulation
            if mode == .scanning {
                let dist = abs(p.homeNY - scanWaveY)
                let beam = exp(-pow(dist / 0.11, 2.0))
                alpha = p.baseAlpha * (0.36 + 0.64 * beam)
                dotScale = 0.92 + 0.25 * beam
            } else if mode == .needsSync {
                let syncWave = 0.5 + 0.5 * sin(now * 2.3 - p.u * 4.5)
                alpha = min(1.0, p.baseAlpha * (0.74 + 0.30 * syncWave))
                dotScale = 0.95 + 0.14 * syncWave
            } else {
                let breath = 0.90 + 0.10 * sin(now * 1.05 + p.phase)
                alpha = min(1.0, p.baseAlpha * breath * (ctaHovered ? 1.08 : 0.96))
            }

            // Working progress illumination: rises from golden bottom apex (y=0.86) up both azure wings (y=0.14)
            if smoothWorking > 0.01 {
                let riseFrac = min(max((0.86 - p.homeNY) / 0.72, 0.0), 1.0)
                let front = max(0.16, smoothProgress)
                let litTarget = riseFrac <= front ? 1.08 : 0.36
                let kineticFlow = 0.85 + 0.25 * sin(now * 4.4 - riseFrac * 10.0)
                let workAlpha = min(1.0, p.baseAlpha * litTarget * kineticFlow)
                alpha = alpha * (1.0 - smoothWorking) + workAlpha * smoothWorking
                if riseFrac <= front {
                    dotScale += 0.18 * smoothWorking * max(0, sin(now * 4.4 - riseFrac * 10.0))
                }
            }

            // Soft error wash
            if smoothError > 0.01 {
                r = r * (1.0 - smoothError * 0.5) + 0.95 * smoothError * 0.5
                g = g * (1.0 - smoothError * 0.5) + 0.36 * smoothError * 0.5
                b = b * (1.0 - smoothError * 0.5) + 0.36 * smoothError * 0.5
            }

            // Interactive scatter glow boost (particles sparkle crisply as they disperse!)
            if p.excitation > 0.01 {
                let ex = p.excitation
                r = min(1.0, r + ex * 0.28)
                g = min(1.0, g + ex * 0.28)
                b = min(1.0, b + ex * 0.28)
                alpha = min(1.0, alpha + ex * 0.35)
                dotScale += ex * 0.34
            }

            // Celebratory upward wave on completion
            if celebrate > 0.01 {
                let sweepY = 0.86 - (1.0 - celebrate) * 0.76
                let band = exp(-pow((p.homeNY - sweepY) / 0.11, 2.0)) * celebrate
                alpha = min(1.0, alpha + band * 0.45)
                dotScale += band * 0.32
                r = min(1.0, r + band * 0.3)
                g = min(1.0, g + band * 0.3)
                b = min(1.0, b + band * 0.3)
            }

            // In Light Mode, deepen pastel particle hues into rich optical-ink saturation for crisp contrast on porcelain
            let lightMix = 1.0 - smoothDark
            if lightMix > 0.01 {
                let lr = max(0.08, pow(r, 1.55) * 0.90)
                let lg = max(0.14, pow(g, 1.48) * 0.86)
                let lb = max(0.18, pow(b, 1.25) * 0.95)
                r = r * smoothDark + lr * lightMix
                g = g * smoothDark + lg * lightMix
                b = b * smoothDark + lb * lightMix
            }

            let rad = p.radius * dotScale
            let dotRect = CGRect(x: cx - rad, y: cy - rad, width: rad * 2, height: rad * 2)
            ctx.fill(
                Path(ellipseIn: dotRect),
                with: .color(Color(red: r, green: g, blue: b).opacity(alpha))
            )
        }
    }

    // MARK: - Inverted V-Arch Geometry & Seeded Starfield Generation

    private static func outerCurve(_ u: Double) -> (x: Double, y: Double) {
        let a = abs(u)
        let s = u < 0 ? -1.0 : 1.0
        let x = 0.5 + s * (0.145 * sin(a * .pi * 0.5) + 0.235 * pow(a, 1.55))
        // Vertically inverted: bottom rounded golden apex at y=0.86, azure wings sweeping up to y=0.14
        let y = 1.0 - (0.14 + 0.72 * (0.58 * a * a + 0.42 * pow(a, 3.0)))
        return (x, y)
    }

    private static func innerCurve(_ u: Double) -> (x: Double, y: Double) {
        let a = abs(u)
        let s = u < 0 ? -1.0 : 1.0
        let x = 0.5 + s * (0.155 * sin(a * .pi * 0.5) + 0.205 * pow(a, 1.42))
        let y = 1.0 - (0.51 + 0.35 * (0.72 * a * a + 0.28 * pow(a, 2.8)))
        return (x, y)
    }

    private static func particleColor(u: Double, v: Double) -> (Double, Double, Double) {
        let a = abs(u)
        var r = 0.72
        var g = 0.85
        var b = 1.00

        // Upper sweeping V-wings in vibrant Google Azure Blue
        let wingWeight = min(max((a - 0.26) / 0.52, 0.0), 1.0)
        r = r * (1.0 - wingWeight) + 0.30 * wingWeight
        g = g * (1.0 - wingWeight) + 0.62 * wingWeight
        b = b * (1.0 - wingWeight) + 1.00 * wingWeight

        // Bottom rounded golden-amber apex
        let apexWeight = exp(-pow(a / 0.26, 2.0)) * exp(-pow(v / 0.52, 2.0))
        r = r * (1.0 - apexWeight) + 1.00 * apexWeight
        g = g * (1.0 - apexWeight) + 0.87 * apexWeight
        b = b * (1.0 - apexWeight) + 0.56 * apexWeight

        // Lower-left emerald green refraction
        if u < -0.05 {
            let gw = exp(-pow((u + 0.32) / 0.20, 2.0)) * exp(-pow(v / 0.44, 2.0)) * 0.80
            r = r * (1.0 - gw) + 0.38 * gw
            g = g * (1.0 - gw) + 0.92 * gw
            b = b * (1.0 - gw) + 0.64 * gw
        }

        // Lower-right coral red refraction
        if u > 0.05 {
            let rw = exp(-pow((u - 0.30) / 0.20, 2.0)) * exp(-pow(v / 0.44, 2.0)) * 0.84
            r = r * (1.0 - rw) + 1.00 * rw
            g = g * (1.0 - rw) + 0.50 * rw
            b = b * (1.0 - rw) + 0.45 * rw
        }

        // Crisp luminous white accent along inner vault saddle
        let vaultCrisp = exp(-pow((v - 0.92) / 0.16, 2.0)) * exp(-pow(a / 0.45, 2.0)) * 0.28
        r = min(1.0, r + vaultCrisp)
        g = min(1.0, g + vaultCrisp)
        b = min(1.0, b + vaultCrisp)

        return (r, g, b)
    }

    private static func buildInvertedArchLattice() -> [SimArchParticle] {
        var result: [SimArchParticle] = []
        let ribCount = 17
        for rib in 0..<ribCount {
            let v = Double(rib) / Double(ribCount - 1)
            let steps = Int(54.0 - 16.0 * v)
            for i in 0...steps {
                let u = -1.0 + 2.0 * (Double(i) / Double(steps))
                let out = outerCurve(u)
                let inn = innerCurve(u)
                let blend = pow(v, 0.96)
                let x = out.x * (1.0 - blend) + inn.x * blend
                let y = out.y * (1.0 - blend) + inn.y * blend

                let tipFade = max(0.0, 1.0 - pow(max(0.0, (abs(u) - 0.68) / 0.32), 1.5))
                guard tipFade > 0.04 else { continue }
                if abs(u) > 0.78 && rib % 2 == 1 { continue }

                let (r, g, b) = particleColor(u: u, v: v)
                let apexBoost = 1.0 + 0.28 * exp(-pow(abs(u) / 0.38, 2.0))
                let radius = (0.78 + 0.44 * (1.0 - abs(u) * 0.48)) * (0.92 + 0.14 * (1.0 - v))
                let alpha = min(0.98, (0.52 + 0.44 * (1.0 - abs(u) * 0.40)) * tipFade * apexBoost)
                let phase = u * 4.2 + v * 6.8

                result.append(SimArchParticle(
                    u: u, v: v,
                    homeNX: x, homeNY: y,
                    radius: radius, phase: phase,
                    r: r, g: g, b: b,
                    baseAlpha: alpha
                ))
            }
        }
        return result
    }

    private static func buildStarfield() -> [SimStar] {
        var rng: UInt64 = 0xA971_62A7_5EED_0019
        func nextDouble() -> Double {
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            return Double((rng >> 33) & 0x7FFF_FFFF) / Double(0x7FFF_FFFF)
        }

        var list: [SimStar] = []
        for idx in 0..<115 {
            let x = nextDouble()
            let y = nextDouble()
            let radius = 0.62 + nextDouble() * 1.05
            let phase = nextDouble() * .pi * 2.0
            let speed = 0.22 + nextDouble() * 0.42
            let depth = 0.35 + nextDouble() * 0.65
            let alpha = 0.14 + nextDouble() * 0.36

            let (r, g, b): (Double, Double, Double)
            switch idx % 14 {
            case 0: (r, g, b) = (0.45, 0.74, 1.00)
            case 4: (r, g, b) = (1.00, 0.80, 0.45)
            case 9: (r, g, b) = (0.96, 0.50, 0.48)
            case 12: (r, g, b) = (0.48, 0.90, 0.68)
            default: (r, g, b) = (0.86, 0.90, 0.98)
            }

            list.append(SimStar(
                homeNX: x, homeNY: y,
                radius: radius, phase: phase,
                driftSpeed: speed, depth: depth,
                r: r, g: g, b: b,
                baseAlpha: alpha
            ))
        }
        return list
    }
}

// MARK: - Full-Window Interactive Cosmic Particle Canvas View

struct FullWindowCosmicFieldView: View {
    var mode: ParticleVisualMode
    var progress: Double
    var sheenTrigger: Int
    var ctaHovered: Bool
    var isClosing: Bool = false

    @Environment(\.colorScheme) private var colorScheme
    @State private var engine = ParticleFieldEngine()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            let now = context.date.timeIntervalSinceReferenceDate
            let isDark = colorScheme == .dark
            Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
                engine.ctaHovered = ctaHovered
                engine.step(now: now, size: size, mode: mode, progress: progress, isDark: isDark)
                engine.draw(ctx: &ctx, size: size, now: now, mode: mode)
            }
        }
        .background(
            WindowMouseMonitor(
                onMove: { pt in engine.updatePointer(pt) },
                onClick: { pt in engine.triggerPulse(at: pt) }
            )
        )
        .onChange(of: sheenTrigger) { _, _ in
            engine.triggerCelebration()
        }
        .onChange(of: isClosing) { _, closing in
            if closing {
                engine.triggerCloseDisperse()
            }
        }
        .onChange(of: mode) { oldMode, newMode in
            if newMode == .working && oldMode != .working {
                engine.triggerStateBurst()
            }
        }
    }
}

// MARK: - Razor-Thin 2.4pt Optical Light Thread Progress (With Prismatic Leading Tip)

struct StudioOpticalProgressBar: View {
    var progress: Double
    var isActive: Bool

    var body: some View {
        let clamped = min(max(progress, 0.0), 1.0)

        GeometryReader { geo in
            let fillWidth = max(clamped > 0 ? 8 : 0, geo.size.width * clamped)

            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { context in
                let t = isActive ? context.date.timeIntervalSinceReferenceDate : 0
                let shimmerPhase = CGFloat((t * 0.68).truncatingRemainder(dividingBy: 1.0))

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(StudioTheme.controlTrack)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: StudioTheme.textPrimary.opacity(0.92), location: 0.0),
                                    .init(color: StudioTheme.prismBlue, location: 0.54),
                                    .init(color: StudioTheme.prismGreen, location: 0.76),
                                    .init(color: StudioTheme.prismYellow, location: 0.90),
                                    .init(color: StudioTheme.prismRed, location: 1.0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .overlay(
                            Group {
                                if isActive && fillWidth > 16 {
                                    LinearGradient(
                                        colors: [.clear, Color.white.opacity(0.85), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                    .frame(width: 56)
                                    .offset(x: -56 + (fillWidth + 112) * shimmerPhase)
                                }
                            }
                            .mask(Capsule(style: .continuous).frame(width: fillWidth))
                        )
                        .shadow(color: StudioTheme.prismBlue.opacity(isActive ? 0.45 : 0.10), radius: 6, x: 0, y: 0)
                        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: clamped)

                    // Subtle radiant prism tip flare riding the advancing front
                    if isActive && clamped > 0.02 && clamped < 0.99 {
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.92))
                            .frame(width: 6, height: 3.2)
                            .shadow(color: StudioTheme.prismYellow.opacity(0.75), radius: 5, x: 0, y: 0)
                            .offset(x: max(0, fillWidth - 4))
                            .animation(.spring(response: 0.42, dampingFraction: 0.88), value: clamped)
                    }
                }
            }
        }
        .frame(height: 2.5)
    }
}
