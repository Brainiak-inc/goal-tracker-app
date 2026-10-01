import Foundation
import HealthKit
import Observation
import TrainingKit

@Observable
final class HealthProbe {
    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case unavailable
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var workouts: [WorkoutProbe] = []

    @ObservationIgnored let store = HKHealthStore()

    private static let heartRate = HKQuantityType(.heartRate)
    private static let beatsPerMinute = HKUnit.count().unitDivided(by: .minute())
    private static let distanceTypes = [
        HKQuantityType(.distanceWalkingRunning),
        HKQuantityType(.distanceCycling),
        HKQuantityType(.distanceSwimming)
    ]
    private static let powerTypes = [
        HKQuantityType(.runningPower),
        HKQuantityType(.cyclingPower)
    ]

    static var readTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = [.workoutType(), heartRate, HKQuantityType(.activeEnergyBurned)]
        types.formUnion(distanceTypes)
        types.formUnion(powerTypes)
        return types
    }

    var thresholdEstimate: Double? {
        TrainingLoad.estimateThresholdHeartRate(workouts.map(\.activity), discipline: .run)
    }

    var settings: AthleteSettings {
        AthleteSettings(thresholdHeartRate: thresholdEstimate ?? AthleteSettings.fallbackThresholdHeartRate)
    }

    func stress(for workout: WorkoutProbe) -> Double {
        TrainingLoad.heartRateStress(workout.activity, settings: settings)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func markUnavailable() {
        status = .unavailable
    }

    func handleAccess(_ result: Result<Bool, any Error>) async {
        switch result {
        case .success:
            await load()
        case .failure(let error):
            status = .failed(error.localizedDescription)
        }
    }

    func load(limit: Int = 30) async {
        status = .loading
        do {
            let descriptor = HKSampleQueryDescriptor(
                predicates: [.workout()],
                sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
                limit: limit
            )
            var probes: [WorkoutProbe] = []
            for workout in try await descriptor.result(for: store) {
                probes.append(try await probe(workout))
            }
            workouts = probes
            status = .loaded
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func probe(_ workout: HKWorkout) async throws -> WorkoutProbe {
        let interval = HKQuery.predicateForSamples(
            withStart: workout.startDate,
            end: workout.endDate,
            options: .strictStartDate
        )
        let heartRateSamples = try await samples(Self.heartRate, matching: interval)
        let heartRateAverage = try await HKStatisticsQueryDescriptor(
            predicate: .quantitySample(type: Self.heartRate, predicate: interval),
            options: .discreteAverage
        ).result(for: store)?.averageQuantity()?.doubleValue(for: Self.beatsPerMinute)

        var sampleDistance: Double?
        if let type = distanceType(for: workout.workoutActivityType) {
            let sameSource = NSCompoundPredicate(andPredicateWithSubpredicates: [
                interval,
                HKQuery.predicateForObjects(from: workout.sourceRevision.source)
            ])
            let distances = try await samples(type, matching: sameSource)
            if !distances.isEmpty {
                sampleDistance = distances.reduce(0) { $0 + $1.quantity.doubleValue(for: .meter()) }
            }
        }

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
            workoutHeartRate: workout.statistics(for: Self.heartRate)?
                .averageQuantity()?
                .doubleValue(for: Self.beatsPerMinute),
            sampleHeartRate: heartRateAverage,
            heartRateSampleCount: heartRateSamples.count,
            heartRateSources: Set(heartRateSamples.map(\.sourceRevision.source.name)).sorted(),
            averagePower: Self.powerTypes.lazy
                .compactMap { workout.statistics(for: $0)?.averageQuantity()?.doubleValue(for: .watt()) }
                .first
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
