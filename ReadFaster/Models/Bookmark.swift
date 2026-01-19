import Foundation
import SwiftData

@Model
final class Bookmark {
    var id: UUID
    var wordIndex: Int
    var note: String?
    var highlightedText: String?
    var dateCreated: Date

    var book: Book?

    init(
        id: UUID = UUID(),
        wordIndex: Int,
        note: String? = nil,
        highlightedText: String? = nil
    ) {
        self.id = id
        self.wordIndex = wordIndex
        self.note = note
        self.highlightedText = highlightedText
        self.dateCreated = Date()
    }
}
