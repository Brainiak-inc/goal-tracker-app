import Foundation

public enum WeeklyVolume {
    public static func weekStarts(
        weeks: Int,
        now: Date,
        calendar: Calendar,
        includingCurrent: Bool = false
    ) -> [Date] {
        let last = lastWeek(now: now, calendar: calendar, includingCurrent: includingCurrent)
        return (0..<weeks).map { calendar.adding(days: -7 * (weeks - 1 - $0), to: last) }
    }

    public static func series(
        _ activities: [Activity],
        discipline: Discipline,
        weeks: Int,
        now: Date,
        calendar: Calendar,
        includingCurrent: Bool = false
    ) -> [Double] {
        let last = lastWeek(now: now, calendar: calendar, includingCurrent: includingCurrent)
        let first = calendar.adding(days: -7 * (weeks - 1), to: last)
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

    private static func lastWeek(now: Date, calendar: Calendar, includingCurrent: Bool) -> Date {
        let monday = calendar.monday(of: now)
        return includingCurrent ? monday : calendar.adding(days: -7, to: monday)
    }
}
