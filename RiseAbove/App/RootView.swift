import SwiftUI
import TrainingKit

struct RootView: View {
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon
    @AppStorage(OnboardingView.completedKey) private var isOnboarded = false

    var body: some View {
        TabView {
            Tab("Overview", systemImage: "square.grid.2x2") {
                OverviewView()
            }
            Tab("Readiness", systemImage: "scope") {
                ReadinessView()
            }
            Tab(disciplinesTitle, systemImage: profile.single?.symbol ?? "waveform.path.ecg") {
                DisciplinesView()
            }
            Tab("Plan", systemImage: "calendar") {
                PlanView()
            }
        }
        .tint(Palette.fitness)
        .fullScreenCover(isPresented: Binding { !isOnboarded } set: { isOnboarded = !$0 }) {
            OnboardingView()
        }
    }

    private var disciplinesTitle: LocalizedStringResource {
        profile.single?.title ?? "Disciplines"
    }
}
