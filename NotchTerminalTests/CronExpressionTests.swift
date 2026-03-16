import XCTest
@testable import NotchTerminal

final class CronExpressionTests: XCTestCase {
    func testMatchesDayOfWeekExpression() throws {
        let cron = try CronExpression("30 9 * * 1")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let matchingDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 16, hour: 9, minute: 30))!
        let nonMatchingDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 17, hour: 9, minute: 30))!

        XCTAssertTrue(cron.matches(matchingDate, calendar: calendar))
        XCTAssertFalse(cron.matches(nonMatchingDate, calendar: calendar))
    }

    func testMatchesDayOfMonthExpression() throws {
        let cron = try CronExpression("0 8 15 * *")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let matchingDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 8, minute: 0))!
        let nonMatchingDate = calendar.date(from: DateComponents(year: 2026, month: 4, day: 16, hour: 8, minute: 0))!

        XCTAssertTrue(cron.matches(matchingDate, calendar: calendar))
        XCTAssertFalse(cron.matches(nonMatchingDate, calendar: calendar))
    }

    func testMatchesCronSemanticsWhenDayOfMonthAndDayOfWeekAreBothRestricted() throws {
        let cron = try CronExpression("0 10 15 * 1")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let mondayMatch = calendar.date(from: DateComponents(year: 2026, month: 3, day: 16, hour: 10, minute: 0))!
        let fifteenthMatch = calendar.date(from: DateComponents(year: 2026, month: 4, day: 15, hour: 10, minute: 0))!
        let noMatch = calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 10, minute: 0))!

        XCTAssertTrue(cron.matches(mondayMatch, calendar: calendar))
        XCTAssertTrue(cron.matches(fifteenthMatch, calendar: calendar))
        XCTAssertFalse(cron.matches(noMatch, calendar: calendar))
    }

    func testLaunchdScheduleUsesRuntimeDayMatchingWhenCronNeedsOrSemantics() throws {
        let cron = try CronExpression("0 10 15 * 1")
        let schedule = cron.makeLaunchdSchedule()

        XCTAssertTrue(schedule.requiresRuntimeDayMatching)
        XCTAssertEqual(schedule.intervals, [["Hour": 10, "Minute": 0]])
    }

    func testLaunchdScheduleEncodesWeekdayWhenOnlyDayOfWeekIsRestricted() throws {
        let cron = try CronExpression("15 6 * * 1,3")
        let schedule = cron.makeLaunchdSchedule()

        XCTAssertFalse(schedule.requiresRuntimeDayMatching)
        XCTAssertEqual(
            schedule.intervals,
            [
                ["Hour": 6, "Minute": 15, "Weekday": 1],
                ["Hour": 6, "Minute": 15, "Weekday": 3],
            ]
        )
    }

    func testInvalidFieldCountThrows() {
        XCTAssertThrowsError(try CronExpression("0 0 * *")) { error in
            XCTAssertEqual(error as? CronExpressionError, .invalidFieldCount)
        }
    }
}
