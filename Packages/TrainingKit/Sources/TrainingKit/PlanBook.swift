import Foundation

public struct PlanBook: Codable, Hashable, Sendable {
    public var plans: [TrainingPlan]
    public var activePlanID: UUID?

    public init(plans: [TrainingPlan] = [], activePlanID: UUID? = nil) {
        self.plans = plans
        self.activePlanID = activePlanID
    }

    public var activePlan: TrainingPlan? {
        plans.first { $0.id == activePlanID } ?? plans.first
    }

    @discardableResult
    public mutating func createPlan(name: String, startingOn start: Date?, weeks: Int, calendar: Calendar) -> UUID {
        let plan = TrainingPlan(
            name: name,
            startMonday: start.map { calendar.monday(of: $0) },
            weeks: (0..<max(1, weeks)).map { _ in PlanWeek() }
        )
        plans.append(plan)
        activePlanID = plan.id
        return plan.id
    }

    @discardableResult
    public mutating func importPlans(_ imported: [TrainingPlan]) -> Int {
        var added = 0
        for plan in imported {
            if let index = plans.firstIndex(where: { $0.id == plan.id }) {
                plans[index] = plan
            } else {
                plans.append(plan)
                added += 1
            }
        }
        if activePlan == nil || activePlanID == nil {
            activePlanID = imported.first?.id ?? plans.first?.id
        }
        return added
    }

    public mutating func deletePlan(_ id: UUID) {
        plans.removeAll { $0.id == id }
        if activePlanID == id {
            activePlanID = plans.first?.id
        }
    }

    public mutating func renamePlan(_ id: UUID, to name: String) {
        update(id) { $0.name = name }
    }

    public mutating func appendWeek(to planID: UUID) {
        update(planID) { $0.weeks.append(PlanWeek()) }
    }

    public mutating func removeWeek(_ weekID: UUID, from planID: UUID) {
        update(planID) { plan in
            guard plan.weeks.count > 1 else { return }
            plan.weeks.removeAll { $0.id == weekID }
        }
    }

    public mutating func save(_ workout: PlannedWorkout, in planID: UUID, week weekID: UUID, day: Int) {
        guard (0..<PlanWeek.dayCount).contains(day) else { return }
        update(planID) { plan in
            plan.removeWorkout(workout.id)
            guard let index = plan.weeks.firstIndex(where: { $0.id == weekID }) else { return }
            plan.weeks[index].days[day].append(workout)
        }
    }

    public mutating func removeWorkout(_ workoutID: UUID, from planID: UUID) {
        update(planID) { $0.removeWorkout(workoutID) }
    }

    public mutating func toggleDay(_ day: Int, week weekID: UUID, in planID: UUID) {
        update(planID) { plan in
            guard let index = plan.weeks.firstIndex(where: { $0.id == weekID }),
                  plan.weeks[index].days.indices.contains(day),
                  !plan.weeks[index].days[day].isEmpty else { return }
            let isDone = !plan.weeks[index].done[day]
            plan.weeks[index].done[day] = isDone
            plan.weeks[index].dismissed[day] = !isDone
        }
    }

    @discardableResult
    public mutating func applyActuals(_ activities: [Activity], calendar: Calendar, coverage: Double = 0.8) -> Int {
        var marked = 0
        for planIndex in plans.indices where plans[planIndex].startMonday != nil {
            for weekIndex in plans[planIndex].weeks.indices {
                let actuals = plans[planIndex].actuals(forWeek: weekIndex, activities: activities, calendar: calendar)
                guard !actuals.isEmpty else { continue }
                let week = plans[planIndex].weeks[weekIndex]
                for (day, workouts) in week.days.enumerated() where !workouts.isEmpty && !week.done[day] && !week.dismissed[day] {
                    let covered = workouts.allSatisfy { workout in
                        guard let actual = actuals[workout.id] else { return false }
                        guard let completion = actual.completion(of: workout.distance) else { return true }
                        return completion >= coverage
                    }
                    if covered {
                        plans[planIndex].weeks[weekIndex].done[day] = true
                        marked += 1
                    }
                }
            }
        }
        return marked
    }

    private mutating func update(_ id: UUID, _ change: (inout TrainingPlan) -> Void) {
        guard let index = plans.firstIndex(where: { $0.id == id }) else { return }
        change(&plans[index])
    }
}

extension TrainingPlan {
    mutating func removeWorkout(_ id: UUID) {
        for week in weeks.indices {
            for day in weeks[week].days.indices {
                weeks[week].days[day].removeAll { $0.id == id }
                if weeks[week].days[day].isEmpty {
                    weeks[week].done[day] = false
                    weeks[week].dismissed[day] = false
                }
            }
        }
    }

    public func location(of workoutID: UUID) -> (weekID: UUID, day: Int)? {
        for week in weeks {
            for (day, workouts) in week.days.enumerated() where workouts.contains(where: { $0.id == workoutID }) {
                return (week.id, day)
            }
        }
        return nil
    }

    public func currentWeekIndex(today: Date, calendar: Calendar) -> Int? {
        guard let start = startMonday else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: today)).day ?? -1
        guard days >= 0 else { return nil }
        let index = days / 7
        return weeks.indices.contains(index) ? index : nil
    }

    public func comparison(forWeek index: Int, activities: [Activity], today: Date, calendar: Calendar) -> [VolumeComparison]? {
        guard weeks.indices.contains(index),
              let start = weekStart(index, calendar: calendar),
              start <= today else { return nil }
        let end = calendar.adding(days: 7, to: start)
        let result = weeks[index].comparison(with: activities, from: start, to: end)
        return result.contains { $0.actual > 0 } ? result : nil
    }
}
