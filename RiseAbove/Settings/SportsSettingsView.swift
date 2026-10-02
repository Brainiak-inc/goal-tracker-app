import SwiftUI
import TrainingKit

struct SportsSettingsView: View {
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Choose what you train. This sets which disciplines the app shows.")
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
                SportPicker(profile: $profile)
                Text("Fitness, fatigue, and form always count every workout. At least one sport stays selected.")
                    .font(.footnote)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background { ConsoleBackground() }
        .navigationTitle("Sports")
        .navigationBarTitleDisplayMode(.inline)
    }
}
