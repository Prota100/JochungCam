import Foundation
import Testing
@testable import JochungCam

struct MOVImportSmokeTests {

    @Test("importVideo can read local test_sample.mov")
    func importLocalMOV() async {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let movURL = cwd.appendingPathComponent("test_sample.mov")

        #expect(FileManager.default.fileExists(atPath: movURL.path))

        let frames = await FrameOps.importVideo(from: movURL, fps: 30, progress: nil)

        #expect(frames != nil)
        #expect((frames?.isEmpty ?? true) == false)

        if let frames {
            #expect(frames.count > 1)
            #expect(frames.allSatisfy { $0.duration > 0 })
        }
    }
}
