import SwiftUI
import TrainingKit

struct AllActivitiesView: View {
    @Environment(ActivityLibrary.self) private var library
    @State private var filter: Discipline?
    @State private var selected: Activity?

    var body: some View {
        let months = groupedByMonth
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if months.isEmpty {
                    Text("No workouts match this filter.")
                        .foregroundStyle(Palette.muted)
                        .padding(16)
                        .consoleCard(brackets: false)
                }
                ForEach(months, id: \.month) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(Text(group.month, format: .dateTime.month(.wide))) \(String(library.calendar.component(.year, from: group.month)))")
                            .consoleLabel()
                            .padding(.leading, 4)
                        VStack(spacing: 0) {
                            ForEach(Array(group.activities.enumerated()), id: \.element.identity) { index, activity in
                                if index > 0 {
                                    Divider().overlay(Color.white.opacity(0.06))
                                }
                                Button {
                                    selected = activity
                                } label: {
                                    ActivityRow(activity: activity, detail: .stress(library.stress(for: activity)))
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .consoleCard(brackets: false)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background { ConsoleBackground() }
        .navigationTitle("All workouts")
        .navigationSubtitle(Text("\(filtered.count) workouts"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Discipline", selection: $filter) {
                        Text("All disciplines").tag(Discipline?.none)
                        ForEach(Discipline.allCases, id: \.self) { discipline in
                            Text(discipline.title).tag(Discipline?.some(discipline))
                        }
                    }
                } label: {
                    Label("Filter", systemImage: filter == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .sheet(item: $selected) { activity in
            ActivityDetailSheet(activity: activity)
        }
    }

    private var filtered: [Activity] {
        guard let filter else { return library.activities }
        return library.activities.filter { $0.discipline == filter }
    }

    private var groupedByMonth: [(month: Date, activities: [Activity])] {
        let calendar = library.calendar
        let groups = Dictionary(grouping: filtered) { activity in
            calendar.dateInterval(of: .month, for: activity.start)?.start ?? activity.start
        }
        return groups
            .map { (month: $0.key, activities: $0.value.sorted { $0.start > $1.start }) }
            .sorted { $0.month > $1.month }
    }
}
