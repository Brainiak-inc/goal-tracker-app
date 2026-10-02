import Foundation

public enum WeeklyVolume {
    public static func weekStarts(weeks: Int, now: Date, calendar: Calendar) -> [Date] {
        let lastComplete = calendar.adding(days: -7, to: calendar.monday(of: now))
        return (0..<weeks).map { calendar.adding(days: -7 * (weeks - 1 - $0), to: lastComplete) }
    }

    public static func series(
        _ activities: [Activity],
        discipline: Discipline,
        weeks: Int,
        now: Date,
        calendar: Calendar
    ) -> [Double] {
        let lastComplete = calendar.adding(days: -7, to: calendar.monday(of: now))
        let first = calendar.adding(days: -7 * (weeks - 1), to: lastComplete)
        var buckets = Array(repeating: 0.0, count: weeks)
        for activity in activities where activity.discipline == discipline {
            guard let distance = activity.distance else { continue }
            let monday = calendar.monday(of: activity.start)
            let days = calendar.dateComponents([.day], from: first, to: monday).day ?? 0
            let index = Int(jsRound(Double(days) / 7))
            guard buckets.indices.contains(index) else { continue }
            buckets[index] += distance
        }
        return buckets
    }
}
