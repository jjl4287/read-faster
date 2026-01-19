import Foundation

struct TextParser: DocumentParser {
    static let supportedExtensions = ["txt", "text", "md"]

    func parse(url: URL) async throws -> ParsedDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentParserError.fileNotFound
        }

        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            // Try other encodings
            if let data = FileManager.default.contents(atPath: url.path),
               let latin1 = String(data: data, encoding: .isoLatin1) {
                content = latin1
            } else {
                throw DocumentParserError.parsingFailed("Could not read text file with any supported encoding.")
            }
        }

        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DocumentParserError.emptyContent
        }

        let title = url.deletingPathExtension().lastPathComponent

        return ParsedDocument(
            title: title,
            author: nil,
            content: trimmed,
            coverImage: nil
        )
    }
}
