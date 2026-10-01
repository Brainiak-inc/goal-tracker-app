import Foundation
import Testing
@testable import TrainingKit

struct GarminCSVTests {
    static let utc = TimeZone(identifier: "UTC")!

    struct WebImport: Decodable {
        let skipped: Int
        let activities: [WebActivity]
    }

    static func decode(_ data: Data) throws -> WebImport {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            return try Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(text)
        }
        return try decoder.decode(WebImport.self, from: data)
    }

    static func fixture(_ name: String, _ ext: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    static func expectSame(_ result: GarminImport, _ web: WebImport) {
        #expect(result.skipped == web.skipped)
        #expect(result.activities.count == web.activities.count)
        for (actual, expected) in zip(result.activities, web.activities.map(\.activity)) {
            #expect(actual.start == expected.start)
            #expect(actual.discipline == expected.discipline)
            #expect(actual.sourceType == expected.sourceType)
            #expect(actual.title == expected.title)
            #expect(close(actual.duration, expected.duration))
            #expect(close(actual.distance, expected.distance))
            #expect(actual.averageHeartRate == expected.averageHeartRate)
            #expect(actual.maxHeartRate == expected.maxHeartRate)
            #expect(actual.calories == expected.calories)
        }
    }

    @Test func sampleMatchesWebParser() throws {
        let text = try #require(String(data: try Self.fixture("garmin-sample", "csv"), encoding: .utf8))
        let web = try Self.decode(try Self.fixture("garmin-sample-expected", "json"))
        Self.expectSame(GarminCSV.parse(text, timeZone: Self.utc), web)
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["GARMIN_CSV"] != nil))
    func localExportMatchesWebParser() throws {
        let environment = ProcessInfo.processInfo.environment
        let text = try String(contentsOfFile: try #require(environment["GARMIN_CSV"]), encoding: .utf8)
        let expected = try Data(contentsOf: URL(fileURLWithPath: try #require(environment["GARMIN_CSV_EXPECTED"])))
        Self.expectSame(GarminCSV.parse(text, timeZone: Self.utc), try Self.decode(expected))
    }

    @Test func quotedFieldsAndLineEndings() {
        let rows = GarminCSV.rows(in: "\u{FEFF}a,b\r\n\"x, y\",\"say \"\"hi\"\"\"\r\n\r\nlast,row")
        #expect(rows == [["a", "b"], ["x, y", "say \"hi\""], ["last", "row"]])
    }

    @Test(arguments: [
        ("01:02:03", 3723.0),
        ("45:12", 2712.0),
        ("42", 42.0),
        ("2:31:07.6", 9067.6)
    ])
    func durations(_ raw: String, _ seconds: Double) {
        #expect(GarminCSV.duration(raw) == seconds)
    }

    @Test func emptyValues() {
        #expect(GarminCSV.number("--") == nil)
        #expect(GarminCSV.number("") == nil)
        #expect(GarminCSV.number("9,950") == 9950)
        #expect(GarminCSV.duration("--") == nil)
        #expect(GarminCSV.duration("1:2:3:4") == nil)
        #expect(GarminCSV.parse("").activities.isEmpty)
    }
}

struct ActivityMergeTests {
    func activity(_ minute: Int, _ type: String = "Running", discipline: Discipline = .run, distance: Double = 5_000) -> Activity {
        Activity(
            start: Date(timeIntervalSince1970: 1_790_000_000 + Double(minute) * 60),
            discipline: discipline,
            sourceType: type,
            title: type,
            duration: 1800,
            distance: distance
        )
    }

    @Test func reimportUpdatesValuesButKeepsDisciplineOverride() {
        var edited = activity(0)
        edited.discipline = .other
        let result = ActivityMerge.merge([edited, activity(10)], with: [activity(0, distance: 6_000), activity(20)])
        #expect(result.added == 1)
        #expect(result.updated == 1)
        #expect(result.activities.count == 3)
        #expect(result.activities[0].distance == 6_000)
        #expect(result.activities[0].discipline == .other)
        #expect(result.activities.map(\.start) == result.activities.map(\.start).sorted())
    }

    @Test func deletedActivitiesStayDeleted() {
        let removed = activity(5)
        let result = ActivityMerge.merge([], with: [removed, activity(6)], excluding: [removed.identity])
        #expect(result.activities.map(\.identity) == [activity(6).identity])
        #expect(result.added == 1)
    }
}
