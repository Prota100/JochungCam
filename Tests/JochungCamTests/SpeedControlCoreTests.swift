import Foundation
import Testing
@testable import JochungCam

struct SpeedControlCoreTests {

    @Test("currentSpeedMultiplier baseline 15fps is 1x")
    func currentSpeedBaseline() {
        let durations: [TimeInterval] = [1.0 / 15.0, 1.0 / 15.0]
        let multiplier = SpeedControlCore.currentSpeedMultiplier(durations: durations)
        #expect(abs(multiplier - 1.0) < 0.0001)
    }

    @Test("currentSpeedMultiplier clamps to 0.25...4.0")
    func currentSpeedClamp() {
        let verySlow: [TimeInterval] = [10.0, 10.0]
        #expect(abs(SpeedControlCore.currentSpeedMultiplier(durations: verySlow) - 0.25) < 0.0001)

        let veryFast: [TimeInterval] = [0.001, 0.001]
        #expect(abs(SpeedControlCore.currentSpeedMultiplier(durations: veryFast) - 4.0) < 0.0001)
    }

    @Test("resetMultiplier computes inverse for baseline recovery")
    func resetMultiplier() {
        let durations: [TimeInterval] = [0.10, 0.10]
        let reset = SpeedControlCore.resetMultiplier(durations: durations)
        #expect(abs(reset - 1.5) < 0.0001)
    }

    @Test("quickAdjustedMultiplier enforces 0.1...10.0 bounds")
    func quickAdjustBounds() {
        #expect(abs((SpeedControlCore.quickAdjustedMultiplier(current: 1.0, step: 1.1) ?? 0) - 1.1) < 0.0001)
        #expect(SpeedControlCore.quickAdjustedMultiplier(current: 10.0, step: 1.1) == nil)
        #expect(SpeedControlCore.quickAdjustedMultiplier(current: 0.1, step: 0.9) == nil)
    }

    @Test("previewInterval uses deterministic minimum of 33ms")
    func previewIntervalFloor() {
        let interval = SpeedControlCore.previewInterval(durations: [0.001, 0.001], multiplier: 4.0)
        #expect(abs(interval - 0.033) < 0.000001)
    }
}
