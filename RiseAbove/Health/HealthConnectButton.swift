import HealthKitUI
import SwiftUI

struct HealthConnectButton: View {
    @Environment(HealthSync.self) private var healthSync
    @State private var requested = false
    @State private var failed = false

    var body: some View {
        Button {
            requested.toggle()
        } label: {
            Label("Connect Apple Health", systemImage: "heart.text.square")
        }
        .healthDataAccessRequest(store: healthSync.store, readTypes: HealthWorkoutReader.readTypes, trigger: requested) { result in
            Task { @MainActor in
                switch result {
                case .success:
                    await healthSync.enable()
                case .failure:
                    failed = true
                }
            }
        }
        .alert("Couldn't connect to Health", isPresented: $failed) {
            Button("OK") {}
        } message: {
            Text("Check that Health is available on this iPhone and try again.")
        }
    }
}

struct HealthSyncStatus: View {
    @Environment(HealthSync.self) private var healthSync

    var body: some View {
        switch healthSync.status {
        case .syncing:
            HStack(spacing: 6) {
                ConsoleSpinner(size: 11, lineWidth: 1.6)
                if let progress = healthSync.progress {
                    Text("Loading workouts: \(progress.done) of \(progress.total)")
                } else {
                    Text("Syncing…")
                }
            }
        case .failed:
            Text("Sync failed")
                .foregroundStyle(Palette.fatigue)
        case .idle:
            if let date = healthSync.lastSync {
                Text("Synced \(Text(date, format: .relative(presentation: .named)))")
            } else {
                Text("Not synced yet")
            }
        }
    }
}

struct HealthLoadingCard: View {
    @Environment(HealthSync.self) private var healthSync

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ConsoleSpinner(size: 18, lineWidth: 2.2)
                Text("Loading workouts from Apple Health")
                    .font(.headline)
                    .foregroundStyle(Palette.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let progress = healthSync.progress {
                ConsoleProgressBar(value: Double(progress.done) / Double(max(progress.total, 1)))
                Text("\(progress.done) of \(progress.total)")
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(Palette.muted)
            } else {
                Text("The first time can take a minute: the whole workout history is loaded.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .consoleCard()
        .accessibilityElement(children: .combine)
    }
}
