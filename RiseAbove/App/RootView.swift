import SwiftUI

struct RootView: View {
    @State private var library = ActivityLibrary()
    @State private var raceGoal = RaceGoalStore()

    var body: some View {
        TabView {
            Tab("Overview", systemImage: "square.grid.2x2") {
                OverviewView()
            }
            Tab("Readiness", systemImage: "scope") {
                ReadinessView()
            }
            Tab("Disciplines", systemImage: "waveform.path.ecg") {
                DisciplinesView()
            }
            Tab("Plan", systemImage: "calendar") {
                SectionPlaceholder(title: "Plan", systemImage: "calendar")
            }
        }
        .environment(library)
        .environment(raceGoal)
        .tint(Palette.fitness)
    }
}

private struct SectionPlaceholder: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text("This section is being built. Overview and data import already work.")
            }
            .background { ConsoleBackground() }
            .navigationTitle(title)
            .settingsToolbar()
        }
    }
}
