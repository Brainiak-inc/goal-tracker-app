import Foundation

enum AdaptiveReadiness {
    static let weeks = 6
    static let decay = 0.75
    static let taperDays = 21.0
    static let longestWindowWeeks = 12.0
    static let longestFullWeeks = 6.0
    static let longestOldestWeight = 0.75
    static let climbEquivalent = 10.0
    static let tssPerHour = 60.0
    static let defaultSpeed: [Discipline: Double] = [.swim: 0.75, .bike: 6.9, .run: 2.6]

    static func evaluate(
        _ norm: RaceNorm,
        activities all: [Activity],
        settings: AthleteSettings?,
        daysToRace: Double?,
        now: Date,
        calendar: Calendar
    ) -> DisciplineReadiness {
        let activities = all.filter { $0.discipline == norm.discipline }
        let volumes = weeklyVolumes(activities, now: now, count: weeks + 2)
        var weekly = weighted(volumes[0..<weeks])
        if let daysToRace, daysToRace >= 0, daysToRace <= taperDays {
            weekly = max(weekly, weighted(volumes[2..<(weeks + 2)]))
        }
        let longest = longestSession(activities, now: now)
        let activeWeeks = volumes[0..<weeks].filter { $0 > 0 }.count

        let volumeRatio = min(1, weekly / norm.weekly)
        let longestRatio = min(1, longest / norm.longest)
        let consistency = Double(activeWeeks) / Double(weeks)

        var fitness: Double?
        var targetFitness: Double?
        let score: Double
        if let settings, let load = load(norm, activities: activities, settings: settings, now: now, calendar: calendar) {
            fitness = load.fitness
            targetFitness = load.target
            let loadRatio = min(1, load.fitness / load.target)
            score = 0.4 * volumeRatio + 0.3 * longestRatio + 0.2 * loadRatio + 0.1 * consistency
        } else {
            score = 0.5 * volumeRatio + 0.35 * longestRatio + 0.15 * consistency
        }

        var readiness = DisciplineReadiness(
            discipline: norm.discipline,
            percent: Int(jsRound(score * 100)),
            weeklyDistance: weekly,
            targetWeeklyDistance: norm.weekly,
            longestDistance: longest,
            targetLongestDistance: norm.longest
        )
        readiness.activeWeeks = activeWeeks
        readiness.fitness = fitness
        readiness.targetFitness = targetFitness
        return readiness
    }

    static func effectiveDistance(_ activity: Activity) -> Double {
        guard let distance = activity.distance else { return 0 }
        if activity.discipline == .run, let gain = activity.elevationGain, gain > 0 {
            return distance + gain * climbEquivalent
        }
        return distance
    }

    static func weeklyVolumes(_ activities: [Activity], now: Date, count: Int) -> [Double] {
        var volumes = Array(repeating: 0.0, count: count)
        for activity in activities {
            let age = now.timeIntervalSince(activity.start)
            guard age >= 0 else { continue }
            let index = Int(age / ReadinessCalculator.week)
            guard index < count else { continue }
            volumes[index] += effectiveDistance(activity)
        }
        return volumes
    }

    static func weighted(_ volumes: ArraySlice<Double>) -> Double {
        var total = 0.0
        var weights = 0.0
        var weight = 1.0
        for volume in volumes {
            total += volume * weight
            weights += weight
            weight *= decay
        }
        return weights > 0 ? total / weights : 0
    }

    static func longestSession(_ activities: [Activity], now: Date) -> Double {
        activities.reduce(0) { best, activity in
            let age = now.timeIntervalSince(activity.start) / ReadinessCalculator.week
            guard age >= 0, age < longestWindowWeeks else { return best }
            let fade = age <= longestFullWeeks
                ? 1
                : 1 - (1 - longestOldestWeight) * (age - longestFullWeeks) / (longestWindowWeeks - longestFullWeeks)
            return max(best, effectiveDistance(activity) * fade)
        }
    }

    static func load(
        _ norm: RaceNorm,
        activities: [Activity],
        settings: AthleteSettings,
        now: Date,
        calendar: Calendar
    ) -> (fitness: Double, target: Double)? {
        let window = now.addingTimeInterval(-longestWindowWeeks * ReadinessCalculator.week)
        let recent = activities.filter { $0.start >= window && $0.start <= now }
        guard recent.contains(where: { ($0.averageHeartRate ?? 0) > 0 }) else { return nil }

        var distance = 0.0
        var time = 0.0
        for activity in recent {
            guard let meters = activity.distance, meters > 0, activity.duration > 0 else { continue }
            distance += meters
            time += activity.duration
        }
        let speed = time > 0 ? distance / time : defaultSpeed[norm.discipline] ?? 1
        let weeklyHours = norm.weekly / max(speed, 0.1) / 3600
        let target = weeklyHours * tssPerHour / 7
        guard target > 0 else { return nil }

        let past = activities.filter { $0.start <= now }
        let fitness = TrainingLoad.series(past, settings: settings, calendar: calendar, until: now).last?.fitness ?? 0
        return (fitness, target)
    }
}
