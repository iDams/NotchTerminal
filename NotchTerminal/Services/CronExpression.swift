import Foundation

enum CronExpressionError: LocalizedError, Equatable {
    case invalidFieldCount
    case invalidToken(String)
    case valueOutOfRange(field: String, value: Int)

    var errorDescription: String? {
        switch self {
        case .invalidFieldCount:
            return "Cron expression must contain exactly 5 fields."
        case .invalidToken(let token):
            return "Unsupported cron token: \(token)"
        case .valueOutOfRange(let field, let value):
            return "Value \(value) is out of range for \(field)."
        }
    }
}

struct CronExpression: Equatable {
    struct LaunchdSchedule: Equatable {
        let intervals: [[String: Int]]
        let requiresRuntimeDayMatching: Bool
    }

    private struct Field: Equatable {
        let range: ClosedRange<Int>
        let name: String
        let values: Set<Int>?

        var isWildcard: Bool { values == nil }

        func contains(_ value: Int) -> Bool {
            guard let values else { return true }
            return values.contains(value)
        }
    }

    private let minute: Field
    private let hour: Field
    private let dayOfMonth: Field
    private let month: Field
    private let dayOfWeek: Field

    init(_ rawValue: String) throws {
        let parts = rawValue
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)

        guard parts.count == 5 else {
            throw CronExpressionError.invalidFieldCount
        }

        minute = try Self.parseField(parts[0], name: "minute", range: 0...59)
        hour = try Self.parseField(parts[1], name: "hour", range: 0...23)
        dayOfMonth = try Self.parseField(parts[2], name: "day-of-month", range: 1...31)
        month = try Self.parseField(parts[3], name: "month", range: 1...12)
        dayOfWeek = try Self.parseDayOfWeekField(parts[4])
    }

    func matches(_ date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: date)
        guard let minuteValue = components.minute,
              let hourValue = components.hour,
              let dayValue = components.day,
              let monthValue = components.month,
              let weekdayValue = components.weekday else {
            return false
        }

        guard minute.contains(minuteValue),
              hour.contains(hourValue),
              month.contains(monthValue) else {
            return false
        }

        let cronWeekday = (weekdayValue + 6) % 7
        let matchesDayOfMonth = dayOfMonth.contains(dayValue)
        let matchesDayOfWeek = dayOfWeek.contains(cronWeekday)

        if dayOfMonth.isWildcard && dayOfWeek.isWildcard {
            return true
        }

        if dayOfMonth.isWildcard {
            return matchesDayOfWeek
        }

        if dayOfWeek.isWildcard {
            return matchesDayOfMonth
        }

        return matchesDayOfMonth || matchesDayOfWeek
    }

    func makeLaunchdSchedule() -> LaunchdSchedule {
        let minuteValues = Self.expandedValues(for: minute)
        let hourValues = Self.expandedValues(for: hour)
        let monthValues = Self.expandedValues(for: month)

        let canEncodeDayOfMonth = !dayOfMonth.isWildcard && dayOfWeek.isWildcard
        let canEncodeDayOfWeek = dayOfMonth.isWildcard && !dayOfWeek.isWildcard
        let requiresRuntimeDayMatching = !dayOfMonth.isWildcard && !dayOfWeek.isWildcard

        let dayValues = canEncodeDayOfMonth ? Self.expandedValues(for: dayOfMonth) : [nil]
        let weekdayValues = canEncodeDayOfWeek ? Self.expandedValues(for: dayOfWeek) : [nil]

        var intervals: [[String: Int]] = []

        for monthValue in monthValues {
            for dayValue in dayValues {
                for weekdayValue in weekdayValues {
                    for hourValue in hourValues {
                        for minuteValue in minuteValues {
                            var interval: [String: Int] = [:]
                            if let monthValue { interval["Month"] = monthValue }
                            if let dayValue { interval["Day"] = dayValue }
                            if let weekdayValue { interval["Weekday"] = Self.launchdWeekday(fromCronWeekday: weekdayValue) }
                            if let hourValue { interval["Hour"] = hourValue }
                            if let minuteValue { interval["Minute"] = minuteValue }
                            intervals.append(interval)
                        }
                    }
                }
            }
        }

        return LaunchdSchedule(
            intervals: intervals.isEmpty ? [[:]] : intervals,
            requiresRuntimeDayMatching: requiresRuntimeDayMatching
        )
    }

    private static func expandedValues(for field: Field) -> [Int?] {
        guard let values = field.values else { return [nil] }
        return values.sorted().map(Optional.some)
    }

    private static func launchdWeekday(fromCronWeekday value: Int) -> Int {
        value == 0 ? 7 : value
    }

    private static func parseDayOfWeekField(_ token: String) throws -> Field {
        let field = try parseField(token, name: "day-of-week", range: 0...7)
        guard let values = field.values else {
            return Field(range: 0...6, name: field.name, values: nil)
        }

        let normalized = Set(values.map { $0 == 7 ? 0 : $0 })
        return Field(range: 0...6, name: field.name, values: normalized)
    }

    private static func parseField(_ token: String, name: String, range: ClosedRange<Int>) throws -> Field {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "*" {
            return Field(range: range, name: name, values: nil)
        }

        var values = Set<Int>()

        for part in trimmed.split(separator: ",").map(String.init) {
            guard !part.isEmpty else {
                throw CronExpressionError.invalidToken(token)
            }

            let stepParts = part.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
            guard stepParts.count <= 2 else {
                throw CronExpressionError.invalidToken(part)
            }

            let base = stepParts[0]
            let step: Int
            if stepParts.count == 2 {
                guard let parsedStep = Int(stepParts[1]), parsedStep > 0 else {
                    throw CronExpressionError.invalidToken(part)
                }
                step = parsedStep
            } else {
                step = 1
            }

            let candidates: [Int]
            if base == "*" {
                candidates = Array(range)
            } else if base.contains("-") {
                let bounds = base.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
                guard bounds.count == 2,
                      let lower = Int(bounds[0]),
                      let upper = Int(bounds[1]) else {
                    throw CronExpressionError.invalidToken(part)
                }
                try validate(lower, in: range, field: name)
                try validate(upper, in: range, field: name)
                guard lower <= upper else {
                    throw CronExpressionError.invalidToken(part)
                }
                candidates = Array(lower...upper)
            } else if let value = Int(base) {
                try validate(value, in: range, field: name)
                candidates = [value]
            } else {
                throw CronExpressionError.invalidToken(part)
            }

            for (index, value) in candidates.enumerated() where index.isMultiple(of: step) {
                values.insert(value)
            }
        }

        return Field(range: range, name: name, values: values)
    }

    private static func validate(_ value: Int, in range: ClosedRange<Int>, field: String) throws {
        guard range.contains(value) else {
            throw CronExpressionError.valueOutOfRange(field: field, value: value)
        }
    }
}
