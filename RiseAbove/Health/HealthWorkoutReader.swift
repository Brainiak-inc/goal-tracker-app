import Foundation
import HealthKit
import TrainingKit

struct HealthWorkoutReader {
    static let heartRate = HKQuantityType(.heartRate)
    static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
    static let distanceTypes = [
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming)
    ]
    static let powerTypes = [
        HKQuantityType(.runningPower),
        HKQuantityType(.cyclingPower)
    ]
    static let energy = HKQuantityType(.activeEnergyBurned)

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [.workoutType(), heartRate, energy]
        types.formUnion(distanceTypes)
        types.formUnion(powerTypes)
        return types
    }

    let store: HKHealthStore

    func read(_ workout: HKWorkout) async -> WorkoutProbe {
        let interval = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        let heartRateSamples = (try? await samples(Self.heartRate, matching: interval)) ?? []
        let heartRateStatistics = try? await HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.heartRate, predicate: interval),
            options: [.discreteAverage, .discreteMax]
        ).result(for: store)

        var sampleDistance: Double?
        if let type = distanceType(for: workout.workoutActivityType) {
            let sameSource = NSCompoundPredicate(andPredicateWithSubpredicates: [
                interval,
                HKQuery.predicateForObjects(from: workout.sourceRevision.source)
            ])
            if let distances = try? await samples(type, matching: sameSource), !distances.isEmpty {
                sampleDistance = distances.reduce(0) { $0 + $1.quantity.doubleValue(for: .meter()) }
            }
        }

        let workoutHeartRate = workout.statistics(for: Self.heartRate)
        return WorkoutProbe(
            id: workout.uuid,
            start: workout.startDate,
            duration: workout.duration,
            discipline: Discipline(workoutType: workout.workoutActivityType),
            activityType: workout.workoutActivityType.identifier,
            sourceName: workout.sourceRevision.source.name,
            workoutDistance: Self.distanceTypes.lazy
                .compactMap { workout.statistics(for: $0)?.sumQuantity()?.doubleValue(for: .meter()) }
                .first,
            sampleDistance: sampleDistance,
            workoutHeartRate: workoutHeartRate?.averageQuantity()?.doubleValue(for: Self.beatsPerMinute),
            sampleHeartRate: heartRateStatistics?.averageQuantity()?.doubleValue(for: Self.beatsPerMinute),
            maxHeartRate: workoutHeartRate?.maximumQuantity()?.doubleValue(for: Self.beatsPerMinute)
                ?? heartRateStatistics?.maximumQuantity()?.doubleValue(for: Self.beatsPerMinute),
            heartRateSampleCount: heartRateSamples.count,
            heartRateSources: Set(heartRateSamples.map(\.sourceRevision.source.name)).sorted(),
            averagePower: Self.powerTypes.lazy
                .compactMap { workout.statistics(for: $0)?.averageQuantity()?.doubleValue(for: .watt()) }
                .first,
            calories: workout.statistics(for: Self.energy)?.sumQuantity()?.doubleValue(for: .kilocalorie())
        )
    }

    private func samples(_ type: HKQuantityType, matching predicate: NSPredicate) async throws -> [HKQuantitySample] {
        try await HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\.startDate)]
        ).result(for: store)
    }

    private func distanceType(for type: HKWorkoutActivityType) -> HKQuantityType? {
        switch type {
        case .running, .walking, .hiking: HKQuantityType(.distanceWalkingRunning)
        case .cycling, .handCycling: HKQuantityType(.distanceCycling)
        case .swimming: HKQuantityType(.distanceSwimming)
        default: nil
        }
    }
}
