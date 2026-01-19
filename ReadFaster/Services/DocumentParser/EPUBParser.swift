import Foundation
import ZIPFoundation
import SwiftSoup

struct EPUBParser: DocumentParser {
    static let supportedExtensions = ["epub"]

    func parse(url: URL) async throws -> ParsedDocument {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DocumentParserError.fileNotFound
        }

        let archive: Archive
        do {
            archive = try Archive(url: url, accessMode: .read)
        } catch {
            throw DocumentParserError.parsingFailed("Could not open EPUB archive: \(error.localizedDescription)")
        }

        // 1. Find the root file path from container.xml
        let rootFilePath = try findRootFile(in: archive)

        // 2. Parse the OPF file to get metadata and spine
        let (metadata, spine, basePath) = try parseOPF(archive: archive, opfPath: rootFilePath)

        // 3. Extract text content in spine order
        let content = try extractContent(archive: archive, spine: spine, basePath: basePath)

        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw DocumentParserError.emptyContent
        }

        // 4. Try to extract cover image
        let coverImage = try? extractCover(archive: archive, metadata: metadata, basePath: basePath)

        return ParsedDocument(
            title: metadata.title ?? url.deletingPathExtension().lastPathComponent,
            author: metadata.author,
            content: content,
            coverImage: coverImage
        )
    }

    private func findRootFile(in archive: Archive) throws -> String {
        guard let containerEntry = archive["META-INF/container.xml"] else {
            throw DocumentParserError.parsingFailed("Missing container.xml")
        }

        var containerData = Data()
        do {
            _ = try archive.extract(containerEntry) { data in
                containerData.append(data)
            }
        } catch {
            throw DocumentParserError.parsingFailed("Could not extract container.xml: \(error.localizedDescription)")
        }

        guard let containerXML = String(data: containerData, encoding: .utf8) else {
            throw DocumentParserError.parsingFailed("Could not read container.xml as UTF-8")
        }

        do {
            let doc = try SwiftSoup.parse(containerXML, "", Parser.xmlParser())
            let rootFiles = try doc.select("rootfile")

            guard let rootFile = rootFiles.first() else {
                throw DocumentParserError.parsingFailed("No rootfile element found in container.xml")
            }

            let fullPath = try rootFile.attr("full-path")
            guard !fullPath.isEmpty else {
                throw DocumentParserError.parsingFailed("Empty full-path attribute in rootfile")
            }

            return fullPath
        } catch let error as DocumentParserError {
            throw error
        } catch {
            throw DocumentParserError.parsingFailed("Failed to parse container.xml: \(error.localizedDescription)")
        }
    }

    private func parseOPF(archive: Archive, opfPath: String) throws -> (EPUBMetadata, [SpineItem], String) {
        guard let opfEntry = archive[opfPath] else {
            throw DocumentParserError.parsingFailed("Missing OPF file at \(opfPath)")
        }

        var opfData = Data()
        do {
            _ = try archive.extract(opfEntry) { data in
                opfData.append(data)
            }
        } catch {
            throw DocumentParserError.parsingFailed("Could not extract OPF file: \(error.localizedDescription)")
        }

        guard let opfXML = String(data: opfData, encoding: .utf8) else {
            throw DocumentParserError.parsingFailed("Could not read OPF file as UTF-8")
        }

        let basePath = (opfPath as NSString).deletingLastPathComponent

        do {
            let doc = try SwiftSoup.parse(opfXML, "", Parser.xmlParser())

            // Extract metadata - try multiple selector patterns for compatibility
            var title: String?
            var author: String?
            var coverId: String?

            // Try to find title
            if let titleEl = try doc.select("title").first() {
                title = try titleEl.text()
            }
            if title == nil || title?.isEmpty == true {
                if let titleEl = try doc.select("dc|title").first() {
                    title = try titleEl.text()
                }
            }

            // Try to find author/creator
            if let authorEl = try doc.select("creator").first() {
                author = try authorEl.text()
            }
            if author == nil || author?.isEmpty == true {
                if let authorEl = try doc.select("dc|creator").first() {
                    author = try authorEl.text()
                }
            }

            // Try to find cover ID
            if let metaEl = try doc.select("meta[name=cover]").first() {
                coverId = try metaEl.attr("content")
            }

            // Build manifest
            var manifest: [String: ManifestItem] = [:]
            let items = try doc.select("item")
            for item in items {
                let id = try item.attr("id")
                let href = try item.attr("href")
                let mediaType = try item.attr("media-type")
                if !id.isEmpty && !href.isEmpty {
                    manifest[id] = ManifestItem(id: id, href: href, mediaType: mediaType)
                }
            }

            // Build spine
            var spine: [SpineItem] = []
            let itemRefs = try doc.select("itemref")
            for itemRef in itemRefs {
                let idref = try itemRef.attr("idref")
                if let item = manifest[idref] {
                    spine.append(SpineItem(id: idref, href: item.href))
                }
            }

            let coverHref = coverId.flatMap { manifest[$0]?.href }
            let metadata = EPUBMetadata(title: title, author: author, coverId: coverId, coverHref: coverHref)

            return (metadata, spine, basePath)
        } catch let error as DocumentParserError {
            throw error
        } catch {
            throw DocumentParserError.parsingFailed("Failed to parse OPF file: \(error.localizedDescription)")
        }
    }

    private func extractContent(archive: Archive, spine: [SpineItem], basePath: String) throws -> String {
        var fullContent = ""
        var foundMainContent = false

        // Patterns to skip (front matter)
        let skipPatterns = [
            "cover", "title", "toc", "nav", "copyright", "dedication",
            "frontmatter", "front-matter", "halftitle", "half-title",
            "series", "praise", "about", "colophon", "credits"
        ]

        for item in spine {
            let hrefLower = item.href.lowercased()

            // Skip front matter files
            let shouldSkip = skipPatterns.contains { pattern in
                hrefLower.contains(pattern)
            }

            // Once we find real content, stop skipping
            if !foundMainContent && shouldSkip {
                continue
            }

            // Handle URL-encoded paths and resolve relative paths
            let decodedHref = item.href.removingPercentEncoding ?? item.href
            let itemPath = basePath.isEmpty ? decodedHref : "\(basePath)/\(decodedHref)"

            guard let entry = archive[itemPath] else {
                // Try without base path as fallback
                if let fallbackEntry = archive[decodedHref] {
                    if let text = extractTextFromEntry(archive: archive, entry: fallbackEntry) {
                        if !text.isEmpty && text.count > 100 {
                            foundMainContent = true
                        }
                        if foundMainContent {
                            fullContent += text + "\n\n"
                        }
                    }
                }
                continue
            }

            if let text = extractTextFromEntry(archive: archive, entry: entry) {
                // Consider it main content if it has substantial text
                if !text.isEmpty && text.count > 100 {
                    foundMainContent = true
                }
                if foundMainContent {
                    fullContent += text + "\n\n"
                }
            }
        }

        return fullContent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTextFromEntry(archive: Archive, entry: Entry) -> String? {
        var data = Data()
        do {
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
        } catch {
            return nil
        }

        // Try UTF-8 first, then Latin-1
        let html: String
        if let utf8 = String(data: data, encoding: .utf8) {
            html = utf8
        } else if let latin1 = String(data: data, encoding: .isoLatin1) {
            html = latin1
        } else {
            return nil
        }

        do {
            let doc = try SwiftSoup.parse(html)
            return try doc.body()?.text()
        } catch {
            return nil
        }
    }

    private func extractCover(archive: Archive, metadata: EPUBMetadata, basePath: String) throws -> Data? {
        guard let coverHref = metadata.coverHref else { return nil }

        let decodedHref = coverHref.removingPercentEncoding ?? coverHref
        let coverPath = basePath.isEmpty ? decodedHref : "\(basePath)/\(decodedHref)"

        let entry = archive[coverPath] ?? archive[decodedHref]
        guard let coverEntry = entry else { return nil }

        var data = Data()
        _ = try archive.extract(coverEntry) { chunk in
            data.append(chunk)
        }

        return data
    }
}

private struct EPUBMetadata {
    let title: String?
    let author: String?
    let coverId: String?
    let coverHref: String?
}

private struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
}

private struct SpineItem {
    let id: String
    let href: String
}
