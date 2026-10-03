import Foundation

public struct RacePrediction: Hashable, Sendable {
    public let discipline: Discipline
    public let time: TimeInterval
    public let distance: Double
    public let effortDistance: Double
    public let effortDuration: TimeInterval
    public let effortDate: Date
    public let exponent: Double
}

public enum RacePredictor {
    static let windowWeeks = 12
    static let marathon = 42_200.0
    static let longRunPenalty = 0.14
    static let volumePenalty = 0.093
    static let maxExponent = 1.3

    struct Limits {
        let minDistance: Double
        let minDuration: TimeInterval
        let maxSpeed: Double
        let exponent: Double
        let longestReference: Double
    }

    static func limits(for discipline: Discipline) -> Limits? {
        switch discipline {
        case .run: Limits(minDistance: 3_000, minDuration: 12 * 60, maxSpeed: 6.2, exponent: 1.06, longestReference: marathon)
        case .swim: Limits(minDistance: 400, minDuration: 6 * 60, maxSpeed: 2.0, exponent: 1.04, longestReference: 10_000)
        default: nil
        }
    }

    public static func predict(
        config: RaceConfig,
        activities: [Activity],
        longest: Double,
        volumeRatio: Double,
        now: Date
    ) -> RacePrediction? {
        guard config.distance.sport != .triathlon,
              let discipline = config.distance.disciplines.first,
              let limits = limits(for: discipline) else { return nil }

        let cutoff = now.addingTimeInterval(-Double(windowWeeks) * ReadinessCalculator.week)
        let efforts = activities.filter { activity in
            guard activity.discipline == discipline,
                  activity.start >= cutoff,
                  activity.start <= now,
                  let distance = activity.distance,
                  distance >= limits.minDistance,
                  activity.duration >= limits.minDuration else { return false }
            return distance / activity.duration <= limits.maxSpeed
        }

        var best: RacePrediction?
        for effort in efforts {
            guard let effortDistance = effort.distance else { continue }
            let prediction: RacePrediction
            if let timeLimit = config.timeLimit {
                var distance = effortDistance * pow(timeLimit / effort.duration, 1 / limits.exponent)
                var exponent = limits.exponent
                for _ in 0..<3 {
                    exponent = self.exponent(limits, discipline: discipline, raceDistance: distance, effortDistance: effortDistance, longest: longest, volumeRatio: volumeRatio)
                    distance = effortDistance * pow(timeLimit / effort.duration, 1 / exponent)
                }
                prediction = RacePrediction(
                    discipline: discipline,
                    time: timeLimit,
                    distance: distance,
                    effortDistance: effortDistance,
                    effortDuration: effort.duration,
                    effortDate: effort.start,
                    exponent: exponent
                )
                if best.map({ prediction.distance > $0.distance }) ?? true {
                    best = prediction
                }
            } else {
                let raceDistance = config.distance.leg(for: discipline)
                guard raceDistance > 0 else { return nil }
                let exponent = self.exponent(limits, discipline: discipline, raceDistance: raceDistance, effortDistance: effortDistance, longest: longest, volumeRatio: volumeRatio)
                prediction = RacePrediction(
                    discipline: discipline,
                    time: effort.duration * pow(raceDistance / effortDistance, exponent),
                    distance: raceDistance,
                    effortDistance: effortDistance,
                    effortDuration: effort.duration,
                    effortDate: effort.start,
                    exponent: exponent
                )
                if best.map({ prediction.time < $0.time }) ?? true {
                    best = prediction
                }
            }
        }
        return best
    }

    static func exponent(
        _ limits: Limits,
        discipline: Discipline,
        raceDistance: Double,
        effortDistance: Double,
        longest: Double,
        volumeRatio: Double
    ) -> Double {
        var exponent = limits.exponent
        if raceDistance > effortDistance {
            let reference = min(raceDistance, limits.longestReference)
            let reach = min(1, max(0, longest / reference))
            exponent += longRunPenalty * (1 - reach)
            exponent += volumePenalty * (1 - min(1, max(0, volumeRatio)))
        }
        if discipline == .run, raceDistance > marathon {
            exponent += min(0.08, 0.04 * log2(raceDistance / marathon))
        }
        return min(maxExponent, exponent)
    }
}
