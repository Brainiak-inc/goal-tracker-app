import SwiftUI
import TrainingKit

struct ThresholdView: View {
    @Environment(ActivityLibrary.self) private var library
    @State private var isManual = false
    @State private var value = 170
    @State private var isReady = false

    var body: some View {
        List {
            Section {
                Picker("Mode", selection: $isManual) {
                    Text("Automatic").tag(false)
                    Text("Manual").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                if isManual {
                    Picker("Threshold heart rate", selection: $value) {
                        ForEach(120...210, id: \.self) { bpm in
                            Text("\(bpm) bpm").tag(bpm)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                } else {
                    LabeledContent("Current value") {
                        Text("\(library.settings.thresholdHeartRate.displayRounded) bpm")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            } footer: {
                if isManual {
                    Text("Use a value from a lab test or a 30-minute time trial: your average heart rate over the last 20 minutes.")
                } else if library.thresholdEstimate != nil {
                    Text("The highest average heart rate among runs of 20 minutes or longer. It updates with every import or sync.")
                } else {
                    Text("There are no runs with heart rate yet, so the default of 170 bpm is used.")
                }
            }
            .listRowBackground(Palette.surface)

            Section {
                Text("Threshold heart rate is the highest heart rate you can hold for about an hour of hard effort. Training load (TSS) compares every workout with it: one hour at threshold equals 100.")
                    .font(.subheadline)
                    .foregroundStyle(Palette.muted)
            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Threshold heart rate")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            isManual = library.thresholdIsManual
            value = min(210, max(120, library.settings.thresholdHeartRate.displayRounded))
            isReady = true
        }
        .onChange(of: isManual) { apply() }
        .onChange(of: value) { apply() }
    }

    private func apply() {
        guard isReady else { return }
        library.setThreshold(manual: isManual ? Double(value) : nil)
    }
}
