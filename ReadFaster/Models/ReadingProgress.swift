import Foundation
import SwiftData

@Model
final class ReadingProgress {
    var id: UUID
    var currentWordIndex: Int
    var totalReadingTime: TimeInterval
    var sessionsCount: Int
    var wordsRead: Int
    var lastUpdated: Date

    var book: Book?

    init(
        id: UUID = UUID(),
        currentWordIndex: Int = 0,
        totalReadingTime: TimeInterval = 0,
        sessionsCount: Int = 0,
        wordsRead: Int = 0
    ) {
        self.id = id
        self.currentWordIndex = currentWordIndex
        self.totalReadingTime = totalReadingTime
        self.sessionsCount = sessionsCount
        self.wordsRead = wordsRead
        self.lastUpdated = Date()
    }

    var averageWPM: Int {
        guard totalReadingTime > 0 else { return 0 }
        return Int(Double(wordsRead) / (totalReadingTime / 60.0))
    }

    func updateProgress(wordIndex: Int, sessionTime: TimeInterval, wordsInSession: Int) {
        self.currentWordIndex = wordIndex
        self.totalReadingTime += sessionTime
        self.wordsRead += wordsInSession
        self.lastUpdated = Date()
    }

    func startNewSession() {
        self.sessionsCount += 1
        self.lastUpdated = Date()
    }
}
