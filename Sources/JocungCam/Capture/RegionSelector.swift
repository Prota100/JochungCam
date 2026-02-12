import AppKit

final class RegionSelectorWindow: NSPanel {
    var onSelected: ((CGRect) -> Void)?
    var onCancelled: (() -> Void)?
    private var origin: NSPoint?
    private var selection: CGRect = .zero
    private let overlay: SelectionOverlay

    init() {
        overlay = SelectionOverlay()

        // Cover all screens
        var fullRect = CGRect.zero
        for screen in NSScreen.screens { fullRect = fullRect.union(screen.frame) }

        super.init(
            contentRect: fullRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        contentView = overlay
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }

    override func mouseDown(with event: NSEvent) {
        origin = event.locationInWindow
        overlay.sel = .zero
        overlay.needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let o = origin else { return }
        let p = event.locationInWindow
        selection = CGRect(
            x: min(o.x, p.x), y: min(o.y, p.y),
            width: abs(p.x - o.x), height: abs(p.y - o.y)
        )
        overlay.sel = selection
        overlay.needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard selection.width > 20, selection.height > 20 else { return }
        guard let screen = NSScreen.main else { return }
        // AppKit coords → ScreenCaptureKit coords (flip Y)
        let y = screen.frame.height - selection.maxY
        let result = CGRect(x: selection.minX, y: y, width: selection.width, height: selection.height)
        close()
        onSelected?(result)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { close(); onCancelled?() }
    }
}

private final class SelectionOverlay: NSView {
    var sel: CGRect = .zero

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Dim background
        ctx.setFillColor(NSColor.black.withAlphaComponent(0.3).cgColor)
        ctx.fill(bounds)

        if sel.width > 0, sel.height > 0 {
            // Clear selected area
            ctx.clear(sel)

            // Yellow border
            ctx.setStrokeColor(NSColor.systemYellow.cgColor)
            ctx.setLineWidth(2)
            ctx.setLineDash(phase: 0, lengths: [6, 4])
            ctx.stroke(sel)

            // Size label
            let text = "\(Int(sel.width))×\(Int(sel.height))"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.white
            ]
            let size = (text as NSString).size(withAttributes: attrs)

            // Background for label
            let labelRect = CGRect(
                x: sel.minX, y: sel.minY - size.height - 6,
                width: size.width + 12, height: size.height + 4
            )
            ctx.setFillColor(NSColor.black.withAlphaComponent(0.75).cgColor)
            ctx.fill(labelRect)
            (text as NSString).draw(
                at: NSPoint(x: labelRect.minX + 6, y: labelRect.minY + 2),
                withAttributes: attrs
            )
        } else {
            // Instructions
            let text = "드래그로 캡처 영역 선택  ·  ESC 취소"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.9)
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(
                at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY),
                withAttributes: attrs
            )
        }
    }
}
