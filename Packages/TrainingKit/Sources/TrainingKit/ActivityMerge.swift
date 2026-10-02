import Foundation

extension Activity {
    public var identity: String {
        if let externalID {
            return externalID
        }
        return "\(start.timeIntervalSince1970)|\(sourceType)"
    }

    public func isSameSession(as other: Activity) -> Bool {
        guard discipline == other.discipline,
              abs(start.timeIntervalSince(other.start)) <= ActivityMerge.startTolerance,
              duration > 0, other.duration > 0 else { return false }
        let ratio = duration / other.duration
        return ratio >= 1 - ActivityMerge.durationTolerance && ratio <= 1 + ActivityMerge.durationTolerance
    }

    mutating func fillGaps(from other: Activity) {
        distance = distance ?? other.distance
        averageHeartRate = averageHeartRate ?? other.averageHeartRate
        maxHeartRate = maxHeartRate ?? other.maxHeartRate
        calories = calories ?? other.calories
        if title.isEmpty {
            title = other.title
        }
    }
}

public struct MergeResult: Sendable {
    public let activities: [Activity]
    public let added: Int
    public let updated: Int
}

public enum ActivityMerge {
    static let startTolerance: TimeInterval = 120
    static let durationTolerance = 0.15

    public static func merge(
        _ existing: [Activity],
        with incoming: [Activity],
        excluding deleted: Set<String> = []
    ) -> MergeResult {
        var result = existing
        var indexByIdentity: [String: Int] = [:]
        for (index, activity) in result.enumerated() {
            indexByIdentity[activity.identity] = index
        }
        var added = 0
        var updated = 0
        for var activity in incoming where !deleted.contains(activity.identity) {
            if let index = indexByIdentity[activity.identity] {
                activity.discipline = result[index].discipline
                result[index] = activity
                updated += 1
            } else if let index = result.firstIndex(where: { $0.isSameSession(as: activity) }) {
                result[index].fillGaps(from: activity)
                updated += 1
            } else {
                indexByIdentity[activity.identity] = result.count
                result.append(activity)
                added += 1
            }
        }
        result.sort { $0.start < $1.start }
        return MergeResult(activities: result, added: added, updated: updated)
    }

    public static func removing(externalIDs: Set<String>, from activities: [Activity]) -> [Activity] {
        guard !externalIDs.isEmpty else { return activities }
        return activities.filter { activity in
            activity.externalID.map { !externalIDs.contains($0) } ?? true
        }
    }
}

extension Activity: Identifiable {
    public var id: String { identity }
}
