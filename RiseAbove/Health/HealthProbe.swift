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

    var thresholdEstimate: Double? {
        TrainingLoad.estimateThresholdHeartRate(workouts.map(\.activity), discipline: .run)
    }

    var settings: AthleteSettings {
        AthleteSettings(thresholdHeartRate: thresholdEstimate ?? AthleteSettings.fallbackThresholdHeartRate)
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func stress(for workout: WorkoutProbe) -> Double {
        TrainingLoad.heartRateStress(workout.activity, settings: settings)
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
            let reader = HealthWorkoutReader(store: store)
            var probes: [WorkoutProbe] = []
            for workout in try await descriptor.result(for: store) {
                probes.append(await reader.read(workout))
            }
            workouts = probes
            status = .loaded
        } catch {
            status = .failed(error.localizedDescription)
        }
    }
}
