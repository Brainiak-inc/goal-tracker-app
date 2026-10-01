import Foundation
import Testing
@testable import TrainingKit

struct PlanBookTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func date(_ day: Int, month: Int = 10, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    @Test func createdPlanStartsOnMondayAndBecomesActive() throws {
        var book = PlanBook()
        let first = book.createPlan(name: "Base", startingOn: date(1), weeks: 4, calendar: calendar)
        let second = book.createPlan(name: "Off-season", startingOn: nil, weeks: 0, calendar: calendar)
        #expect(book.activePlanID == second)
        #expect(book.plans[0].startMonday == date(28, month: 9))
        #expect(book.plans[0].weeks.count == 4)
        #expect(book.plans[1].weeks.count == 1)

        book.deletePlan(second)
        #expect(book.activePlan?.id == first)
        book.deletePlan(first)
        #expect(book.activePlan == nil)
    }

    @Test func savingAWorkoutAgainMovesIt() throws {
        var book = PlanBook()
        let planID = book.createPlan(name: "Base", startingOn: nil, weeks: 2, calendar: calendar)
        let weeks = try #require(book.activePlan?.weeks)
        var workout = PlannedWorkout(discipline: .run, distance: 8_000)
        book.save(workout, in: planID, week: weeks[0].id, day: 0)
        book.toggleDay(0, week: weeks[0].id, in: planID)
        #expect(book.activePlan?.weeks[0].done[0] == true)

        workout.distance = 10_000
        book.save(workout, in: planID, week: weeks[1].id, day: 3)
        let plan = try #require(book.activePlan)
        #expect(plan.weeks[0].days[0].isEmpty)
        #expect(plan.weeks[0].done[0] == false)
        #expect(plan.weeks[1].days[3] == [workout])
        #expect(plan.location(of: workout.id)?.day == 3)

        book.removeWorkout(workout.id, from: planID)
        #expect(book.activePlan?.weeks[1].days[3].isEmpty == true)
    }

    @Test func restDaysCannotBeChecked() throws {
        var book = PlanBook()
        let planID = book.createPlan(name: "Base", startingOn: nil, weeks: 1, calendar: calendar)
        let weekID = try #require(book.activePlan?.weeks.first?.id)
        book.toggleDay(2, week: weekID, in: planID)
        #expect(book.activePlan?.weeks[0].done[2] == false)
    }

    @Test func lastWeekIsKept() throws {
        var book = PlanBook()
        let planID = book.createPlan(name: "Base", startingOn: nil, weeks: 1, calendar: calendar)
        book.appendWeek(to: planID)
        let ids = try #require(book.activePlan?.weeks.map(\.id))
        book.removeWeek(ids[0], from: planID)
        book.removeWeek(ids[1], from: planID)
        #expect(book.activePlan?.weeks.map(\.id) == [ids[1]])
        book.renamePlan(planID, to: "Build")
        #expect(book.activePlan?.name == "Build")
    }

    @Test func importReplacesSamePlansAndAppendsNewOnes() {
        var book = PlanBook()
        let existing = book.createPlan(name: "Local", startingOn: nil, weeks: 1, calendar: calendar)
        var updatedCopy = book.plans[0]
        updatedCopy.name = "From web"
        let fresh = TrainingPlan(name: "Second", weeks: [PlanWeek()])
        #expect(book.importPlans([updatedCopy, fresh]) == 1)
        #expect(book.plans.map(\.name) == ["From web", "Second"])
        #expect(book.activePlanID == existing)

        var empty = PlanBook()
        empty.importPlans([fresh])
        #expect(empty.activePlan?.id == fresh.id)
    }

    @Test func currentWeekFollowsTheCalendar() {
        let plan = TrainingPlan(name: "Base", startMonday: date(21, month: 9), weeks: [PlanWeek(), PlanWeek(), PlanWeek()])
        #expect(plan.currentWeekIndex(today: date(20, month: 9), calendar: calendar) == nil)
        #expect(plan.currentWeekIndex(today: date(21, month: 9), calendar: calendar) == 0)
        #expect(plan.currentWeekIndex(today: date(1, hour: 18), calendar: calendar) == 1)
        #expect(plan.currentWeekIndex(today: date(12), calendar: calendar) == nil)
        #expect(TrainingPlan(name: "Free").currentWeekIndex(today: date(1), calendar: calendar) == nil)
    }

    @Test func comparisonNeedsAStartedWeekWithActualVolume() {
        var week = PlanWeek()
        week.days[0] = [PlannedWorkout(discipline: .run, distance: 8_000)]
        week.days[2] = [PlannedWorkout(discipline: .swim, distance: 1_500)]
        let plan = TrainingPlan(name: "Base", startMonday: date(28, month: 9), weeks: [week, week])
        let run = Activity(start: date(29, month: 9, hour: 7), discipline: .run, sourceType: "Running", title: "Run", duration: 2400, distance: 7_000)

        let current = plan.comparison(forWeek: 0, activities: [run], today: date(1), calendar: calendar)
        #expect(current == [
            VolumeComparison(discipline: .swim, planned: 1_500, actual: 0),
            VolumeComparison(discipline: .run, planned: 8_000, actual: 7_000)
        ])
        #expect(plan.comparison(forWeek: 0, activities: [], today: date(1), calendar: calendar) == nil)
        #expect(plan.comparison(forWeek: 1, activities: [run], today: date(1), calendar: calendar) == nil)
        #expect(TrainingPlan(name: "Free", weeks: [week]).comparison(forWeek: 0, activities: [run], today: date(1), calendar: calendar) == nil)
    }
}

