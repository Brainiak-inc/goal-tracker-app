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
            Text("Syncing…")
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
