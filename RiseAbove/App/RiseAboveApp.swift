import SwiftUI

@main
struct RiseAboveApp: App {
    @State private var library: ActivityLibrary
    @State private var healthSync: HealthSync
    @State private var raceGoal: RaceGoalStore
    @State private var plans: PlanStore
    @State private var adherence: AdherenceStore
    @State private var backup: BackupManager
    @AppStorage(PlanStore.autoCheckKey) private var autoCheck = true
    @AppStorage(UnitSystem.storageKey) private var units: UnitSystem = .metric
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let library = ActivityLibrary()
        let healthSync = HealthSync(library: library)
        let raceGoal = RaceGoalStore()
        let plans = PlanStore()
        let adherence = AdherenceStore()
        _library = State(initialValue: library)
        _healthSync = State(initialValue: healthSync)
        _raceGoal = State(initialValue: raceGoal)
        _plans = State(initialValue: plans)
        _adherence = State(initialValue: adherence)
        _backup = State(initialValue: BackupManager(library: library, plans: plans, raceGoal: raceGoal, adherence: adherence))
        healthSync.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(healthSync)
                .environment(raceGoal)
                .environment(plans)
                .environment(adherence)
                .environment(backup)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await healthSync.sync() }
            case .background:
                let task = UIApplication.shared.beginBackgroundTask(withName: "backup")
                Task {
                    await backup.flush()
                    UIApplication.shared.endBackgroundTask(task)
                }
            default:
                break
            }
        }
        .onChange(of: library.activities) {
            backup.dataDidChange()
        }
        .onChange(of: library.settings) {
            backup.dataDidChange()
        }
        .onChange(of: raceGoal.config) {
            backup.dataDidChange()
        }
        .onChange(of: adherence.book) {
            backup.dataDidChange()
        }
        .onChange(of: units) {
            backup.dataDidChange()
        }
        .onChange(of: library.activities, initial: true) {
            markPlanFromActuals()
        }
        .onChange(of: plans.book) {
            markPlanFromActuals()
            backup.dataDidChange()
        }
        .onChange(of: autoCheck) {
            markPlanFromActuals()
            backup.dataDidChange()
        }
    }

    private func markPlanFromActuals() {
        guard autoCheck else { return }
        plans.applyActuals(library.activities, calendar: library.calendar)
    }
}
