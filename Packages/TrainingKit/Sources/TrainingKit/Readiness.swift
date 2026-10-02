import Foundation

public enum RaceDistance: String, Codable, CaseIterable, Sendable {
    case full
    case half

    public var cutoff: TimeInterval {
        switch self {
        case .full: 17 * 3600
        case .half: 8.5 * 3600
        }
    }

    var transitionTime: TimeInterval {
        switch self {
        case .full: 12 * 60
        case .half: 8 * 60
        }
    }

    func target(for discipline: Discipline) -> (weekly: Double, longest: Double) {
        switch (self, discipline) {
        case (.full, .swim): (6_000, 3_000)
        case (.full, .bike): (180_000, 120_000)
        case (.full, _): (40_000, 28_000)
        case (.half, .swim): (3_000, 1_900)
        case (.half, .bike): (110_000, 80_000)
        case (.half, _): (25_000, 16_000)
        }
    }

    public func leg(for discipline: Discipline) -> Double {
        switch (self, discipline) {
        case (.full, .swim): 3_800
        case (.full, .bike): 180_000
        case (.full, _): 42_200
        case (.half, .swim): 1_900
        case (.half, .bike): 90_000
        case (.half, _): 21_100
        }
    }
}

public struct RaceConfig: Codable, Hashable, Sendable {
    public var distance: RaceDistance
    public var raceDay: Date?
    public var targetTime: TimeInterval
    public var weeklyHours: Double?
    public var fromZero: Bool

    public init(
        distance: RaceDistance,
        raceDay: Date? = nil,
        targetTime: TimeInterval? = nil,
        weeklyHours: Double? = nil,
        fromZero: Bool = false
    ) {
        self.distance = distance
        self.raceDay = raceDay
        self.targetTime = targetTime ?? distance.cutoff
        self.weeklyHours = weeklyHours
        self.fromZero = fromZero
    }
}

public struct DisciplineReadiness: Hashable, Sendable {
    public let discipline: Discipline
    public let percent: Int
    public let weeklyDistance: Double
    public let targetWeeklyDistance: Double
    public let longestDistance: Double
    public let targetLongestDistance: Double
}

public enum RaceStatus: String, Sendable {
    case ahead
    case onTrack
    case behind
}

public struct WeeklyStep: Hashable, Sendable {
    public let discipline: Discipline
    public let currentDistance: Double
    public let suggestedDistance: Double
    public let isDone: Bool
}

public struct PaceCheck: Hashable, Sendable {
    public let discipline: Discipline
    public let currentSpeed: Double?
    public let requiredSpeed: Double
    public let isOnPace: Bool

    public var hasData: Bool { currentSpeed != nil }
}

public struct Readiness: Hashable, Sendable {
    public let overall: Int
    public let volumeScore: Int
    public let disciplines: [DisciplineReadiness]
    public let limiting: Discipline
    public let monthsToReady: Int
    public let weeksToRace: Int?
    public let status: RaceStatus?
    public let hasVolume: Bool
    public let fitness: Int?
    public let form: Int?
    public let fitnessTrend: Double?
    public let fitnessBonus: Int
    public let nextWeek: [WeeklyStep]
    public let pace: [PaceCheck]
}

public enum ReadinessCalculator {
    static let fitnessBonus = 4
    static let legShare: [Discipline: Double] = [.swim: 0.14, .bike: 0.47, .run: 0.39]
    static let week: TimeInterval = 7 * 24 * 3600
    static let weeksPerMonth = 4.345

