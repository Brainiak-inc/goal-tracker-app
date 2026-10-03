import Foundation
import TrainingKit

struct WorkoutProbe: Identifiable, Hashable, Sendable {
    enum HeartRateOrigin: Sendable {
        case workout
        case samples
        case missing
    }

    enum DistanceOrigin: Sendable {
        case workout
        case samples
        case missing
    }

    let id: UUID
    let start: Date
    let duration: TimeInterval
    let discipline: Discipline
    let activityType: String
    let sourceName: String
    let workoutDistance: Double?
    let sampleDistance: Double?
    let workoutHeartRate: Double?
    let sampleHeartRate: Double?
    let maxHeartRate: Double?
    let heartRateSampleCount: Int
    let heartRateSources: [String]
    let averagePower: Double?
    let calories: Double?
    var elevationGain: Double?

    var distance: Double? {
        workoutDistance ?? sampleDistance
    }

    var distanceOrigin: DistanceOrigin {
        if workoutDistance != nil { return .workout }
        if sampleDistance != nil { return .samples }
        return .missing
    }

    var averageHeartRate: Double? {
        workoutHeartRate ?? sampleHeartRate
    }

    var heartRateOrigin: HeartRateOrigin {
        if workoutHeartRate != nil { return .workout }
        if sampleHeartRate != nil { return .samples }
        return .missing
    }

    var activity: Activity {
        Activity(
            start: start,
            discipline: discipline,
            sourceType: activityType,
            title: "",
            duration: duration,
            distance: distance,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            calories: calories,
            externalID: Self.externalID(id),
            elevationGain: elevationGain
        )
    }

    static func externalID(_ id: UUID) -> String {
        "health:\(id.uuidString)"
    }
}
