// Refeed: plays a signed video full screen for a phone's front camera
// (Pixel SL2T) to read. No chrome: a time dial, a speed dial, a mirror toggle,
// and a video you can drag to the left or right edge. The controls sit on the
// opposite edge.

import AppKit
import AVFoundation
import UniformTypeIdentifiers

let minSpeed = 0.25, maxSpeed = 3.0, step = 0.25

enum Align: Int { case left = -1, center = 0, right = 1 }

func speedLabel(_ s: Double) -> String {
    var t = String(format: "%.2f", s)
    while t.hasSuffix("0") { t.removeLast() }
    if t.hasSuffix(".") { t.removeLast() }
    if t.hasPrefix("0.") { t.removeFirst() }
    return t + "×"
}

// MARK: - Dial

func timeLabel(_ t: Double) -> String {
    let s = max(0, Int(t.rounded(.down)))
    return String(format: "%d:%02d", s / 60, s % 60)
}

// A vertical DialKit slider: 5% white track, 11% fill from the bottom, a 3pt
// handle at the fill's edge, hashmarks that appear only while it's active.
// The owner sets the fill and label; a drag reports a fraction, 0 at the bottom.
final class DialView: NSView {
    var onScrub: ((Double) -> Void)?
    var marks: [CGFloat] = [] { didSet { rebuildMarks() } }

    private var fraction: CGFloat = 0
    private var text = ""
    private let fill = CALayer()
    private let handle = CALayer()
    private let value = CATextLayer()
    private var markLayers: [CALayer] = []
    private var hovering = false
    private var dragging = false
    private var active: Bool { hovering || dragging }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        guard let root = layer else { return }
        root.backgroundColor = NSColor(white: 1, alpha: 0.05).cgColor
        root.cornerRadius = 8
        root.cornerCurve = .continuous
        root.masksToBounds = true

        root.addSublayer(fill)
        handle.backgroundColor = NSColor(white: 1, alpha: 0.95).cgColor
        handle.cornerRadius = 1.5
        root.addSublayer(handle)
        value.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        value.fontSize = 11
        value.alignmentMode = .center
        root.addSublayer(value)

        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    required init?(coder: NSCoder) { fatalError() }

    func set(fraction f: CGFloat, text t: String, animated: Bool) {
        fraction = min(1, max(0, f))
        text = t
        update(animated: animated)
    }

    private func rebuildMarks() {
        markLayers.forEach { $0.removeFromSuperlayer() }
        markLayers = marks.map { _ in
            let m = CALayer()
            m.cornerRadius = 0.5
            layer?.insertSublayer(m, below: handle)
            return m
        }
        update(animated: false)
    }

    override func viewDidChangeBackingProperties() {
        value.contentsScale = window?.backingScaleFactor ?? 2
    }

    override func layout() {
        super.layout()
        update(animated: false)
    }

    private func update(animated: Bool) {
        let w = bounds.width, h = bounds.height
        let fillH = (fraction * h).rounded()
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.18)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1))
        fill.frame = CGRect(x: 0, y: 0, width: w, height: fillH)
        fill.backgroundColor = NSColor(white: 1, alpha: active ? 0.15 : 0.11).cgColor
        handle.frame = CGRect(x: (w - 20) / 2, y: min(h - 9, max(6, fillH - 7)), width: 20, height: 3)
        for (m, f) in zip(markLayers, marks) {
            m.frame = CGRect(x: (w - 8) / 2, y: (f * h).rounded(), width: 8, height: 1)
            m.backgroundColor = NSColor(white: 1, alpha: active ? 0.15 : 0).cgColor
        }
        value.string = text
        value.foregroundColor = NSColor(white: 1, alpha: active ? 1 : 0.7).cgColor
        value.frame = CGRect(x: 0, y: h - 26, width: w, height: 16)
        CATransaction.commit()
    }

    private func setActive(hover: Bool? = nil, drag: Bool? = nil) {
        if let hover { hovering = hover }
        if let drag { dragging = drag }
        update(animated: true)
    }

    override func mouseEntered(with e: NSEvent) { setActive(hover: true) }
    override func mouseExited(with e: NSEvent) { setActive(hover: false) }
    override func mouseDown(with e: NSEvent) { setActive(drag: true); track(e) }
    override func mouseDragged(with e: NSEvent) { track(e) }
    override func mouseUp(with e: NSEvent) { setActive(drag: false) }
    private func track(_ e: NSEvent) {
        let y = convert(e.locationInWindow, from: nil).y
        onScrub?(Double(min(1, max(0, y / bounds.height))))
    }
}