struct AutoCheckTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func at(_ day: Int, hour: Int = 7) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
    }

    func run(_ day: Int, _ distance: Double, discipline: Discipline = .run) -> Activity {
        Activity(start: at(day), discipline: discipline, sourceType: discipline.rawValue, title: "", duration: 2400, distance: distance)
    }

    func book() -> (PlanBook, UUID, UUID) {
        var week = PlanWeek()
        week.days[0] = [PlannedWorkout(discipline: .run, distance: 10_000)]
        week.days[1] = [PlannedWorkout(discipline: .swim, distance: 1_500), PlannedWorkout(discipline: .run, distance: 5_000)]
        week.days[2] = [PlannedWorkout(discipline: .strength)]
        week.days[3] = [PlannedWorkout(discipline: .bike)]
        let plan = TrainingPlan(name: "Base", startMonday: at(21, hour: 0), weeks: [week])
        return (PlanBook(plans: [plan], activePlanID: plan.id), plan.id, week.id)
    }

    @Test func daysCoveredByActualsAreMarked() {
        var (book, _, _) = book()
        let activities = [
            run(21, 8_000),
            run(22, 1_500, discipline: .swim),
            run(23, 0, discipline: .strength),
            run(24, 30_000, discipline: .bike)
        ]
        #expect(book.applyActuals(activities, calendar: calendar) == 3)
        let done = book.activePlan!.weeks[0].done
        #expect(done[0])
        #expect(!done[1])
        #expect(done[2])
        #expect(done[3])
        #expect(book.applyActuals(activities, calendar: calendar) == 0)
    }

    @Test func belowCoverageStaysOpen() {
        var (book, _, _) = book()
        #expect(book.applyActuals([run(21, 7_900)], calendar: calendar) == 0)
        #expect(book.applyActuals([run(21, 7_900)], calendar: calendar, coverage: 0.75) == 1)
    }

    @Test func manualUncheckIsRespected() {
        var (book, planID, weekID) = book()
        let activities = [run(21, 10_000)]
        book.applyActuals(activities, calendar: calendar)
        book.toggleDay(0, week: weekID, in: planID)
        #expect(book.activePlan!.weeks[0].done[0] == false)
        #expect(book.applyActuals(activities, calendar: calendar) == 0)
        book.toggleDay(0, week: weekID, in: planID)
        #expect(book.activePlan!.weeks[0].done[0])
        #expect(book.activePlan!.weeks[0].dismissed[0] == false)
    }

    @Test func undatedPlansAreSkippedAndOldDataDecodes() throws {
        var week = PlanWeek()
        week.days[0] = [PlannedWorkout(discipline: .run, distance: 5_000)]
        var book = PlanBook(plans: [TrainingPlan(name: "Free", weeks: [week])])
        #expect(book.applyActuals([run(21, 6_000)], calendar: calendar) == 0)

        let legacy = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","days":[[],[],[],[],[],[],[]],"done":[true,false,false,false,false,false,false]}"#
        let decoded = try JSONDecoder().decode(PlanWeek.self, from: Data(legacy.utf8))
        #expect(decoded.dismissed == Array(repeating: false, count: 7))
        #expect(decoded.done[0])
    }
}
