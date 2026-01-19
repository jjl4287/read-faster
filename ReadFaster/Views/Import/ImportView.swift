import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var isImporting = false
    @State private var importError: String?
    @State private var showingError = false
    @State private var isProcessing = false
    @State private var isDragOver = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                dropZone

                supportedFormatsInfo

                if isProcessing {
                    ProgressView("Importing...")
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Import Book")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: supportedTypes,
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(importError ?? "Unknown error occurred")
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 300)
        #endif
    }

    private var dropZone: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundStyle(isDragOver ? .accentColor : .secondary)

            Text("Drop a file here")
                .font(.headline)

            Text("or")
                .foregroundStyle(.secondary)

            Button("Browse Files") {
                isImporting = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    isDragOver ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isDragOver ? Color.accentColor.opacity(0.1) : Color.clear)
                )
        }
        .onDrop(of: supportedTypes, isTargeted: $isDragOver) { providers in
            handleDrop(providers)
            return true
        }
    }

    private var supportedFormatsInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Supported Formats")
                .font(.headline)

            HStack(spacing: 16) {
                FormatBadge(icon: "book.closed", label: "EPUB", description: "Best quality")
                FormatBadge(icon: "doc.richtext", label: "PDF", description: "With OCR")
                FormatBadge(icon: "doc.text", label: "TXT", description: "Plain text")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var supportedTypes: [UTType] {
        [.epub, .pdf, .plainText, .text]
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard let provider = providers.first else { return }

        for type in supportedTypes {
            if provider.hasItemConformingToTypeIdentifier(type.identifier) {
                provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
                    if let url = url {
                        // Copy to temporary location since the provided URL is temporary
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(url.lastPathComponent)

                        try? FileManager.default.removeItem(at: tempURL)
                        try? FileManager.default.copyItem(at: url, to: tempURL)

                        Task { @MainActor in
                            await importFile(from: tempURL)
                        }
                    }
                }
                break
            }
        }
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importFile(from: url)
            }
        case .failure(let error):
            importError = error.localizedDescription
            showingError = true
        }
    }

    private func importFile(from url: URL) async {
        isProcessing = true
        defer { isProcessing = false }

        do {
            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let storage = StorageService(modelContext: modelContext)
            _ = try await storage.importBook(from: url)

            dismiss()
        } catch {
            importError = error.localizedDescription
            showingError = true
        }
    }
}

struct FormatBadge: View {
    let icon: String
    let label: String
    let description: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.accentColor)

            Text(label)
                .font(.caption)
                .fontWeight(.medium)

            Text(description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.secondary.opacity(0.1))
        }
    }
}

// MARK: - UTType Extensions
extension UTType {
    static var epub: UTType {
        UTType(filenameExtension: "epub") ?? .data
    }
}

#Preview {
    ImportView()
        .modelContainer(for: [Book.self], inMemory: true)
}
