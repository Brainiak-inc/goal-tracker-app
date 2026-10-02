import HealthKitUI
import SwiftUI
import TrainingKit

struct HealthDiagnosticsView: View {
    @State private var probe = HealthProbe()
    @State private var accessRequested = false

    var body: some View {
        List {
            switch probe.status {
            case .idle, .loading:
                Section {
                    HStack(spacing: 12) {
                        ConsoleSpinner(size: 16, lineWidth: 2)
                        Text("Loading…")
                    }
                }
            case .unavailable:
                Section {
                    Text("Health data isn't available on this device.")
                }
            case .failed(let message):
                Section {
                    Text(verbatim: message)
                }
            case .loaded where probe.workouts.isEmpty:
                Section {
                    Text("No workouts found. Check access in Settings → Health → Data Access & Devices.")
                }
            case .loaded:
                summary
                ForEach(probe.workouts) { workout in
                    WorkoutProbeSection(workout: workout, stress: probe.stress(for: workout))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.background)
        .navigationTitle("Health check")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await probe.load() }
                }
                .disabled(probe.status == .loading)
            }
        }
        .healthDataAccessRequest(store: probe.store, readTypes: HealthWorkoutReader.readTypes, trigger: accessRequested) { result in
            Task { await probe.handleAccess(result) }
        }
        .onAppear {
            if probe.isAvailable {
                accessRequested = true
            } else {
                probe.markUnavailable()
            }
        }
    }

    private var summary: some View {
        let total = probe.workouts.count
        let withHeartRate = probe.workouts.filter { $0.averageHeartRate != nil }.count
        let attached = probe.workouts.filter { $0.heartRateOrigin == .workout }.count
        let fromSamples = probe.workouts.filter { $0.heartRateOrigin == .samples }.count
        let sources = Set(probe.workouts.map(\.sourceName)).sorted().formatted(.list(type: .and))

        return Section {
            LabeledContent("Workouts", value: total, format: .number)
            LabeledContent("With heart rate") {
                Text("\(withHeartRate) of \(total)")
            }
            LabeledContent("Heart rate attached to workout", value: attached, format: .number)
            LabeledContent("Heart rate from samples only", value: fromSamples, format: .number)
            LabeledContent("Threshold heart rate") {
                Text("\(Int(probe.settings.thresholdHeartRate)) bpm")
            }
            LabeledContent("Sources", value: sources)
        } header: {
            Text("Summary")
        } footer: {
            if probe.thresholdEstimate == nil {
                Text("Default value, no runs with heart rate yet")
            } else {
                Text("Estimated from runs of 20 minutes or longer")
            }
        }
    }
}

private struct WorkoutProbeSection: View {
    let workout: WorkoutProbe
    let stress: Double

    var body: some View {
        Section {
            LabeledContent("Duration") {
                Text(Duration.seconds(workout.duration), format: .units(allowed: [.hours, .minutes], width: .wide))
            }
            LabeledContent("Distance") {
                VStack(alignment: .trailing, spacing: 2) {
                    if let distance = distanceText {
                        Text(distance)
                    } else {
                        Text("No distance")
                    }
                    originLabel(workout.distanceOrigin == .workout, workout.distanceOrigin == .samples)
                }
            }
            LabeledContent("Heart rate in workout") {
                heartRate(workout.workoutHeartRate)
            }
            LabeledContent("Heart rate from samples") {
                heartRate(workout.sampleHeartRate)
            }
            LabeledContent("Heart rate samples", value: workout.heartRateSampleCount, format: .number)
            if !workout.heartRateSources.isEmpty {
                LabeledContent("Heart rate sources", value: workout.heartRateSources.formatted(.list(type: .and)))
            }
            LabeledContent("Load (TSS)", value: stress, format: .number.precision(.fractionLength(0)))
            if let power = workout.averagePower {
                LabeledContent("Power") {
                    Text("\(Int(power.rounded())) W")
                }
            }
            LabeledContent("Source", value: workout.sourceName)
        } header: {
            ViewThatFits(in: .horizontal) {
                HStack {
                    title
                    Spacer()
                    date
                }
                VStack(alignment: .leading, spacing: 2) {
                    title
                    date
                }
            }
        }
    }

    private var title: some View {
        Text(workout.discipline.title)
            .font(.headline)
            .foregroundStyle(Palette.text)
    }

    private var date: some View {
        Text(workout.start, format: .dateTime.day().month(.wide).hour().minute())
            .foregroundStyle(Palette.muted)
    }

    private var distanceText: String? {
        guard let meters = workout.distance else { return nil }
        if workout.discipline == .swim {
            return Measurement(value: meters, unit: UnitLength.meters).formatted(
                .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0)))
            )
        }
        return Measurement(value: meters / 1000, unit: UnitLength.kilometers).formatted(
            .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(2)))
        )
    }

    @ViewBuilder
    private func heartRate(_ value: Double?) -> some View {
        if let value {
            Text("\(Int(value.rounded())) bpm")
        } else {
            Text("None")
                .foregroundStyle(Palette.muted)
        }
    }

    @ViewBuilder
    private func originLabel(_ fromWorkout: Bool, _ fromSamples: Bool) -> some View {
        if fromWorkout {
            Text("from workout")
                .font(.caption)
                .foregroundStyle(Palette.muted)
        } else if fromSamples {
            Text("from samples")
                .font(.caption)
                .foregroundStyle(Palette.fatigue)
        }
    }
}

#Preview {
    NavigationStack {
        HealthDiagnosticsView()
    }
}
