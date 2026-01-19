import Foundation

struct ORPCalculator {
    /// Calculates the Optimal Recognition Point (ORP) index for a word.
    /// The ORP is the character position where the eye naturally fixates,
    /// typically around 25-35% into the word depending on length.
    static func calculate(for word: String) -> Int {
        let length = word.count

        guard length > 0 else { return 0 }

        // For very short words, fixate near the beginning
        // For longer words, fixate around 30% in
        switch length {
        case 1:
            return 0
        case 2:
            return 0
        case 3:
            return 1
        case 4:
            return 1
        case 5:
            return 1
        case 6:
            return 2
        case 7:
            return 2
        case 8:
            return 2
        case 9:
            return 3
        case 10:
            return 3
        case 11:
            return 3
        case 12:
            return 4
        case 13:
            return 4
        default:
            // For very long words, cap at position 4-5
            return min(4, Int(Double(length) * 0.3))
        }
    }

    /// Splits a word into three parts: before ORP, the ORP character, and after ORP.
    static func split(word: String) -> (before: String, orp: Character?, after: String) {
        guard !word.isEmpty else {
            return ("", nil, "")
        }

        let orpIndex = calculate(for: word)
        let characters = Array(word)

        guard orpIndex < characters.count else {
            return (word, nil, "")
        }

        let before = String(characters.prefix(orpIndex))
        let orp = characters[orpIndex]
        let after = String(characters.suffix(from: orpIndex + 1))

        return (before, orp, after)
    }
}

// MARK: - Word Display Model
struct ORPWord {
    let before: String
    let focal: Character?
    let after: String
    let fullWord: String

    init(word: String) {
        self.fullWord = word
        let parts = ORPCalculator.split(word: word)
        self.before = parts.before
        self.focal = parts.orp
        self.after = parts.after
    }

    /// The number of characters before the focal point (for alignment)
    var leadingCount: Int {
        before.count
    }

    /// The total character count
    var totalCount: Int {
        fullWord.count
    }
}
