import Foundation

public struct WorkoutActual: Hashable, Sendable {
    public let activities: [Activity]

    public var distance: Double {
        activities.reduce(0) { $0 + ($1.distance ?? 0) }
    }

    public var duration: TimeInterval {
        activities.reduce(0) { $0 + $1.duration }
    }

    public func completion(of planned: Double?) -> Double? {
        guard let planned, planned > 0 else { return nil }
        return distance / planned
    }
}

extension TrainingPlan {
    public func actuals(forWeek index: Int, activities: [Activity], calendar: Calendar) -> [UUID: WorkoutActual] {
        guard weeks.indices.contains(index) else { return [:] }
        var result: [UUID: WorkoutActual] = [:]
        for (dayIndex, planned) in weeks[index].days.enumerated() where !planned.isEmpty {
            guard let day = day(dayIndex, ofWeek: index, calendar: calendar) else { return [:] }
            let sameDay = activities
                .filter { calendar.isDate($0.start, inSameDayAs: day) }
                .sorted { $0.start < $1.start }
            for discipline in Discipline.allCases {
                let slots = planned.filter { $0.discipline == discipline }
                let done = sameDay.filter { $0.discipline == discipline }
                guard !slots.isEmpty, !done.isEmpty else { continue }
                var buckets = Array(repeating: [Activity](), count: slots.count)
                for (position, activity) in done.enumerated() {
                    buckets[min(position, slots.count - 1)].append(activity)
                }
                for (slot, bucket) in zip(slots, buckets) where !bucket.isEmpty {
                    result[slot.id] = WorkoutActual(activities: bucket)
                }
            }
        }
        return result
    }
}
