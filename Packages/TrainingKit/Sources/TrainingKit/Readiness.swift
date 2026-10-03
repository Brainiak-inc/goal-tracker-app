import Foundation

public struct RaceNorm: Codable, Hashable, Sendable {
    public var discipline: Discipline
    public var weekly: Double
    public var longest: Double

    public init(discipline: Discipline, weekly: Double, longest: Double) {
        self.discipline = discipline
        self.weekly = weekly
        self.longest = longest
    }

    var isValid: Bool {
        weekly > 0 && longest > 0
    }
}

public struct RaceConfig: Codable, Hashable, Sendable {
    public var distance: RaceDistance
    public var raceDay: Date?
    public var targetTime: TimeInterval
    public var weeklyHours: Double?
    public var fromZero: Bool
    public var manualNorms: [RaceNorm]?
    public var timeLimit: TimeInterval?

    public init(
        distance: RaceDistance,
        raceDay: Date? = nil,
        targetTime: TimeInterval? = nil,
        weeklyHours: Double? = nil,
        fromZero: Bool = false,
        manualNorms: [RaceNorm]? = nil,
        timeLimit: TimeInterval? = nil
    ) {
        self.distance = distance
        self.raceDay = raceDay
        self.targetTime = timeLimit ?? targetTime ?? distance.cutoff
        self.weeklyHours = weeklyHours
        self.fromZero = fromZero
        self.manualNorms = manualNorms
        self.timeLimit = timeLimit
    }

    public var isTimed: Bool {
        timeLimit != nil
    }

    public var hasGoalDistance: Bool {
        !isTimed || distance.total > 0
    }

    public var planningDistance: RaceDistance {
        guard let timeLimit, distance.total <= 0, let discipline = distance.disciplines.first else { return distance }
        let speed = RaceNorms.timedReferenceSpeed[discipline] ?? 2
        return RaceDistance(sport: distance.sport, legs: [discipline: timeLimit * speed])
    }

    public var hasManualNorms: Bool {
        !(manualNorms ?? []).isEmpty
    }
}

public enum ReadinessModel: Sendable {
    case legacy
    case adaptive
}

public struct ReadinessComponent: Hashable, Sendable {
    public enum Kind: Sendable {
        case volume
        case longest
        case load
        case consistency
    }

    public let kind: Kind
    public let ratio: Double
    public let weight: Double
}

public struct DisciplineReadiness: Hashable, Sendable {
    public let discipline: Discipline
    public let percent: Int
    public let weeklyDistance: Double
    public let targetWeeklyDistance: Double
    public let longestDistance: Double
    public let targetLongestDistance: Double
    public var activeWeeks: Int?
    public var fitness: Double?
    public var targetFitness: Double?
    public var components: [ReadinessComponent] = []
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
    public let prediction: RacePrediction?
}

public enum ReadinessCalculator {
    static let fitnessBonus = 4
    static let week: TimeInterval = 7 * 24 * 3600
    static let weeksPerMonth = 4.345

    public static func compute(
        config: RaceConfig,
        activities: [Activity],
        fitness snapshot: FitnessSnapshot? = nil,
        settings: AthleteSettings? = nil,
        model: ReadinessModel = .adaptive,
        now: Date,
        calendar: Calendar
    ) -> Readiness {
        let ramp = config.fromZero ? 0.045 : 0.07
        let daysToRace = config.raceDay.map { calendar.startOfDay(for: $0).timeIntervalSince(now) / 86_400 }

        let disciplines = norms(for: config).map { norm in
            switch model {
            case .legacy:
                legacyReadiness(norm, activities: activities, now: now)
            case .adaptive:
                AdaptiveReadiness.evaluate(norm, activities: activities, settings: settings, daysToRace: daysToRace, now: now, calendar: calendar)
            }
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

        let distance = config.planningDistance
        let movingTime = max(1, config.targetTime - distance.transitionTime)
        let pace = distance.disciplines.map { discipline in
            let required = distance.leg(for: discipline) / (movingTime * distance.share(for: discipline))
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
            pace: pace,
            prediction: RacePredictor.predict(
                config: config,
                activities: activities,
                longest: disciplines.first?.longestDistance ?? 0,
                volumeRatio: disciplines.first.map { $0.targetWeeklyDistance > 0 ? $0.weeklyDistance / $0.targetWeeklyDistance : 0 } ?? 0,
                now: now
            )
        )
    }

    static func legacyReadiness(_ norm: RaceNorm, activities: [Activity], now: Date) -> DisciplineReadiness {
        let weekly = weeklyAverage(activities, norm.discipline, now: now, weeks: 4)
        let longest = longestSession(activities, norm.discipline, now: now, weeks: 12)
        let volumeRatio = min(1, weekly / norm.weekly)
        let longestRatio = min(1, longest / norm.longest)
        var readiness = DisciplineReadiness(
            discipline: norm.discipline,
            percent: Int(jsRound((0.6 * volumeRatio + 0.4 * longestRatio) * 100)),
            weeklyDistance: weekly,
            targetWeeklyDistance: norm.weekly,
            longestDistance: longest,
            targetLongestDistance: norm.longest
        )
        readiness.components = [
            ReadinessComponent(kind: .volume, ratio: volumeRatio, weight: 0.6),
            ReadinessComponent(kind: .longest, ratio: longestRatio, weight: 0.4)
        ]
        return readiness
    }

    public static func automaticNorms(for config: RaceConfig) -> [RaceNorm] {
        let goalFactor = paceFactor(config)
        let distance = config.planningDistance
        return distance.disciplines.map { discipline in
            let base = distance.target(for: discipline)
            let scaledLongest = base.longest * goalFactor
            return RaceNorm(
                discipline: discipline,
                weekly: base.weekly * goalFactor,
                longest: distance.longestCap(for: discipline).map { min(scaledLongest, $0) } ?? scaledLongest
            )
        }
    }

    public static func norms(for config: RaceConfig) -> [RaceNorm] {
        let manual = config.manualNorms ?? []
        return automaticNorms(for: config).map { automatic in
            manual.first { $0.discipline == automatic.discipline && $0.isValid } ?? automatic
        }
    }

    static func paceFactor(_ config: RaceConfig) -> Double {
        guard config.targetTime > 0 else { return 1 }
        return min(2, max(1, config.planningDistance.cutoff / config.targetTime))
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
