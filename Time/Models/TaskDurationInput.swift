import Foundation

enum TaskDurationInput {
    static func parse(_ input: String) -> TimeInterval? {
        let allowedCharacters = CharacterSet.decimalDigits.union(CharacterSet(charactersIn: ":"))
        guard input.rangeOfCharacter(from: allowedCharacters.inverted) == nil else {
            return nil
        }

        let parts = input.split(separator: ":", omittingEmptySubsequences: false)
        guard !parts.isEmpty, parts.count <= 3 else {
            return nil
        }

        var values: [Int] = []
        for part in parts {
            guard !part.isEmpty, let value = Int(part), value >= 0 else {
                return nil
            }
            values.append(value)
        }

        switch values.count {
        case 1:
            return TimeInterval(values[0] * 60)
        case 2:
            return TimeInterval(values[0] * 3600 + values[1] * 60)
        case 3:
            return TimeInterval(values[0] * 3600 + values[1] * 60 + values[2])
        default:
            return nil
        }
    }

    static func format(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(max(0, duration))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d:%02d", hours, minutes, seconds)
    }
}
