import Foundation
import PDFKit

struct PDFParser: DocumentParser {
    static let supportedExtensions = ["pdf"]

    func parse(url: URL) async throws -> ParsedDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentParserError.fileNotFound
        }

        guard let pdfDocument = PDFDocument(url: url) else {
            throw DocumentParserError.parsingFailed("Could not open PDF document.")
        }

        // Try text extraction first
        var fullText = ""
        var hasExtractableText = false

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fullText += pageText + "\n\n"
                hasExtractableText = true
            }
        }

        // If no extractable text, this might be a scanned PDF
        if !hasExtractableText {
            // Attempt OCR
            fullText = try await performOCR(on: pdfDocument)
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // Extract title from PDF metadata or filename
        let title = pdfDocument.documentAttributes?[PDFDocumentAttribute.titleAttribute] as? String
            ?? url.deletingPathExtension().lastPathComponent

        let author = pdfDocument.documentAttributes?[PDFDocumentAttribute.authorAttribute] as? String

        // Try to get cover image from first page
        let coverImage = extractCoverImage(from: pdfDocument)

        return ParsedDocument(
            title: title,
            author: author,
            content: trimmed,
            coverImage: coverImage
        )
    }

    private func performOCR(on document: PDFDocument) async throws -> String {
        return try await OCRParser().performOCR(on: document)
    }

    private func extractCoverImage(from document: PDFDocument) -> Data? {
        guard let firstPage = document.page(at: 0) else { return nil }

        let pageRect = firstPage.bounds(for: .mediaBox)
        let scale: CGFloat = 0.5
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        #if os(macOS)
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        if let context = NSGraphicsContext.current?.cgContext {
            context.setFillColor(NSColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: scaledSize))
            context.scaleBy(x: scale, y: scale)
            firstPage.draw(with: .mediaBox, to: context)
        }
        image.unlockFocus()
        return image.tiffRepresentation
        #else
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            context.cgContext.scaleBy(x: scale, y: scale)
            firstPage.draw(with: .mediaBox, to: context.cgContext)
        }
        return image.pngData()
        #endif
    }
}
