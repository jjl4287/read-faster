import Foundation

struct TextProcessor {
    /// Cleans and normalizes text for RSVP display
    static func process(_ text: String) -> [String] {
        // Normalize whitespace and line breaks
        var cleaned = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        // Replace multiple spaces with single space
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }

        // Replace multiple newlines with double newline (paragraph break)
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }

        // Split into words, preserving punctuation attached to words
        let words = cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .flatMap { splitLongHyphenatedWords($0) }

        return words
    }

    /// Splits very long hyphenated words for better readability
    private static func splitLongHyphenatedWords(_ word: String) -> [String] {
        // Only split if the word is very long and contains hyphens
        guard word.count > 15, word.contains("-") else {
            return [word]
        }

        let parts = word.components(separatedBy: "-")

        // Only split if it makes sense (multiple meaningful parts)
        guard parts.count > 1, parts.allSatisfy({ $0.count >= 2 }) else {
            return [word]
        }

        // Rejoin with hyphens to indicate continuation
        return parts.enumerated().map { index, part in
            if index < parts.count - 1 {
                return part + "-"
            }
            return part
        }
    }

    /// Estimates reading time at a given WPM
    static func estimatedReadingTime(wordCount: Int, wpm: Int) -> TimeInterval {
        guard wpm > 0 else { return 0 }
        return Double(wordCount) / Double(wpm) * 60.0
    }

    /// Formats a time interval as a human-readable string
    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) / 60 % 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }

    /// Formats word count with thousands separator
    static func formatWordCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}
