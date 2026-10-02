import Testing
@testable import TrainingKit

struct SportProfileTests {
    @Test func triathlonCoversAllThreeDisciplines() {
        let profile = SportProfile.triathlon
        #expect(profile.disciplines == [.swim, .bike, .run])
        #expect(profile.single == nil)
        #expect(profile.adherenceTracks == [.general, .swim, .bike, .run])
    }

    @Test func singleSportHasOneDisciplineAndGeneralTrack() {
        let profile = SportProfile(sports: [.run])
        #expect(profile.disciplines == [.run])
        #expect(profile.single == .run)
        #expect(profile.adherenceTracks == [.general])
    }

    @Test func disciplinesKeepTriathlonOrder() {
        let profile = SportProfile(sports: [.run, .bike])
        #expect(profile.disciplines == [.bike, .run])
        #expect(profile.adherenceTracks == [.general, .bike, .run])
    }

    @Test func rawValueRoundTrips() {
        let profile = SportProfile(sports: [.swim, .run])
        #expect(profile.rawValue == "run,swim")
        #expect(SportProfile(rawValue: profile.rawValue) == profile)
        #expect(SportProfile(rawValue: "") == nil)
        #expect(SportProfile(rawValue: "unknown") == nil)
        #expect(SportProfile(sports: []) == .triathlon)
    }

    @Test func lastSportCannotBeRemoved() {
        var profile = SportProfile(sports: [.run])
        profile.toggle(.run)
        #expect(profile.sports == [.run])
        profile.toggle(.bike)
        profile.toggle(.run)
        #expect(profile.sports == [.bike])
    }

    @Test func triathlonLocksSingleSports() {
        var profile = SportProfile(sports: [.run])
        profile.toggle(.triathlon)
        #expect(profile.isTriathlon)
        #expect(profile.isIncludedInTriathlon(.bike))
        profile.toggle(.bike)
        #expect(profile.sports == [.run, .triathlon])
        profile.toggle(.triathlon)
        #expect(profile.sports == [.run])
    }

    @Test func emptyProfileForFirstChoice() {
        var profile = SportProfile.empty
        #expect(profile.isEmpty)
        #expect(profile.disciplines.isEmpty)
        profile.toggle(.run, allowsEmpty: true)
        #expect(profile.sports == [.run])
        profile.toggle(.run, allowsEmpty: true)
        #expect(profile.isEmpty)
        profile.toggle(.triathlon, allowsEmpty: true)
        profile.toggle(.triathlon, allowsEmpty: true)
        #expect(profile.isEmpty)
    }

    @Test func leavingTriathlonKeepsAllThreeWhenNothingElseWasChosen() {
        var profile = SportProfile.triathlon
        profile.toggle(.triathlon)
        #expect(profile.sports == [.swim, .bike, .run])
        #expect(profile.disciplines == [.swim, .bike, .run])
    }
}
