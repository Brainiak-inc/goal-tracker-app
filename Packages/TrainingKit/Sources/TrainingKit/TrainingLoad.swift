import Foundation

public struct LoadPoint: Hashable, Sendable {
    public let day: Date
    public let stress: Double
    public let fitness: Double
    public let fatigue: Double
    public let form: Double
}

public enum TrainingLoad {
    public static let fitnessDays: Double = 42
    public static let fatigueDays: Double = 7
    static let minimumThresholdEstimateDuration: TimeInterval = 20 * 60

    public static func heartRateStress(_ activity: Activity, settings: AthleteSettings) -> Double {
        guard let heartRate = activity.averageHeartRate, heartRate > 0 else { return 0 }
        let intensity = heartRate / settings.thresholdHeartRate(for: activity.discipline)
        let hours = activity.duration / 3600
        return hours * intensity * intensity * 100
    }

    public static func dailyStress(
        _ activities: [Activity],
        settings: AthleteSettings,
        calendar: Calendar
    ) -> [Date: Double] {
        var byDay: [Date: Double] = [:]
        for activity in activities {
            let day = calendar.startOfDay(for: activity.start)
            byDay[day, default: 0] += heartRateStress(activity, settings: settings)
        }
        return byDay
    }

    public static func series(
        _ activities: [Activity],
        settings: AthleteSettings,
        calendar: Calendar,
        until: Date? = nil,
        where include: (Activity) -> Bool = { _ in true }
    ) -> [LoadPoint] {
        let relevant = activities.filter(include)
        guard let firstStart = relevant.map(\.start).min(),
              let lastStart = relevant.map(\.start).max() else { return [] }

        let byDay = dailyStress(relevant, settings: settings, calendar: calendar)
        let first = calendar.startOfDay(for: firstStart)
        let last = calendar.startOfDay(for: until ?? lastStart)

        let fitnessAlpha = 1 - exp(-1 / fitnessDays)
        let fatigueAlpha = 1 - exp(-1 / fatigueDays)

        var points: [LoadPoint] = []
        var fitness = 0.0
        var fatigue = 0.0
        var day = first
        while day <= last {
            let stress = byDay[day] ?? 0
            let form = fitness - fatigue
            fitness += (stress - fitness) * fitnessAlpha
            fatigue += (stress - fatigue) * fatigueAlpha
            points.append(LoadPoint(day: day, stress: stress, fitness: fitness, fatigue: fatigue, form: form))
            day = calendar.adding(days: 1, to: day)
        }
        return points
    }

    public static func estimateThresholdHeartRate(_ activities: [Activity], discipline: Discipline) -> Double? {
        activities
            .filter { $0.discipline == discipline && $0.duration >= minimumThresholdEstimateDuration }
            .compactMap(\.averageHeartRate)
            .max()
    }
}
