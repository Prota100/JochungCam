import Foundation
import CoreGraphics
import Testing
@testable import JochungCam

struct FrameOpsTests {

    @Test("mergeShortFrames merges consecutive durations")
    func mergeShortFrames() {
        var frames = makeFrames([0.02, 0.03, 0.02, 0.08, 0.01])
        FrameOps.mergeShortFrames(minDuration: 0.05, frames: &frames)

        #expect(frames.count == 3)
        #expect(abs(frames[0].duration - 0.07) < 0.001)
        #expect(abs(frames[1].duration - 0.08) < 0.001)
        #expect(abs(frames[2].duration - 0.01) < 0.001)
    }

    @Test("removeStaticSequences compacts static runs and preserves total duration")
    func removeStaticSequences() {
        let staticImage = TestImageFactory.makeSolid(red: 1, green: 0, blue: 0)
        let dynamic1 = TestImageFactory.makeSolid(red: 0, green: 1, blue: 0)
        let dynamic2 = TestImageFactory.makeSolid(red: 0, green: 0, blue: 1)

        var frames: [GIFFrame] = [
            GIFFrame(image: staticImage, duration: 0.1),
            GIFFrame(image: staticImage, duration: 0.1),
            GIFFrame(image: staticImage, duration: 0.1),
            GIFFrame(image: staticImage, duration: 0.1),
            GIFFrame(image: dynamic1, duration: 0.1),
            GIFFrame(image: dynamic2, duration: 0.1),
        ]

        let beforeDuration = frames.reduce(0) { $0 + $1.duration }
        FrameOps.removeStaticSequences(frames: &frames)
        let afterDuration = frames.reduce(0) { $0 + $1.duration }

        #expect(frames.count < 6)
        #expect(abs(afterDuration - beforeDuration) < 0.0001)
    }

    @Test("aggressiveOptimize handles edge cases and reduces when target is strict")
    func aggressiveOptimizeEdgeCases() {
        var emptyFrames: [GIFFrame] = []
        FrameOps.aggressiveOptimize(frames: &emptyFrames, targetSizeKB: 500)
        #expect(emptyFrames.isEmpty)

        var single = [GIFFrame(image: TestImageFactory.makeSolid(), duration: 1.0)]
        FrameOps.aggressiveOptimize(frames: &single, targetSizeKB: 500)
        #expect(single.count == 1)

        var medium = makeFrames(Array(repeating: 0.1, count: 20))
        let before = medium.count
        FrameOps.aggressiveOptimize(frames: &medium, targetSizeKB: 10)
        #expect(medium.count < before)
    }

    @Test("estimateGIFSize returns positive plausible size")
    func estimateGIFSize() {
        let frames = makeFrames([0.1, 0.1, 0.1])
        let size = FrameOps.estimateGIFSize(frames)
        #expect(size > 0)
        #expect(size < 100_000)
    }

    @Test("adjustSpeed clamps minimum duration to 0.01")
    func adjustSpeedClamp() {
        var frames = makeFrames([0.02, 0.03])
        FrameOps.adjustSpeed(100.0, frames: &frames)

        #expect(abs(frames[0].duration - 0.01) < 0.0001)
        #expect(abs(frames[1].duration - 0.01) < 0.0001)
    }

    private func makeFrames(_ durations: [TimeInterval]) -> [GIFFrame] {
        durations.enumerated().map { index, duration in
            GIFFrame(image: TestImageFactory.makeSolid(red: CGFloat(index % 2), green: 0, blue: 1), duration: duration)
        }
    }
}
