import Foundation

/// A calendar day ("2026-11-14") independent of time of day and time zone.
/// Created from the player's local calendar; arithmetic is done in UTC.
public struct DayKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    public init?(string: String) {
        let parts = string.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
    }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    public var date: Date {
        Self.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    public func adding(days: Int) -> DayKey {
        DayKey(date: Self.utc.date(byAdding: .day, value: days, to: date)!, calendar: Self.utc)
    }

    public func days(until other: DayKey) -> Int {
        Self.utc.dateComponents([.day], from: date, to: other.date).day ?? 0
    }

    public var daysInMonth: Int {
        Self.utc.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    /// 1 = Monday … 7 = Sunday (ISO), for laying out the calendar grid.
    public var isoWeekday: Int {
        let weekday = Self.utc.component(.weekday, from: date) // 1 = Sunday
        return weekday == 1 ? 7 : weekday - 1
    }

    public var firstOfMonth: DayKey { DayKey(year: year, month: month, day: 1) }
    public var monthKey: String { String(format: "%04d-%02d", year, month) }

    public static func < (lhs: DayKey, rhs: DayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public init(from decoder: Decoder) throws {
        let string = try decoder.singleValueContainer().decode(String.self)
        guard let key = DayKey(string: string) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad day \(string)"))
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
