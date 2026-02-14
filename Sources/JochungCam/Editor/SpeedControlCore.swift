import Foundation

enum SpeedControlCore {
    static let baselineFPS: Double = 15.0

    static func currentSpeedMultiplier(durations: [TimeInterval]) -> Double {
        guard !durations.isEmpty else { return 1.0 }
        let total = durations.reduce(0, +)
        let avgDuration = total / Double(durations.count)
        let standardDuration = 1.0 / baselineFPS
        let raw = standardDuration / avgDuration
        return max(0.25, min(4.0, raw))
    }

    static func resetMultiplier(durations: [TimeInterval]) -> Double {
        guard !durations.isEmpty else { return 1.0 }
        let total = durations.reduce(0, +)
        let currentAvg = total / Double(durations.count)
        let target = 1.0 / baselineFPS
        return currentAvg / target
    }

    static func quickAdjustedMultiplier(current: Double, step: Double) -> Double? {
        let next = current * step
        guard next >= 0.1, next <= 10.0 else { return nil }
        return next
    }

    static func previewInterval(durations: [TimeInterval], multiplier: Double) -> TimeInterval {
        guard !durations.isEmpty, multiplier > 0 else { return 0.033 }
        let avg = durations.reduce(0, +) / Double(durations.count)
        return max(0.033, avg / multiplier)
    }
}
