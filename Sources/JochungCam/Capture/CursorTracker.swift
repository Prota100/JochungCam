import AppKit
import CoreGraphics

/// Tracks mouse position and click events during recording, then renders highlights onto frames
final class CursorTracker: @unchecked Sendable {
    struct CursorEvent {
        let timestamp: TimeInterval  // relative to recording start
        let position: CGPoint        // screen coords
        let isLeftClick: Bool
        let isRightClick: Bool
    }

    private let lock = NSLock()
    private var _events: [CursorEvent] = []
    private var startTime: Date?
    private var captureRegion: CGRect = .zero
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var moveTimer: Timer?

    var events: [CursorEvent] { lock.withLock { _events } }

    func start(region: CGRect) {
        captureRegion = region
        startTime = Date()
        lock.withLock { _events = [] }

        // Track mouse position periodically
        DispatchQueue.main.async { [weak self] in
            self?.moveTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
                self?.recordPosition()
            }
        }

        // Track clicks
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.recordClick(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            self?.recordClick(event)
            return event
        }
    }

    func stop() {
        moveTimer?.invalidate()
        moveTimer = nil
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        globalMonitor = nil
        localMonitor = nil
    }

    private func recordPosition() {
        guard let start = startTime else { return }
        let pos = NSEvent.mouseLocation
        let t = Date().timeIntervalSince(start)
        lock.withLock {
            _events.append(CursorEvent(timestamp: t, position: pos, isLeftClick: false, isRightClick: false))
        }
    }

    private func recordClick(_ event: NSEvent) {
        guard let start = startTime else { return }
        let pos = NSEvent.mouseLocation
        let t = Date().timeIntervalSince(start)
        let isLeft = event.type == .leftMouseDown
        lock.withLock {
            _events.append(CursorEvent(timestamp: t, position: pos, isLeftClick: isLeft, isRightClick: !isLeft))
        }
    }

    // MARK: - Render cursor effects onto frames

    struct RenderOptions {
        var highlightRadius: CGFloat = 30
        var highlightColor: NSColor = .yellow.withAlphaComponent(0.3)
        var leftClickColor: NSColor = .red.withAlphaComponent(0.5)
        var rightClickColor: NSColor = .blue.withAlphaComponent(0.5)
        var clickRadius: CGFloat = 20
        var clickFadeDuration: TimeInterval = 0.3
    }

    func renderOntoFrames(_ frames: [GIFFrame], region: CGRect, scale: CGFloat, options: RenderOptions) -> [GIFFrame] {
        let allEvents = events
        guard !allEvents.isEmpty else { return frames }

        // Build timeline: cumulative timestamp for each frame
        var frameTimes: [TimeInterval] = []
        var t: TimeInterval = 0
        for f in frames {
            frameTimes.append(t)
            t += f.duration
        }

        return frames.enumerated().map { (i, frame) in
            let frameTime = frameTimes[i]
            let frameEnd = frameTime + frame.duration

            // Find cursor position for this frame (nearest event)
            let posEvent = allEvents
                .filter { !$0.isLeftClick && !$0.isRightClick }
                .min(by: { abs($0.timestamp - frameTime) < abs($1.timestamp - frameTime) })

            // Find clicks within this frame's time range (+ fade window)
            let clicks = allEvents.filter {
                ($0.isLeftClick || $0.isRightClick) &&
                $0.timestamp >= frameTime - options.clickFadeDuration &&
                $0.timestamp <= frameEnd
            }

            guard posEvent != nil || !clicks.isEmpty else { return frame }

            let w = frame.image.width
            let h = frame.image.height
            guard let ctx = CGContext(
                data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return frame }

            // Draw original frame
            ctx.draw(frame.image, in: CGRect(x: 0, y: 0, width: w, height: h))

            // Convert screen coords to image coords
            func toImageCoords(_ screenPos: CGPoint) -> CGPoint {
                let x = (screenPos.x - region.minX) * scale
                // Flip Y: screen coords have origin at bottom-left, image at top-left
                let y = CGFloat(h) - (screenPos.y - region.minY) * scale
                return CGPoint(x: x, y: y)
            }

            // Draw highlight circle at cursor position
            if let pos = posEvent {
                let p = toImageCoords(pos.position)
                let r = options.highlightRadius * scale
                ctx.setFillColor(options.highlightColor.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            }

            // Draw click effects
            for click in clicks {
                let p = toImageCoords(click.position)
                let age = frameTime - click.timestamp
                let alpha = max(0, 1.0 - age / options.clickFadeDuration)
                let r = options.clickRadius * scale * CGFloat(1.0 + (1.0 - alpha) * 0.5)

                let color = click.isLeftClick ? options.leftClickColor : options.rightClickColor
                let fadedColor = color.withAlphaComponent(color.alphaComponent * CGFloat(alpha))
                ctx.setFillColor(fadedColor.cgColor)
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
            }

            guard let img = ctx.makeImage() else { return frame }
            return GIFFrame(image: img, duration: frame.duration)
        }
    }
}