// MARK: - Mirror toggle

// A 40pt DialKit button under the dial, with Lucide's
// square-centerline-dashed-horizontal (ISC) drawn at 16pt.
final class MirrorButton: NSView {
    var on = false { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

    override var isFlipped: Bool { true } // SVG coordinates run top-down

    // The icon's paths on Lucide's 24pt grid.
    private static let icon: NSBezierPath = {
        let p = NSBezierPath()
        // M8 3H5a2 2 0 0 0-2 2v14c0 1.1.9 2 2 2h3
        p.move(to: NSPoint(x: 8, y: 3))
        p.line(to: NSPoint(x: 5, y: 3))
        p.appendArc(from: NSPoint(x: 3, y: 3), to: NSPoint(x: 3, y: 5), radius: 2)
        p.line(to: NSPoint(x: 3, y: 19))
        p.appendArc(from: NSPoint(x: 3, y: 21), to: NSPoint(x: 5, y: 21), radius: 2)
        p.line(to: NSPoint(x: 8, y: 21))
        // M16 3h3a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-3
        p.move(to: NSPoint(x: 16, y: 3))
        p.line(to: NSPoint(x: 19, y: 3))
        p.appendArc(from: NSPoint(x: 21, y: 3), to: NSPoint(x: 21, y: 5), radius: 2)
        p.line(to: NSPoint(x: 21, y: 19))
        p.appendArc(from: NSPoint(x: 21, y: 21), to: NSPoint(x: 19, y: 21), radius: 2)
        p.line(to: NSPoint(x: 16, y: 21))
        // The dashed centreline: M12 2v2, M12 8v2, M12 14v2, M12 20v2
        for y in [2.0, 8, 14, 20] {
            p.move(to: NSPoint(x: 12, y: y))
            p.line(to: NSPoint(x: 12, y: y + 2))
        }
        p.lineCapStyle = .round
        p.lineJoinStyle = .round
        return p
    }()

    override func draw(_ dirtyRect: NSRect) {
        NSColor(white: 1, alpha: on ? 0.15 : 0.05).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8).fill()

        let size: CGFloat = 16, scale = size / 24
        let path = Self.icon.copy() as! NSBezierPath
        var t = AffineTransform(scale: scale)
        t.append(AffineTransform(translationByX: (bounds.width - size) / 2, byY: (bounds.height - size) / 2))
        path.transform(using: t)
        path.lineWidth = 2 * scale
        NSColor(white: 1, alpha: on ? 1 : 0.7).setStroke()
        path.stroke()
    }
    override func mouseDown(with e: NSEvent) { onClick?() }
}

// MARK: - Drop zone

