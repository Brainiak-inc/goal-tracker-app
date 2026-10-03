import SwiftUI
import TrainingKit

struct MetricsGuideView: View {
    enum Metric: Hashable, CaseIterable {
        case form
        case fitness
        case fatigue
        case load
    }

    var focus: Metric = .form

    @Environment(ActivityLibrary.self) private var library

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("How the app turns your workouts into fitness, fatigue, and form.")
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    formSection.id(Metric.form)
                    fitnessSection.id(Metric.fitness)
                    fatigueSection.id(Metric.fatigue)
                    loadSection.id(Metric.load)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo(focus, anchor: .top)
                }
            }
        }
        .background { ConsoleBackground() }
        .navigationTitle("Metrics")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var current: FitnessSnapshot? {
        library.fitness
    }

    private var formSection: some View {
        GuideCard(title: "Form (TSB)", color: Palette.form, value: current.map { Text($0.form.displayRounded, format: .number) }, caption: current.map { Text(FormZone(form: $0.form).title) }) {
            GuideParagraph(heading: "What it is", text: "Fitness minus fatigue as of yesterday. Above zero you are fresh, below zero you carry fatigue from recent training.")
            FormZoneScale(form: current?.form)
            VStack(alignment: .leading, spacing: 6) {
                ZoneRow(zone: .fresh, range: "above +5", meaning: "rested: a good time for a race or a test")
                ZoneRow(zone: .neutral, range: "−10 to +5", meaning: "normal training")
                ZoneRow(zone: .building, range: "−30 to −10", meaning: "productive fatigue: fitness is growing")
                ZoneRow(zone: .overreaching, range: "below −30", meaning: "too much fatigue: add rest days")
            }
        }
    }

    private var fitnessSection: some View {
        GuideCard(title: "Fitness (CTL)", color: Palette.fitness, value: current.map { Text($0.fitness.displayRounded, format: .number) }, caption: library.fitnessTrend.map { Text("\(Formatting.signed($0.delta)) per week") }) {
            GuideParagraph(heading: "What it is", text: "Your training base: the average daily load over about six weeks, where recent days count more. It grows and fades slowly.")
            GuideParagraph(heading: "How it is calculated", text: "Every day fitness moves one forty-second of the way towards that day's load.")
            GuideParagraph(heading: "How to read it", text: "A steady rise of a few points a week is a healthy build. Sharp jumps raise the risk of overload.")
        }
    }

    private var fatigueSection: some View {
        GuideCard(title: "Fatigue (ATL)", color: Palette.fatigue, value: library.series.last.map { Text($0.fatigue.displayRounded, format: .number) }, caption: nil) {
            GuideParagraph(heading: "What it is", text: "How tired you are from recent training: the same average, but over about a week. It reacts quickly to hard days and to rest.")
            GuideParagraph(heading: "How it is calculated", text: "Every day fatigue moves one seventh of the way towards that day's load.")
        }
    }

    private var loadSection: some View {
        GuideCard(title: "Load (TSS)", color: Palette.fatigue, value: library.hasData ? Text(library.weeklyStress.displayRounded, format: .number) : nil, caption: library.hasData ? Text("TSS over 7 days") : nil) {
            GuideParagraph(heading: "What it is", text: "Each workout gets load points for how long and how hard it was. An hour at your threshold heart rate is 100 points.")
            GuideParagraph(heading: "How it is calculated", text: "Hours × (average heart rate ÷ threshold heart rate)² × 100. Workouts without heart rate add no load.")
            NavigationLink {
                ThresholdView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Threshold heart rate")
                            .foregroundStyle(Palette.text)
                        Group {
                            if library.thresholdIsManual {
                                Text("set manually")
                            } else {
                                Text("estimated from runs of 20 minutes or longer")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Text("\(library.settings.thresholdHeartRate.displayRounded) bpm")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Palette.text)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Palette.muted)
                }
                .padding(12)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct GuideCard<Content: View>: View {
    let title: LocalizedStringKey
    let color: Color
    let value: Text?
    let caption: Text?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .consoleLabel()
                Spacer()
                if let value {
                    VStack(alignment: .trailing, spacing: 2) {
                        value
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                            .foregroundStyle(color)
                        if let caption {
                            caption
                                .font(.caption)
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
            }
            content
        }
        .padding(16)
        .consoleCard()
    }
}

private struct GuideParagraph: View {
    let heading: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(heading)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.text)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ZoneRow: View {
    let zone: FormZone
    let range: LocalizedStringKey
    let meaning: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(zone.color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(zone.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.text)
                    Text(range)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Palette.muted)
                }
                Text(meaning)
                    .font(.caption)
                    .foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FormZoneScale: View {
    let form: Double?

    private let lower = -45.0
    private let upper = 25.0
    private let zones: [(FormZone, Double, Double)] = [
        (.overreaching, -45, -30),
        (.building, -30, -10),
        (.neutral, -10, 5),
        (.fresh, 5, 25)
    ]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                HStack(spacing: 2) {
                    ForEach(zones, id: \.0) { zone, from, to in
                        Capsule()
                            .fill(zone.color.opacity(0.75))
                            .frame(width: max(0, width * (to - from) / (upper - lower) - 2))
                    }
                }
                if let form {
                    let position = (min(upper, max(lower, form)) - lower) / (upper - lower)
                    Circle()
                        .fill(Palette.text)
                        .overlay { Circle().stroke(Palette.background, lineWidth: 2) }
                        .frame(width: 14, height: 14)
                        .offset(x: width * position - 7)
                }
            }
            .frame(height: 14)
        }
        .frame(height: 14)
        .accessibilityHidden(true)
    }
}

extension FormZone {
    var color: Color {
        switch self {
        case .fresh: Palette.success
        case .neutral: Palette.form
        case .building: Palette.fatigue
        case .overreaching: Palette.danger
        }
    }
}
