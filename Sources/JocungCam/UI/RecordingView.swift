import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var recorder: ScreenRecorder

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Status badge
            HStack(spacing: 8) {
                if appState.mode == .recording {
                    PulsingDot(color: HCTheme.recording)
                } else {
                    Circle().fill(Color.orange).frame(width: 8, height: 8)
                }
                Text(appState.mode == .recording ? "REC" : "PAUSED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(appState.mode == .recording ? HCTheme.recording : .orange)
            }
            .padding(.horizontal, 12).padding(.vertical, 5)
            .background(Capsule().fill(appState.mode == .recording ? HCTheme.recording.opacity(0.1) : Color.orange.opacity(0.1)))
            .overlay(Capsule().stroke(appState.mode == .recording ? HCTheme.recording.opacity(0.3) : Color.orange.opacity(0.3)))

            Spacer().frame(height: 20)

            // Timer
            Text(formatTime(appState.recordingDuration))
                .font(HCTheme.display)
                .foregroundColor(HCTheme.textPrimary)

            Spacer().frame(height: 12)

            // Stats row
            HStack(spacing: 20) {
                HCStat(label: "프레임", value: "\(appState.frameCount)")
                HCStat(label: "FPS", value: "\(appState.fps)")
                HCStat(label: "영역", value: regionText)
            }

            Spacer().frame(height: 8)

            // Progress bar (time limit)
            if appState.maxRecordSeconds > 0 {
                let progress = appState.recordingDuration / Double(appState.maxRecordSeconds)
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(HCTheme.border).frame(height: 3)
                            RoundedRectangle(cornerRadius: 2).fill(progress > 0.8 ? HCTheme.recording : HCTheme.accent)
                                .frame(width: geo.size.width * min(1, progress), height: 3)
                        }
                    }.frame(height: 3).frame(width: 180)
                    Text("\(Int(appState.recordingDuration))s / \(appState.maxRecordSeconds)s")
                        .font(HCTheme.microMono).foregroundColor(HCTheme.textTertiary)
                }
            }

            Spacer()

            // Controls
            HStack(spacing: 12) {
                // Pause / Resume
                Button(action: {
                    if appState.mode == .recording { recorder.pauseRecording(appState: appState) }
                    else { recorder.resumeRecording(appState: appState) }
                }) {
                    Image(systemName: appState.mode == .recording ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(HCTheme.surfaceHover))
                        .overlay(Circle().stroke(HCTheme.border))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.space, modifiers: [])

                // Stop
                Button(action: { Task { await recorder.stopRecording(appState: appState) } }) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2).fill(Color.white).frame(width: 10, height: 10)
                        Text("완료").font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(Capsule().fill(HCTheme.recording))
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }

            Spacer().frame(height: 24)
        }
        .frame(minWidth: 300, minHeight: 260)
    }

    var regionText: String {
        let r = appState.selectedRegion
        return "\(Int(r.width))×\(Int(r.height))"
    }

    private func formatTime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, s = Int(t) % 60, ms = Int(t * 10) % 10
        return String(format: "%d:%02d.%d", m, s, ms)
    }
}