// What an empty window shows: a dashed drop target that brightens while a
// file is dragged over it, and a Select Video button.
final class DropZone: NSView {
    var highlighted = false { didSet { needsDisplay = true } }
    // Sends openDocument(_:) up the responder chain to the stage.
    private let button = NSButton(title: "Select Video", target: nil, action: #selector(StageView.openDocument(_:)))

    override init(frame: NSRect) {
        super.init(frame: frame)
        button.bezelStyle = .push
        button.controlSize = .regular
        addSubview(button)
    }
    required init?(coder: NSCoder) { fatalError() }

    // A 440 x 260 card in the middle. It's only the invitation: the whole
    // window takes the drop.
    private var box: NSRect {
        let w = min(440, bounds.width - 48), h = min(260, bounds.height - 68)
        return NSRect(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2, width: w, height: h).integral
    }

    // Icon (28), 12, title (16), 20, button: one stack centred in the box.
    override func layout() {
        super.layout()
        button.sizeToFit()
        let w = max(button.frame.width, 120)
        button.frame = NSRect(x: box.midX - w / 2, y: box.midY - 52, width: w, height: button.frame.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        let border = NSBezierPath(roundedRect: box, xRadius: 16, yRadius: 16)
        border.lineWidth = 1.5
        border.setLineDash([6, 6], count: 2, phase: 0)
        NSColor(white: 1, alpha: highlighted ? 0.6 : 0.2).setStroke()
        border.stroke()
        if highlighted {
            NSColor(white: 1, alpha: 0.04).setFill()
            NSBezierPath(roundedRect: box, xRadius: 16, yRadius: 16).fill()
        }

        // The app's viewfinder corners, 22 x 28.
        let gw: CGFloat = 22, gh: CGFloat = 28, arm: CGFloat = 7, r: CGFloat = 4
        let g = NSRect(x: box.midX - gw / 2, y: box.midY + 14, width: gw, height: gh)
        let corners = NSBezierPath()
        for (cx, cy, dx, dy) in [
            (g.minX, g.maxY, 1.0, -1.0), (g.maxX, g.maxY, -1.0, -1.0),
            (g.minX, g.minY, 1.0, 1.0), (g.maxX, g.minY, -1.0, 1.0),
        ] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
            corners.move(to: NSPoint(x: cx, y: cy + dy * arm))
            corners.appendArc(from: NSPoint(x: cx, y: cy), to: NSPoint(x: cx + dx * arm, y: cy), radius: r)
            corners.line(to: NSPoint(x: cx + dx * arm, y: cy))
        }
        corners.lineWidth = 2
        corners.lineCapStyle = .round
        (highlighted ? NSColor(srgbRed: 0xab / 255, green: 1, blue: 0x5a / 255, alpha: 1) : NSColor(white: 1, alpha: 0.45)).setStroke()
        corners.stroke()

        let title = NSAttributedString(string: "Drag and drop a video", attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor(white: 1, alpha: 0.85),
        ])
        let sz = title.size()
        title.draw(at: NSPoint(x: box.midX - sz.width / 2, y: box.midY - 14))
    }
}

// MARK: - Edge glow

// A soft ring of colour around the window edge that says "yes, I've got it":
// it rises while a file is dragged over the window and pulses once when a
// video loads. A conic gradient in VasavanOS colours spins underneath a mask
// made of the blurs of two outlines that sit just outside the window.
final class GlowView: NSView {
    private let gradient = CAGradientLayer()
    private let ring = CALayer()
    private let near = CAShapeLayer()
    private let soft = CAShapeLayer()
    private let edgeStroke: CGFloat = 40

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        alphaValue = 0
        let lime = NSColor(srgbRed: 0xab / 255, green: 1, blue: 0x5a / 255, alpha: 1)   // --color-1
        let pink = NSColor(srgbRed: 1, green: 0xc0 / 255, blue: 1, alpha: 1)            // --color-3
        let cyan = NSColor(srgbRed: 0x80 / 255, green: 0xd8 / 255, blue: 0xe8 / 255, alpha: 1) // --color-4
        gradient.type = .conic
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.endPoint = CGPoint(x: 0.5, y: 0)
        gradient.colors = [lime, cyan, pink, lime, cyan, pink, lime].map(\.cgColor)
        layer?.addSublayer(gradient)

        // Each outline sits just outside the window, so none of its solid
        // stroke shows: only its blur falls inward. Wide and faint, then
        // close and brighter.
        for (shape, blur, opacity) in [(soft, 44.0, 0.9), (near, 14.0, 0.7)] {
            shape.fillColor = nil
            shape.strokeColor = NSColor.black.cgColor
            shape.lineWidth = edgeStroke
            shape.shadowColor = NSColor.black.cgColor
            shape.shadowOffset = .zero
            shape.shadowRadius = blur
            shape.shadowOpacity = 1
            shape.opacity = Float(opacity)
            ring.addSublayer(shape)
        }
        layer?.mask = ring

        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = -2 * Double.pi
        spin.duration = 5
        spin.repeatCount = .infinity
        gradient.add(spin, forKey: "spin")
    }
    required init?(coder: NSCoder) { fatalError() }

    override func hitTest(_ point: NSPoint) -> NSView? { nil } // never takes a click

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // Big enough to cover the window at any angle of the spin.
        let side = hypot(bounds.width, bounds.height)
        gradient.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        gradient.position = CGPoint(x: bounds.midX, y: bounds.midY)
        ring.frame = bounds
        // Outset by half the stroke, so the stroke's inner edge is the window edge.
        let r = bounds.insetBy(dx: -edgeStroke / 2, dy: -edgeStroke / 2)
        let path = CGPath(roundedRect: r, cornerWidth: 18 + edgeStroke / 2, cornerHeight: 18 + edgeStroke / 2, transform: nil)
        near.path = path
        soft.path = path
        CATransaction.commit()
    }

    private var fadeWork: DispatchWorkItem?

    private func fade(to a: CGFloat, over d: TimeInterval) {
        NSAnimationContext.runAnimationGroup { c in
            c.duration = d
            c.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            animator().alphaValue = a
        }
    }

    // While a file hovers over the window.
    func show() { fadeWork?.cancel(); fade(to: 1, over: 0.25) }
    func hide() { fadeWork?.cancel(); fade(to: 0, over: 0.35) }

    // A file arrived: flare, hold a beat, fade.
    func pulse() {
        fadeWork?.cancel()
        fade(to: 1, over: 0.15)
        let work = DispatchWorkItem { [weak self] in self?.fade(to: 0, over: 1.1) }
        fadeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}

