import Foundation

public enum Trend: Sendable, Hashable {
    case up
    case flat
    case down

    public init(fitnessDelta delta: Double) {
        if delta > 0.5 {
            self = .up
        } else if delta < -0.5 {
            self = .down
        } else {
            self = .flat
        }
    }

    public static func fitness(_ series: [LoadPoint]) -> (trend: Trend, delta: Double)? {
        guard series.count >= 8, let last = series.last else { return nil }
        let delta = last.fitness - series[series.count - 8].fitness
        return (Trend(fitnessDelta: delta), delta)
    }

    public static func volume(_ weeks: [Double]) -> Trend? {
        guard let last = weeks.last else { return nil }
        let previous = weeks.dropLast().suffix(3)
        let average = previous.isEmpty ? 0 : previous.reduce(0, +) / Double(previous.count)
        guard average > 0 else { return last > 0 ? .up : nil }
        let change = (last - average) / average
        if change > 0.05 { return .up }
        if change < -0.05 { return .down }
        return .flat
    }
}

extension Double {
    public var displayRounded: Int {
        Int(jsRound(self))
    }
}
