import SwiftUI

struct RootView: View {
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
                PlanView()
            }
        }
        .tint(Palette.fitness)
    }
}
