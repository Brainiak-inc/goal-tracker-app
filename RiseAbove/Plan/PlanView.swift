import SwiftUI
import TrainingKit

struct PlanView: View {
    @Environment(PlanStore.self) private var plans
    @Environment(ActivityLibrary.self) private var library
    @Environment(BackupManager.self) private var backup
    @Environment(\.calendar) private var calendar
    @AppStorage(SportProfile.storageKey) private var profile: SportProfile = .triathlon

    @State private var draft: WorkoutDraft?
    @State private var createsPlan = false
    @State private var renamedPlan: TrainingPlan?
    @State private var newName = ""
    @State private var deletedPlan: TrainingPlan?
    @State private var edge: Edge = .trailing

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let plan = plans.book.activePlan {
                            planChips(active: plan)
                            if backup.needsReminder {
                                BackupReminderCard()
                            }
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(Array(plan.weeks.indices), id: \.self) { index in
                                    weekCard(plan, index)
                                        .id(plan.weeks[index].id)
                                }
                                Button {
                                    plans.perform { $0.appendWeek(to: plan.id) }
                                } label: {
                                    Label("Add week", systemImage: "plus")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.consoleSecondary)
                            }
                            .id(plan.id)
                            .switchTransition(edge: edge)
                            .swipeToSwitch(activePlanSelection, among: plans.book.plans.map(\.id), edge: $edge)
                        } else {
                            invitation
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .onAppear {
                    scrollToCurrentWeek(proxy)
                }
                .onChange(of: plans.book.activePlanID) {
                    scrollToCurrentWeek(proxy)
                }
            }
            .background { ConsoleBackground() }
            .navigationTitle("Plan")
            .navigationSubtitle(subtitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        AdherenceCalendarView()
                    } label: {
                        Label("Adherence calendar", systemImage: "calendar.badge.checkmark")
                    }
                }
                if let plan = plans.book.activePlan {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu("Add", systemImage: "plus") {
                            Button("New workout", systemImage: "figure.run") {
                                draft = newDraft(in: plan, day: nil, weekIndex: nil)
                            }
                            Button("Add week", systemImage: "calendar.badge.plus") {
                                plans.perform { $0.appendWeek(to: plan.id) }
                            }
                            Button("New plan", systemImage: "square.stack") {
                                createsPlan = true
                            }
                        }
                    }
                }
            }
            .settingsToolbar()
            .sheet(item: $draft) { draft in
                if let plan = plans.book.activePlan {
                    WorkoutSheet(plan: plan, draft: draft)
                }
            }
            .sheet(isPresented: $createsPlan) {
                CreatePlanSheet()
            }
            .alert("Rename plan", isPresented: Binding(get: { renamedPlan != nil }, set: { if !$0 { renamedPlan = nil } })) {
                TextField("Name", text: $newName)
                Button("Save") {
                    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let plan = renamedPlan, !trimmed.isEmpty {
                        plans.perform { $0.renamePlan(plan.id, to: trimmed) }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog(
                "Delete plan?",
                isPresented: Binding(get: { deletedPlan != nil }, set: { if !$0 { deletedPlan = nil } }),
                titleVisibility: .visible,
                presenting: deletedPlan
            ) { plan in
                Button("Delete", role: .destructive) {
                    plans.perform { $0.deletePlan(plan.id) }
                }
            } message: { plan in
                Text("“\(plan.name)” and all its weeks will be deleted.")
            }
        }
    }

    private var activePlanSelection: Binding<UUID> {
        Binding {
            plans.book.activePlan?.id ?? UUID()
        } set: { id in
            plans.perform { $0.activePlanID = id }
        }
    }

    private var subtitle: String {
        guard let plan = plans.book.activePlan,
              let index = plan.currentWeekIndex(today: .now, calendar: calendar) else { return "" }
        return String(localized: "Week \(index + 1) of \(plan.weeks.count)")
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Create a training plan")
                .font(.title3.bold())
                .foregroundStyle(Palette.text)
            Text("Plan workouts by week and tick them off. With a dated plan you also see planned against actual volume once workouts are imported.")
                .foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                createsPlan = true
            } label: {
                Label("Create plan", systemImage: "calendar.badge.plus")
            }
            .buttonStyle(.consolePrimary)
            WebBackupImportButton(title: "Restore from backup")
                .buttonStyle(.consoleSecondary)
        }
        .padding(18)
        .consoleCard()
    }

    private func planChips(active: TrainingPlan) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(plans.book.plans) { plan in
                    chip(plan, isActive: plan.id == active.id)
                }
                Button {
                    createsPlan = true
                } label: {
                    Image(systemName: "plus")
                        .frame(height: 20)
                }
                .buttonStyle(.consoleChip(isActive: false))
                .accessibilityLabel(Text("New plan"))
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(_ plan: TrainingPlan, isActive: Bool) -> some View {
        Button(plan.name) {
            switchSelection(to: plan.id, selection: activePlanSelection, values: plans.book.plans.map(\.id), edge: $edge)
        }
        .buttonStyle(.consoleChip(isActive: isActive))
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                newName = plan.name
                renamedPlan = plan
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                deletedPlan = plan
            }
        }
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func weekCard(_ plan: TrainingPlan, _ index: Int) -> some View {
        let week = plan.weeks[index]
        return WeekCard(
            plan: plan,
            index: index,
            comparison: plan.comparison(forWeek: index, activities: library.activities, today: .now, calendar: calendar),
            actuals: plan.actuals(forWeek: index, activities: library.activities, calendar: calendar),
            onToggle: { day in
                plans.perform { $0.toggleDay(day, week: week.id, in: plan.id) }
            },
            onAdd: { day in
                draft = newDraft(in: plan, day: day, weekIndex: index)
            },
            onEdit: { workout, day in
                draft = WorkoutDraft(weekID: week.id, day: day, workout: workout, isNew: false)
            },
            onRemove: {
                plans.perform { $0.removeWeek(week.id, from: plan.id) }
            }
        )
    }

    private func newDraft(in plan: TrainingPlan, day: Int?, weekIndex: Int?) -> WorkoutDraft {
        let current = plan.currentWeekIndex(today: .now, calendar: calendar)
        let index = weekIndex ?? current ?? 0
        let today = (calendar.component(.weekday, from: .now) + 5) % 7
        let defaultDay = day ?? (index == current ? today : 0)
        return WorkoutDraft(
            weekID: plan.weeks[index].id,
            day: defaultDay,
            workout: PlannedWorkout(discipline: profile.disciplines.last ?? .run),
            isNew: true
        )
    }

    private func scrollToCurrentWeek(_ proxy: ScrollViewProxy) {
        guard let plan = plans.book.activePlan,
              let index = plan.currentWeekIndex(today: .now, calendar: calendar) else { return }
        proxy.scrollTo(plan.weeks[index].id, anchor: .top)
    }
}
