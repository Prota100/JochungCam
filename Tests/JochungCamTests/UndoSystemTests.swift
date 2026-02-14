import Foundation
import Testing
@testable import JochungCam

struct UndoSystemTests {

    @MainActor
    @Test("execute -> undo -> redo restores expected durations")
    func executeUndoRedoCycle() {
        var frames = [
            GIFFrame(image: TestImageFactory.makeSolid(), duration: 0.10),
            GIFFrame(image: TestImageFactory.makeSolid(), duration: 0.20)
        ]

        let undo = UndoSystem(maxHistorySize: 10, maxMemoryMB: 32)
        let original = frames.map(\.duration)

        let command = SpeedAdjustCommand(speedMultiplier: 2.0, originalDurations: original)
        undo.execute(command, frames: &frames)

        #expect(abs(frames[0].duration - 0.05) < 0.0001)
        #expect(abs(frames[1].duration - 0.10) < 0.0001)
        #expect(undo.canUndo)
        #expect(!undo.canRedo)

        #expect(undo.undo(frames: &frames))
        #expect(abs(frames[0].duration - 0.10) < 0.0001)
        #expect(abs(frames[1].duration - 0.20) < 0.0001)
        #expect(undo.canRedo)

        #expect(undo.redo(frames: &frames))
        #expect(abs(frames[0].duration - 0.05) < 0.0001)
        #expect(abs(frames[1].duration - 0.10) < 0.0001)
    }

    @MainActor
    @Test("new execute clears redo stack")
    func newExecuteClearsRedoStack() {
        var frames = [
            GIFFrame(image: TestImageFactory.makeSolid(), duration: 0.10),
            GIFFrame(image: TestImageFactory.makeSolid(), duration: 0.20)
        ]

        let undo = UndoSystem(maxHistorySize: 10, maxMemoryMB: 32)

        undo.execute(
            SpeedAdjustCommand(speedMultiplier: 2.0, originalDurations: frames.map(\.duration)),
            frames: &frames
        )
        #expect(undo.undo(frames: &frames))
        #expect(undo.canRedo)

        undo.execute(
            SpeedAdjustCommand(speedMultiplier: 1.25, originalDurations: frames.map(\.duration)),
            frames: &frames
        )

        #expect(!undo.canRedo)
    }
}
