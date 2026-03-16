import Foundation

enum AIScheduleFormatter {
    static func appTimer(_ interval: Double) -> String {
        if interval.truncatingRemainder(dividingBy: 3600) == 0 {
            let hours = Int(interval / 3600)
            return hours == 1 ? "Every hour while the app is open" : "Every \(hours) hours while the app is open"
        }

        let minutes = Int(interval / 60)
        return minutes == 1 ? "Every minute while the app is open" : "Every \(minutes) minutes while the app is open"
    }

    static func cron(_ cron: String) -> String {
        let parts = cron.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count == 5 else { return "Cron \(cron)" }

        let minute = parts[0]
        let hour = parts[1]
        let day = parts[2]
        let month = parts[3]
        let weekday = parts[4]

        guard month == "*" else { return "Cron \(cron)" }

        if minute == "*", hour == "*", day == "*", weekday == "*" {
            return "Every minute"
        }

        if minute.hasPrefix("*/"), hour == "*", day == "*", weekday == "*", let everyMinute = Int(minute.dropFirst(2)) {
            return everyMinute == 1 ? "Every minute" : "Every \(everyMinute) minutes"
        }

        if let minuteValue = Int(minute), hour.hasPrefix("*/"), day == "*", weekday == "*", let everyHour = Int(hour.dropFirst(2)) {
            let time = String(format: ":%02d", minuteValue)
            return everyHour == 1 ? "Every hour at \(time)" : "Every \(everyHour) hours at \(time)"
        }

        if hour == "*", day == "*", weekday == "*", let minuteValue = Int(minute) {
            return "Every hour at :\(String(format: "%02d", minuteValue))"
        }

        if day == "*", weekday == "*", hour.contains(","), let minuteValue = Int(minute) {
            let times = hour
                .split(separator: ",")
                .compactMap { Int($0) }
                .map { "\(String(format: "%02d", $0)):\(String(format: "%02d", minuteValue))" }
                .joined(separator: " & ")
            return "2 times a day · \(times)"
        }

        if day == "*", weekday == "*", let minuteValue = Int(minute), let hourValue = Int(hour) {
            return "Daily at \(String(format: "%02d", hourValue)):\(String(format: "%02d", minuteValue))"
        }

        if day == "*", weekday == "1,2,3,4,5", let minuteValue = Int(minute), let hourValue = Int(hour) {
            return "Weekdays at \(String(format: "%02d", hourValue)):\(String(format: "%02d", minuteValue))"
        }

        if day == "*", let minuteValue = Int(minute), let hourValue = Int(hour) {
            let weekdayLabels = weekday
                .split(separator: ",")
                .compactMap { Int($0) }
                .map {
                    switch $0 {
                    case 1: return "Mon"
                    case 2: return "Tue"
                    case 3: return "Wed"
                    case 4: return "Thu"
                    case 5: return "Fri"
                    case 6: return "Sat"
                    case 0, 7: return "Sun"
                    default: return "\($0)"
                    }
                }
                .joined(separator: ", ")
            if !weekdayLabels.isEmpty {
                return "\(weekdayLabels) at \(String(format: "%02d", hourValue)):\(String(format: "%02d", minuteValue))"
            }
        }

        if weekday == "*", let minuteValue = Int(minute), let hourValue = Int(hour) {
            return "Days \(day) at \(String(format: "%02d", hourValue)):\(String(format: "%02d", minuteValue))"
        }

        return "Cron \(cron)"
    }
}