// MARK: - Stage

final class StageView: NSView {
    let player = AVPlayer()
    let playerLayer = AVPlayerLayer()
    let timeDial = DialView()
    let speedDial = DialView()
    let mirrorButton = MirrorButton()
    let dropZone = DropZone()
    let glow = GlowView()
    private var controls: [NSView] { [timeDial, speedDial, mirrorButton] }

    private let defaults = UserDefaults.standard
    private var speed: Double
    private var mirror: Bool
    private var align: Align

    private var downPoint: NSPoint?
    private var dragOffset: CGFloat?
    private var clickTimer: Timer?
    private var idleTimer: Timer?
    private var wheelAcc: CGFloat = 0
    private var switchingSides = false
    private var dialOnLeft = false
    private var sizeObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var timeObserver: Any?
    private var markedDuration = 0.0

    private var hasVideo: Bool { player.currentItem != nil }

    override init(frame: NSRect) {
        let saved = defaults.double(forKey: "speed")
        speed = saved > 0 ? saved : 1
        mirror = defaults.bool(forKey: "mirror")
        align = Align(rawValue: defaults.integer(forKey: "align")) ?? .center
        super.init(frame: frame)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        playerLayer.backgroundColor = NSColor.black.cgColor
        playerLayer.isHidden = true // until a video loads, so the drop zone shows
        layer?.addSublayer(playerLayer)
        addSubview(dropZone)

        let count = Int(((maxSpeed - minSpeed) / step).rounded())
        speedDial.marks = (1..<count).map { CGFloat($0) / CGFloat(count) }
        speedDial.onScrub = { [weak self] f in self?.setSpeed(minSpeed + f * (maxSpeed - minSpeed)) }
        timeDial.onScrub = { [weak self] f in self?.seek(toFraction: f) }
        mirrorButton.onClick = { [weak self] in self?.setMirror(!(self?.mirror ?? false)) }
        for v in controls {
            addSubview(v)
            v.isHidden = true
        }
        addSubview(glow) // last, so it rings everything

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30), queue: .main
        ) { [weak self] _ in self?.updateTime() }

        registerForDraggedTypes([.fileURL])
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self))

        setSpeed(speed)
        setMirror(mirror)
    }
    required init?(coder: NSCoder) { fatalError() }

    override var acceptsFirstResponder: Bool { true }

    // MARK: Loading

    func load(_ url: URL) {
        let item = AVPlayerItem(url: url)
        item.audioTimePitchAlgorithm = .spectral // holds up across 0.25x to 3x
        if let o = endObserver { NotificationCenter.default.removeObserver(o) }
        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification, object: item, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.player.seek(to: .zero)
            self.player.rate = Float(self.speed)
        }
        sizeObservation = item.observe(\.presentationSize) { [weak self] _, _ in
            DispatchQueue.main.async { self?.layoutVideo(animated: false) }
        }
        player.replaceCurrentItem(with: item)
        window?.title = url.lastPathComponent
        playerLayer.isHidden = false
        dropZone.isHidden = true
        controls.forEach { $0.isHidden = false }
        markedDuration = 0
        timeDial.set(fraction: 0, text: timeLabel(0), animated: false)
        needsLayout = true
        glow.pulse()
        wake()
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.movie]
        if panel.runModal() == .OK, let url = panel.url { load(url) }
    }

    // MARK: Layout

    private func fittedSize() -> CGSize {
        let ps = player.currentItem?.presentationSize ?? .zero
        guard ps.width > 0, ps.height > 0 else { return bounds.size }
        return AVMakeRect(aspectRatio: ps, insideRect: bounds).size
    }
    // How far the video can travel from centre before it touches an edge.
    private func slack() -> CGFloat { max(0, (bounds.width - fittedSize().width) / 2) }

    override func layout() {
        super.layout()
        dropZone.frame = bounds
        glow.frame = bounds
        layoutVideo(animated: false)
        layoutDial()
    }

    private func layoutVideo(animated: Bool) {
        let size = fittedSize()
        let offset = dragOffset ?? CGFloat(align.rawValue) * slack()
        CATransaction.begin()
        CATransaction.setDisableActions(!animated)
        CATransaction.setAnimationDuration(0.28)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.2, 0.8, 0.2, 1))
        playerLayer.bounds = CGRect(origin: .zero, size: size)
        playerLayer.position = CGPoint(x: bounds.midX + offset, y: bounds.midY)
        playerLayer.transform = mirror ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
        CATransaction.commit()
    }

    // One column on the edge the video isn't on (right when centred): time,
    // speed, mirror, centred together.
    private func layoutDial() {
        dialOnLeft = align == .right
        let w: CGFloat = 40, inset: CGFloat = 16, gap: CGFloat = 8
        let h = max(80, min(200, (bounds.height * 0.8 - w - 2 * gap) / 2))
        let x = dialOnLeft ? inset : bounds.width - inset - w
        let bottom = (bounds.height - (2 * h + w + 2 * gap)) / 2
        mirrorButton.frame = NSRect(x: x, y: bottom, width: w, height: w)
        speedDial.frame = NSRect(x: x, y: bottom + w + gap, width: w, height: h)
        timeDial.frame = NSRect(x: x, y: bottom + w + h + 2 * gap, width: w, height: h)
    }

    // MARK: Time

    private var duration: Double {
        let d = player.currentItem?.duration.seconds ?? 0
        return d.isFinite && d > 0 ? d : 0
    }

    private func updateTime() {
        let d = duration
        guard d > 0 else { return }
        let t = player.currentTime().seconds
        timeDial.set(fraction: CGFloat(t / d), text: timeLabel(t), animated: false)
        if markedDuration != d {
            // The smallest interval that gives at most 12 hashmarks.
            markedDuration = d
            let every = [1.0, 2, 5, 10, 15, 30, 60, 120, 300, 600, 1800].first { d / $0 <= 12 } ?? 3600
            timeDial.marks = stride(from: every, to: d, by: every).map { CGFloat($0 / d) }
        }
    }

    private func seek(toFraction f: Double) {
        let d = duration
        guard d > 0 else { return }
        player.seek(to: CMTime(seconds: f * d, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        timeDial.set(fraction: CGFloat(f), text: timeLabel(f * d), animated: false)
        wake()
    }

    // MARK: State

    func setSpeed(_ s: Double) {
        speed = min(maxSpeed, max(minSpeed, (s / step).rounded() * step))
        player.defaultRate = Float(speed)
        if player.rate != 0 { player.rate = Float(speed) }
        speedDial.set(fraction: CGFloat((speed - minSpeed) / (maxSpeed - minSpeed)), text: speedLabel(speed), animated: true)
        defaults.set(speed, forKey: "speed")
        wake()
    }

    func setMirror(_ on: Bool) {
        mirror = on
        mirrorButton.on = on
        defaults.set(on, forKey: "mirror")
        layoutVideo(animated: true)
        wake()
    }

    func setAlign(_ a: Align) {
        let sideChanges = (a == .right) != dialOnLeft
        align = a
        defaults.set(a.rawValue, forKey: "align")
        layoutVideo(animated: true)
        guard sideChanges else { wake(); return }
        switchingSides = true
        NSAnimationContext.runAnimationGroup({ c in
            c.duration = 0.12
            controls.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: {
            self.layoutDial()
            NSAnimationContext.runAnimationGroup({ c in
                c.duration = 0.2
                self.controls.forEach { $0.animator().alphaValue = 1 }
            }, completionHandler: {
                self.switchingSides = false
                self.wake()
            })
        })
    }

    private func togglePlay() {
        guard hasVideo else { return }
        if player.rate == 0 { player.rate = Float(speed) } else { player.pause() }
        wake()
    }

    // Controls dim to 30% after 2 s of untouched playback, and the cursor hides.
    private func wake() {
        idleTimer?.invalidate()
        if !switchingSides {
            NSAnimationContext.runAnimationGroup { c in
                c.duration = 0.2
                controls.forEach { $0.animator().alphaValue = 1 }
            }
        }
        idleTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            guard let self, self.player.rate != 0, !self.switchingSides else { return }
            NSAnimationContext.runAnimationGroup { c in
                c.duration = 0.4
                self.controls.forEach { $0.animator().alphaValue = 0.3 }
            }
            NSCursor.setHiddenUntilMouseMoves(true)
        }
    }

    // MARK: Input

    override func mouseMoved(with e: NSEvent) { wake() }

    override func mouseDown(with e: NSEvent) {
        guard hasVideo else { return }
        downPoint = convert(e.locationInWindow, from: nil)
    }

    // Drag sideways to move the video; it settles on the left edge, centre or right edge.
    override func mouseDragged(with e: NSEvent) {
        guard hasVideo, let d = downPoint else { return }
        let p = convert(e.locationInWindow, from: nil)
        if dragOffset == nil && abs(p.x - d.x) < 4 { return }
        let s = slack()
        dragOffset = max(-s, min(s, CGFloat(align.rawValue) * s + (p.x - d.x)))
        layoutVideo(animated: false)
        wake()
    }

    override func mouseUp(with e: NSEvent) {
        defer { downPoint = nil }
        guard hasVideo else { return }
        if let o = dragOffset {
            let s = slack()
            dragOffset = nil
            setAlign(s < 1 ? .center : o < -s / 3 ? .left : o > s / 3 ? .right : .center)
            return
        }
        if e.clickCount >= 2 {
            clickTimer?.invalidate()
            window?.toggleFullScreen(nil)
        } else {
            clickTimer = Timer.scheduledTimer(withTimeInterval: NSEvent.doubleClickInterval, repeats: false) { [weak self] _ in
                self?.togglePlay()
            }
        }
    }

    override func scrollWheel(with e: NSEvent) {
        guard hasVideo else { return }
        wheelAcc += e.scrollingDeltaY
        let threshold: CGFloat = e.hasPreciseScrollingDeltas ? 30 : 1
        if abs(wheelAcc) >= threshold {
            setSpeed(speed + (wheelAcc > 0 ? step : -step))
            wheelAcc = 0
        }
    }

    override func keyDown(with e: NSEvent) {
        guard hasVideo else { return super.keyDown(with: e) }
        switch e.keyCode {
        case 49: togglePlay()                                   // space
        case 126: setSpeed(speed + step)                        // up
        case 125: setSpeed(speed - step)                        // down
        case 123: seek(by: -2)                                  // left
        case 124: seek(by: 2)                                   // right
        default:
            switch e.charactersIgnoringModifiers?.lowercased() {
            case "m": setMirror(!mirror)
            case "f": window?.toggleFullScreen(nil)
            case "0": player.seek(to: .zero)
            case "[": setAlign(Align(rawValue: max(-1, align.rawValue - 1))!)
            case "]": setAlign(Align(rawValue: min(1, align.rawValue + 1))!)
            default: super.keyDown(with: e)
            }
        }
    }

    private func seek(by seconds: Double) {
        let t = max(0, player.currentTime().seconds + seconds)
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600))
    }

    // MARK: Drop

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        dropZone.highlighted = true
        glow.show()
        return .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) {
        dropZone.highlighted = false
        glow.hide()
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        dropZone.highlighted = false
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]
        guard let url = urls?.first else { return false }
        load(url)
        return true
    }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let stage = StageView(frame: NSRect(x: 0, y: 0, width: 1100, height: 720))

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        NSApp.mainMenu = makeMenu()

        window = NSWindow(
            contentRect: stage.frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .black
        window.collectionBehavior = [.fullScreenPrimary]
        window.contentView = stage
        window.center()
        window.setFrameAutosaveName("Refeed")
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(stage)
        NSApp.activate(ignoringOtherApps: true)
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        if let url = urls.first { stage.load(url) }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    private func makeMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Hide Refeed", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Refeed", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…", action: #selector(StageView.openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu
        main.addItem(fileItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        let fs = windowMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fs.keyEquivalentModifierMask = [.control, .command]
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        return main
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
