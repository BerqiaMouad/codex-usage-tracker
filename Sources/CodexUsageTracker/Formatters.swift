import Foundation

enum Formatters {
    static func compactTokenCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1

        let number = Double(value)
        switch number {
        case 1_000_000_000...:
            return "\(trimmed(number / 1_000_000_000))B"
        case 1_000_000...:
            return "\(trimmed(number / 1_000_000))M"
        case 1_000...:
            return "\(trimmed(number / 1_000))K"
        default:
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
    }

    static func fullTokenCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = value < 1 ? 3 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }

    static func relativeDate(_ date: Date) -> String {
        date.formatted(.relative(presentation: .named))
    }

    static func absoluteDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func trimmed(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
