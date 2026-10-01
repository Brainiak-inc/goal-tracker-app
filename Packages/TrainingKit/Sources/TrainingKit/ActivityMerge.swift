import Foundation

extension Activity {
    public var identity: String {
        "\(start.timeIntervalSince1970)|\(sourceType)"
    }
}

public struct MergeResult: Sendable {
    public let activities: [Activity]
    public let added: Int
    public let updated: Int
}

public enum ActivityMerge {
    public static func merge(
        _ existing: [Activity],
        with incoming: [Activity],
        excluding deleted: Set<String> = []
    ) -> MergeResult {
        var byIdentity: [String: Activity] = [:]
        for activity in existing {
            byIdentity[activity.identity] = activity
        }
        var added = 0
        var updated = 0
        for var activity in incoming where !deleted.contains(activity.identity) {
            if let current = byIdentity[activity.identity] {
                activity.discipline = current.discipline
                updated += 1
            } else {
                added += 1
            }
            byIdentity[activity.identity] = activity
        }
        let sorted = byIdentity.values.sorted { $0.start < $1.start }
        return MergeResult(activities: sorted, added: added, updated: updated)
    }
}
