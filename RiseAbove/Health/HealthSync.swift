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

    struct Progress: Equatable {
        var done: Int
        let total: Int
    }

    private enum Keys {
        static let enabled = "healthSyncEnabled"
        static let lastSync = "healthLastSync"
        static let anchor = "healthAnchor"
    }

    private static let batchSize = 25
    private static let progressThreshold = 10
    private static let recentDays = 3

    private(set) var status: Status = .idle
    private(set) var progress: Progress?
    private(set) var isEnabled: Bool
    private(set) var lastSync: Date?

    @ObservationIgnored let store = HKHealthStore()
    @ObservationIgnored private let library: ActivityLibrary
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var observer: HKObserverQuery?
    @ObservationIgnored private var running: Task<Void, Never>?
    @ObservationIgnored private var pending = false
    @ObservationIgnored private var reloadsAll = false

    init(library: ActivityLibrary, defaults: UserDefaults = .standard) {
        self.library = library
        self.defaults = defaults
        isEnabled = defaults.bool(forKey: Keys.enabled)
        lastSync = defaults.object(forKey: Keys.lastSync) as? Date
    }

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    var isSyncing: Bool {
        status == .syncing
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
        guard isEnabled, isAvailable else { return }
        if let running {
            pending = true
            await running.value
            return
        }
        let task = Task {
            repeat {
                pending = false
                await performSync()
            } while pending && isEnabled
        }
        running = task
        await task.value
        running = nil
    }

    func reloadAll() async {
        reloadsAll = true
        await sync()
    }

    private func performSync() async {
        status = .syncing
        defer { progress = nil }
        let anchor = reloadsAll ? nil : storedAnchor()
        reloadsAll = false
        do {
            let result = try await HKAnchoredObjectQueryDescriptor(
                predicates: [.workout()],
                anchor: anchor
            ).result(for: store)
            let deleted = Set(result.deletedObjects.map { WorkoutProbe.externalID($0.uuid) })
            library.applyHealthChanges(added: [], deletedIDs: deleted)

            let addedIDs = Set(result.addedSamples.map(\.uuid))
            let workouts = result.addedSamples + (try await recentWorkouts()).filter { !addedIDs.contains($0.uuid) }
            if workouts.count >= Self.progressThreshold {
                progress = Progress(done: 0, total: workouts.count)
            }
            for start in stride(from: 0, to: workouts.count, by: Self.batchSize) {
                let batch = Array(workouts[start..<min(start + Self.batchSize, workouts.count)])
                library.applyHealthChanges(added: await read(batch), deletedIDs: [])
                progress?.done += batch.count
            }

            save(result.newAnchor)
            lastSync = .now
            defaults.set(lastSync, forKey: Keys.lastSync)
            status = .idle
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func read(_ workouts: [HKWorkout]) async -> [Activity] {
        let reader = HealthWorkoutReader(store: store)
        return await withTaskGroup(of: Activity.self) { group in
            for workout in workouts {
                group.addTask {
                    await reader.read(workout).activity
                }
            }
            var activities: [Activity] = []
            for await activity in group {
                activities.append(activity)
            }
            return activities
        }
    }

    private func recentWorkouts() async throws -> [HKWorkout] {
        let start = Calendar.current.date(byAdding: .day, value: -Self.recentDays, to: .now) ?? .now
        return try await HKSampleQueryDescriptor(
            predicates: [.workout(HKQuery.predicateForSamples(withStart: start, end: nil))],
            sortDescriptors: []
        ).result(for: store)
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
