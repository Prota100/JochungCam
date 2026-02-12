import SwiftUI

/// Interactive crop overlay that lets users drag to select a region on the preview image
struct CropOverlayView: View {
    @Binding var cropRect: CGRect  // normalized 0..1
    let imageSize: CGSize
    @State private var dragStart: CGPoint?
    @State private var activeHandle: Handle?
    @State private var dragOffset: CGSize = .zero

    enum Handle { case topLeft, topRight, bottomLeft, bottomRight, body }

    var body: some View {
        GeometryReader { geo in
            let displaySize = fitSize(imageSize, in: geo.size)
            let offset = CGPoint(
                x: (geo.size.width - displaySize.width) / 2,
                y: (geo.size.height - displaySize.height) / 2
            )

            ZStack {
                // Dimmed area outside crop
                CropDimOverlay(cropRect: cropRect, displaySize: displaySize, offset: offset)

                // Crop border
                let rect = denormalize(cropRect, displaySize: displaySize, offset: offset)
                Rectangle()
                    .strokeBorder(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                // Grid lines (rule of thirds)
                Path { path in
                    let r = rect
                    for i in 1...2 {
                        let x = r.minX + r.width * CGFloat(i) / 3
                        path.move(to: CGPoint(x: x, y: r.minY))
                        path.addLine(to: CGPoint(x: x, y: r.maxY))
                        let y = r.minY + r.height * CGFloat(i) / 3
                        path.move(to: CGPoint(x: r.minX, y: y))
                        path.addLine(to: CGPoint(x: r.maxX, y: y))
                    }
                }.stroke(Color.white.opacity(0.3), lineWidth: 0.5)

                // Size label
                let imgW = Int(cropRect.width * imageSize.width)
                let imgH = Int(cropRect.height * imageSize.height)
                Text("\(imgW)×\(imgH)")
                    .font(.caption2.monospaced()).foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(3)
                    .position(x: rect.midX, y: rect.maxY + 14)

                // Drag handles
                ForEach([Handle.topLeft, .topRight, .bottomLeft, .bottomRight], id: \.self) { handle in
                    let pos = handlePosition(handle, rect: rect)
                    Circle().fill(Color.yellow).frame(width: 12, height: 12)
                        .position(pos)
                        .gesture(handleDrag(handle, displaySize: displaySize, offset: offset))
                }

                // Body drag (move entire crop)
                Rectangle().fill(Color.clear).contentShape(Rectangle())
                    .frame(width: max(0, rect.width - 24), height: max(0, rect.height - 24))
                    .position(x: rect.midX, y: rect.midY)
                    .gesture(bodyDrag(displaySize: displaySize, offset: offset))
            }
        }
    }

    // MARK: - Gestures

    func handleDrag(_ handle: Handle, displaySize: CGSize, offset: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let p = CGPoint(
                    x: (value.location.x - offset.x) / displaySize.width,
                    y: (value.location.y - offset.y) / displaySize.height
                )
                var r = cropRect
                switch handle {
                case .topLeft:
                    r.origin.x = min(p.x, r.maxX - 0.02)
                    r.origin.y = min(p.y, r.maxY - 0.02)
                    r.size.width = cropRect.maxX - r.origin.x
                    r.size.height = cropRect.maxY - r.origin.y
                case .topRight:
                    r.size.width = max(0.02, p.x - r.origin.x)
                    r.origin.y = min(p.y, r.maxY - 0.02)
                    r.size.height = cropRect.maxY - r.origin.y
                case .bottomLeft:
                    r.origin.x = min(p.x, r.maxX - 0.02)
                    r.size.width = cropRect.maxX - r.origin.x
                    r.size.height = max(0.02, p.y - r.origin.y)
                case .bottomRight:
                    r.size.width = max(0.02, p.x - r.origin.x)
                    r.size.height = max(0.02, p.y - r.origin.y)
                case .body: break
                }
                cropRect = clampRect(r)
            }
    }

    func bodyDrag(displaySize: CGSize, offset: CGPoint) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let dx = value.translation.width / displaySize.width
                let dy = value.translation.height / displaySize.height
                var r = cropRect
                r.origin.x = max(0, min(1 - r.width, cropRect.origin.x + dx - dragOffset.width))
                r.origin.y = max(0, min(1 - r.height, cropRect.origin.y + dy - dragOffset.height))
                dragOffset = CGSize(width: dx, height: dy)
                cropRect = r
            }
            .onEnded { _ in dragOffset = .zero }
    }

    // MARK: - Helpers

    func handlePosition(_ handle: Handle, rect: CGRect) -> CGPoint {
        switch handle {
        case .topLeft: return CGPoint(x: rect.minX, y: rect.minY)
        case .topRight: return CGPoint(x: rect.maxX, y: rect.minY)
        case .bottomLeft: return CGPoint(x: rect.minX, y: rect.maxY)
        case .bottomRight: return CGPoint(x: rect.maxX, y: rect.maxY)
        case .body: return CGPoint(x: rect.midX, y: rect.midY)
        }
    }

    func denormalize(_ r: CGRect, displaySize: CGSize, offset: CGPoint) -> CGRect {
        CGRect(
            x: r.origin.x * displaySize.width + offset.x,
            y: r.origin.y * displaySize.height + offset.y,
            width: r.width * displaySize.width,
            height: r.height * displaySize.height
        )
    }

    func fitSize(_ img: CGSize, in container: CGSize) -> CGSize {
        let scale = min(container.width / img.width, container.height / img.height)
        return CGSize(width: img.width * scale, height: img.height * scale)
    }

    func clampRect(_ r: CGRect) -> CGRect {
        var out = r
        out.origin.x = max(0, out.origin.x)
        out.origin.y = max(0, out.origin.y)
        out.size.width = min(out.width, 1 - out.origin.x)
        out.size.height = min(out.height, 1 - out.origin.y)
        return out
    }
}

// Hashable conformance for Handle
extension CropOverlayView.Handle: Hashable {}

struct CropDimOverlay: View {
    let cropRect: CGRect
    let displaySize: CGSize
    let offset: CGPoint

    var body: some View {
        Canvas { ctx, size in
            // Full dim
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black.opacity(0.5)))
            // Cut out crop area
            let r = CGRect(
                x: cropRect.origin.x * displaySize.width + offset.x,
                y: cropRect.origin.y * displaySize.height + offset.y,
                width: cropRect.width * displaySize.width,
                height: cropRect.height * displaySize.height
            )
            ctx.blendMode = .clear
            ctx.fill(Path(r), with: .color(.white))
        }
        .allowsHitTesting(false)
    }
}
