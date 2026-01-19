import Foundation
import Vision
import PDFKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct OCRParser {
    func performOCR(on document: PDFDocument) async throws -> String {
        var fullText = ""

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            let pageImage = try renderPageToImage(page)
            let pageText = try await recognizeText(in: pageImage)

            if !pageText.isEmpty {
                fullText += pageText + "\n\n"
            }
        }

        return fullText
    }

    func performOCR(on imageData: Data) async throws -> String {
        #if os(macOS)
        guard let nsImage = NSImage(data: imageData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DocumentParserError.parsingFailed("Could not create image from data")
        }
        #else
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            throw DocumentParserError.parsingFailed("Could not create image from data")
        }
        #endif

        return try await recognizeText(in: cgImage)
    }

    private func renderPageToImage(_ page: PDFPage) throws -> CGImage {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0 // Higher resolution for better OCR
        let scaledSize = CGSize(
            width: pageRect.width * scale,
            height: pageRect.height * scale
        )

        #if os(macOS)
        let image = NSImage(size: scaledSize)
        image.lockFocus()
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            throw DocumentParserError.parsingFailed("Could not create graphics context")
        }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: scaledSize))
        context.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: context)
        image.unlockFocus()

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw DocumentParserError.parsingFailed("Could not convert NSImage to CGImage")
        }
        return cgImage
        #else
        let renderer = UIGraphicsImageRenderer(size: scaledSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: scaledSize))
            context.cgContext.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        guard let cgImage = image.cgImage else {
            throw DocumentParserError.parsingFailed("Could not convert UIImage to CGImage")
        }
        return cgImage
        #endif
    }

    private func recognizeText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: DocumentParserError.parsingFailed("OCR failed: \(error.localizedDescription)"))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: " ")

                continuation.resume(returning: text)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en-US"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: image, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: DocumentParserError.parsingFailed("OCR request failed: \(error.localizedDescription)"))
            }
        }
    }
}
