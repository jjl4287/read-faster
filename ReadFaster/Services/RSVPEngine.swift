import Foundation
import Combine

@MainActor
final class RSVPEngine: ObservableObject {
    // MARK: - Published State
    @Published private(set) var currentWord: String = ""
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isPlaying: Bool = false
    @Published var wordsPerMinute: Int = 300 {
        didSet {
            wordsPerMinute = min(max(wordsPerMinute, Self.minWPM), Self.maxWPM)
        }
    }

    // MARK: - Configuration
    static let minWPM = 200
    static let maxWPM = 1000
    @Published var pauseOnPunctuation: Bool = true

    // MARK: - Private State
    private var words: [String] = []
    private var timer: Timer?
    private var sessionStartTime: Date?
    private var wordsReadInSession: Int = 0

    // MARK: - Callbacks
    var onProgressUpdate: ((Int, TimeInterval, Int) -> Void)?

    // MARK: - Computed Properties
    var totalWords: Int { words.count }

    var progress: Double {
        guard totalWords > 0 else { return 0 }
        return Double(currentIndex) / Double(totalWords)
    }

    var hasContent: Bool { !words.isEmpty }
    var isAtEnd: Bool { currentIndex >= totalWords }
    var isAtStart: Bool { currentIndex == 0 }

    private var baseInterval: TimeInterval {
        60.0 / Double(wordsPerMinute)
    }

    // MARK: - Public Methods
    func load(content: String) {
        words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        currentIndex = 0
        currentWord = words.first ?? ""
        isPlaying = false
    }

    func load(words: [String]) {
        self.words = words
        currentIndex = 0
        currentWord = words.first ?? ""
        isPlaying = false
    }

    func play() {
        guard hasContent, !isAtEnd else { return }
        isPlaying = true
        sessionStartTime = Date()
        wordsReadInSession = 0
        scheduleNextWord()
    }

    func pause() {
        isPlaying = false
        timer?.invalidate()
        timer = nil
        saveProgress()
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func seek(to index: Int) {
        let clampedIndex = min(max(index, 0), totalWords - 1)
        currentIndex = clampedIndex
        currentWord = words[safe: clampedIndex] ?? ""

        if isPlaying {
            timer?.invalidate()
            scheduleNextWord()
        }
    }

    func seekToProgress(_ progress: Double) {
        let index = Int(progress * Double(totalWords))
        seek(to: index)
    }

    func skipForward(words count: Int = 10) {
        seek(to: currentIndex + count)
    }

    func skipBackward(words count: Int = 10) {
        seek(to: currentIndex - count)
    }

    func nextSentence() {
        guard currentIndex < totalWords else { return }

        var index = currentIndex + 1
        while index < totalWords {
            let word = words[index - 1]
            if word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!") {
                break
            }
            index += 1
        }
        seek(to: min(index, totalWords - 1))
    }

    func previousSentence() {
        guard currentIndex > 0 else { return }

        var index = currentIndex - 1
        // Skip to start of current sentence
        while index > 0 {
            let word = words[index - 1]
            if word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!") {
                break
            }
            index -= 1
        }

        // If we're at the start of current sentence, go to previous
        if index == currentIndex - 1 || index <= 1 {
            index = max(currentIndex - 2, 0)
            while index > 0 {
                let word = words[index - 1]
                if word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!") {
                    break
                }
                index -= 1
            }
        }

        seek(to: index)
    }

    func restart() {
        seek(to: 0)
    }

    // MARK: - Private Methods
    private func scheduleNextWord() {
        guard isPlaying, currentIndex < totalWords else {
            if isAtEnd {
                pause()
            }
            return
        }

        let interval = intervalForCurrentWord()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.advanceToNextWord()
            }
        }
    }

    private func advanceToNextWord() {
        currentIndex += 1
        wordsReadInSession += 1

        if currentIndex < totalWords {
            currentWord = words[currentIndex]
            scheduleNextWord()
        } else {
            currentWord = ""
            pause()
        }
    }

    private func intervalForCurrentWord() -> TimeInterval {
        guard pauseOnPunctuation else { return baseInterval }

        let word = currentWord

        // Longer pause at sentence endings
        if word.hasSuffix(".") || word.hasSuffix("?") || word.hasSuffix("!") {
            return baseInterval * 2.0
        }

        // Medium pause at clause breaks
        if word.hasSuffix(",") || word.hasSuffix(";") || word.hasSuffix(":") {
            return baseInterval * 1.5
        }

        // Slightly longer for long words
        if word.count > 10 {
            return baseInterval * 1.2
        }

        return baseInterval
    }

    private func saveProgress() {
        guard let startTime = sessionStartTime else { return }
        let sessionDuration = Date().timeIntervalSince(startTime)
        onProgressUpdate?(currentIndex, sessionDuration, wordsReadInSession)
        sessionStartTime = nil
        wordsReadInSession = 0
    }
}

// MARK: - Array Extension
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
