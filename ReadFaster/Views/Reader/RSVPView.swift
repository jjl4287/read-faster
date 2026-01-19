import SwiftUI
import SwiftData

struct RSVPView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @StateObject private var engine = RSVPEngine()
    @State private var showingBookmarks = false
    @State private var showingSettings = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()

                wordDisplayArea(geometry: geometry)

                Spacer()

                controlsArea
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(book.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingBookmarks = true
                    } label: {
                        Label("Bookmarks", systemImage: "bookmark")
                    }

                    Button {
                        addBookmark()
                    } label: {
                        Label("Add Bookmark", systemImage: "bookmark.fill")
                    }

                    Divider()

                    Button {
                        showingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gear")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksSheet(book: book, engine: engine)
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsSheet(engine: engine)
        }
        .onAppear {
            setupEngine()
        }
        .onDisappear {
            engine.pause()
        }
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            engine.pause()
        }
        #else
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            engine.pause()
        }
        #endif
    }

    @ViewBuilder
    private func wordDisplayArea(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            WordDisplay(word: engine.currentWord)
                .frame(maxWidth: min(geometry.size.width * 0.9, 600))
                .contentShape(Rectangle())
                .onTapGesture {
                    engine.toggle()
                }
                #if os(macOS)
                .onKeyPress(.space) {
                    engine.toggle()
                    return .handled
                }
                .onKeyPress(.leftArrow) {
                    engine.skipBackward()
                    return .handled
                }
                .onKeyPress(.rightArrow) {
                    engine.skipForward()
                    return .handled
                }
                #endif

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var controlsArea: some View {
        VStack(spacing: 16) {
            ProgressSlider(
                value: Binding(
                    get: { engine.progress },
                    set: { engine.seekToProgress($0) }
                ),
                isPlaying: engine.isPlaying
            )

            ControlsView(engine: engine)
        }
        .padding()
        .background(.regularMaterial)
    }

    private var statusText: String {
        let current = engine.currentIndex + 1
        let total = engine.totalWords
        let percent = Int(engine.progress * 100)
        return "\(current) / \(total) (\(percent)%)"
    }

    private func setupEngine() {
        engine.load(words: book.words)

        // Resume from saved position
        if let progress = book.progress {
            engine.seek(to: progress.currentWordIndex)
        }

        // Setup progress callback
        engine.onProgressUpdate = { [weak engine] wordIndex, sessionTime, wordsRead in
            guard let engine = engine else { return }
            Task { @MainActor in
                let storage = StorageService(modelContext: modelContext)
                try? storage.updateProgress(
                    for: book,
                    wordIndex: wordIndex,
                    sessionTime: sessionTime,
                    wordsRead: wordsRead
                )
            }
        }

        // Start session
        Task {
            let storage = StorageService(modelContext: modelContext)
            try? storage.startReadingSession(for: book)
        }
    }

    private func addBookmark() {
        let storage = StorageService(modelContext: modelContext)
        let words = book.words
        let startIndex = max(0, engine.currentIndex - 5)
        let endIndex = min(words.count, engine.currentIndex + 5)
        let context = words[startIndex..<endIndex].joined(separator: " ")

        try? storage.addBookmark(
            to: book,
            at: engine.currentIndex,
            highlightedText: context
        )
    }
}

#Preview {
    NavigationStack {
        RSVPView(book: Book(
            title: "Sample Book",
            author: "Author",
            fileName: "sample.txt",
            fileType: .txt,
            content: "This is a sample book with some content to display in the RSVP reader. It contains multiple words that will be shown one at a time.",
            totalWords: 25
        ))
    }
    .modelContainer(for: [Book.self, ReadingProgress.self, Bookmark.self], inMemory: true)
}