    public static func compute(
        config: RaceConfig,
        activities: [Activity],
        fitness snapshot: FitnessSnapshot? = nil,
        now: Date,
        calendar: Calendar
    ) -> Readiness {
        let goalFactor = paceFactor(config)
        let ramp = config.fromZero ? 0.045 : 0.07

        let disciplines = Discipline.triathlon.map { discipline in
            let base = config.distance.target(for: discipline)
            let targetWeekly = base.weekly * goalFactor
            let targetLongest = base.longest * goalFactor
            let weekly = weeklyAverage(activities, discipline, now: now, weeks: 4)
            let longest = longestSession(activities, discipline, now: now, weeks: 12)
            let volumeRatio = min(1, weekly / targetWeekly)
            let longestRatio = min(1, longest / targetLongest)
            return DisciplineReadiness(
                discipline: discipline,
                percent: Int(jsRound((0.6 * volumeRatio + 0.4 * longestRatio) * 100)),
                weeklyDistance: weekly,
                targetWeeklyDistance: targetWeekly,
                longestDistance: longest,
                targetLongestDistance: targetLongest
            )
        }

        let percents = disciplines.map { Double($0.percent) }
        let lowest = percents.min() ?? 0
        let mean = percents.reduce(0, +) / Double(percents.count)
        let volumeScore = Int(jsRound(0.5 * lowest + 0.5 * mean))
        let limiting = disciplines.dropFirst().reduce(disciplines[0]) { $1.percent < $0.percent ? $1 : $0 }.discipline

        var bonus = 0
        if let snapshot {
            if snapshot.fitnessTrend > 0.5 {
                bonus = fitnessBonus
            } else if snapshot.fitnessTrend < -0.5 {
                bonus = -fitnessBonus
            }
        }
        let overall = max(0, min(100, volumeScore + bonus))
        let months = monthsToReady(disciplines, ramp: ramp, fromZero: config.fromZero)

        var weeksToRace: Int?
        var status: RaceStatus?
        if let raceDay = config.raceDay {
            let rawWeeks = calendar.startOfDay(for: raceDay).timeIntervalSince(now) / week
            weeksToRace = max(0, Int(jsRound(rawWeeks)))
            let weeksToReady = Double(months) * weeksPerMonth
            if weeksToReady <= rawWeeks * 0.85 {
                status = .ahead
            } else if weeksToReady <= rawWeeks {
                status = .onTrack
            } else {
                status = .behind
            }
        }

        let movingTime = max(1, config.targetTime - config.distance.transitionTime)
        let pace = Discipline.triathlon.map { discipline in
            let required = config.distance.leg(for: discipline) / (movingTime * (legShare[discipline] ?? 0))
            let current = averageSpeed(activities, discipline, now: now, weeks: 12)
            return PaceCheck(
                discipline: discipline,
                currentSpeed: current,
                requiredSpeed: required,
                isOnPace: current.map { $0 >= required * 0.98 } ?? false
            )
        }

        let nextWeek = disciplines.map { item in
            let done = item.weeklyDistance >= item.targetWeeklyDistance
            let suggested = done
                ? item.targetWeeklyDistance
                : min(item.targetWeeklyDistance, max(item.weeklyDistance * (1 + ramp), item.targetWeeklyDistance * 0.1))
            return WeeklyStep(
                discipline: item.discipline,
                currentDistance: item.weeklyDistance,
                suggestedDistance: suggested,
                isDone: done
            )
        }

        return Readiness(
            overall: overall,
            volumeScore: volumeScore,
            disciplines: disciplines,
            limiting: limiting,
            monthsToReady: months,
            weeksToRace: weeksToRace,
            status: status,
            hasVolume: disciplines.contains { $0.weeklyDistance > 0 || $0.longestDistance > 0 },
            fitness: snapshot.map { Int(jsRound($0.fitness)) },
            form: snapshot.map { Int(jsRound($0.form)) },
            fitnessTrend: snapshot?.fitnessTrend,
            fitnessBonus: bonus,
            nextWeek: nextWeek,
            pace: pace
        )
    }

    static func paceFactor(_ config: RaceConfig) -> Double {
        guard config.targetTime > 0 else { return 1 }
        return min(2, max(1, config.distance.cutoff / config.targetTime))
    }

    static func monthsToReady(_ disciplines: [DisciplineReadiness], ramp: Double, fromZero: Bool) -> Int {
        var longestRamp = 0.0
        for item in disciplines where item.weeklyDistance < item.targetWeeklyDistance {
            let base = max(item.weeklyDistance, item.targetWeeklyDistance * 0.08)
            let weeks = log(item.targetWeeklyDistance / base) / log(1 + ramp)
            longestRamp = max(longestRamp, weeks)
        }
        guard longestRamp > 0 else { return 0 }
        let buffer: Double = fromZero ? 12 : 4
        return Int(jsRound((longestRamp + buffer) / weeksPerMonth))
    }

    static func recent(_ activities: [Activity], _ discipline: Discipline, now: Date, weeks: Int) -> [Activity] {
        let cutoff = now.addingTimeInterval(-Double(weeks) * week)
        return activities.filter { $0.discipline == discipline && $0.start >= cutoff }
    }

    static func weeklyAverage(_ activities: [Activity], _ discipline: Discipline, now: Date, weeks: Int) -> Double {
        recent(activities, discipline, now: now, weeks: weeks).reduce(0) { $0 + ($1.distance ?? 0) } / Double(weeks)
    }

    static func longestSession(_ activities: [Activity], _ discipline: Discipline, now: Date, weeks: Int) -> Double {
        recent(activities, discipline, now: now, weeks: weeks).reduce(0) { max($0, $1.distance ?? 0) }
    }

    static func averageSpeed(_ activities: [Activity], _ discipline: Discipline, now: Date, weeks: Int) -> Double? {
        var distance = 0.0
        var time = 0.0
        for activity in recent(activities, discipline, now: now, weeks: weeks) {
            guard let meters = activity.distance, meters > 0, activity.duration > 0 else { continue }
            distance += meters
            time += activity.duration
        }
        return time > 0 ? distance / time : nil
    }
}
