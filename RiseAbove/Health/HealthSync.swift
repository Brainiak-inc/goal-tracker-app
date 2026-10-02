import Foundation
import HealthKit
import Observation
import TrainingKit

@Observable
final class HealthSync {
    enum Status: Equatable {
        case idle
        case syncing
        case failed(String)
    }

    private enum Keys {
        static let enabled = "healthSyncEnabled"
        static let lastSync = "healthLastSync"
        static let anchor = "healthAnchor"
    }

    private(set) var status: Status = .idle
    private(set) var isEnabled: Bool
    private(set) var lastSync: Date?
    private(set) var lastAdded = 0

    @ObservationIgnored let store = HKHealthStore()
    @ObservationIgnored private let library: ActivityLibrary
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observer: HKObserverQuery?

    init(library: ActivityLibrary, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Keys.enabled)
        lastSync = defaults.object(forKey: Keys.lastSync) as? Date
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func start() {
        guard isEnabled, isAvailable else { return }
        startObserving()
        Task { await sync() }
    }

    func enable() async {
        isEnabled = true
        defaults.set(true, forKey: Keys.enabled)
        startObserving()
        await sync()
    }

    func disable() {
        isEnabled = false
        defaults.set(false, forKey: Keys.enabled)
        if let observer {
            store.stop(observer)
        }
        observer = nil
        Task {
            try? await store.disableBackgroundDelivery(for: .workoutType())
        }
    }

    func sync() async {
        guard isEnabled, isAvailable, status != .syncing else { return }
        status = .syncing
        do {
            let descriptor = HKAnchoredObjectQueryDescriptor(
                predicates: [.workout()],
                anchor: storedAnchor()
            )
            let result = try await descriptor.result(for: store)
            let reader = HealthWorkoutReader(store: store)
            var incoming: [Activity] = []
            for workout in result.addedSamples {
                incoming.append(try await reader.read(workout).activity)
            }
            let deleted = Set(result.deletedObjects.map { WorkoutProbe.externalID($0.uuid) })
            lastAdded = library.applyHealthChanges(added: incoming, deletedIDs: deleted)
            save(result.newAnchor)
            lastSync = .now
            defaults.set(lastSync, forKey: Keys.lastSync)
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func startObserving() {
        guard observer == nil else { return }
        let query = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { @Sendable [weak self] _, completion, error in
            nonisolated(unsafe) let finish = completion
            guard error == nil else {
                finish()
                return
            }
            Task { @MainActor in
                await self?.sync()
                finish()
            }
        }
        observer = query
        store.execute(query)
        Task {
            try? await store.enableBackgroundDelivery(for: .workoutType(), frequency: .immediate)
        }
    }

    private func storedAnchor() -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: Keys.anchor) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    private func save(_ anchor: HKQueryAnchor) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            defaults.set(data, forKey: Keys.anchor)
        }
    }
}
