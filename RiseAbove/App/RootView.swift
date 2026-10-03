import SwiftUI
import TrainingKit

struct RootView: View {
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon
    @AppStorage(OnboardingView.completedKey) private var isOnboarded = false
    @State private var navigation = AppNavigation()

    var body: some View {
        TabView(selection: $navigation.tab) {
            Tab("Overview", systemImage: "square.grid.2x2", value: AppTab.overview) {
                OverviewView()
            }
            Tab("Readiness", systemImage: "scope", value: AppTab.readiness) {
                ReadinessView()
            }
            Tab(disciplinesTitle, systemImage: profile.single?.symbol ?? "waveform.path.ecg", value: AppTab.disciplines) {
                DisciplinesView()
            }
            Tab("Plan", systemImage: "calendar", value: AppTab.plan) {
                PlanView()
            }
        }
        .tint(Palette.fitness)
        .environment(navigation)
        .fullScreenCover(isPresented: Binding { !isOnboarded } set: { isOnboarded = !$0 }) {
            OnboardingView()
        }
    }

    private var disciplinesTitle: LocalizedStringResource {
        profile.single?.title ?? "Disciplines"
    }
}
