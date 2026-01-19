import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedBook: Book?
    @State private var showingImport = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LibraryView(
                selectedBook: $selectedBook,
                showingImport: $showingImport
            )
            .navigationDestination(for: Book.self) { book in
                RSVPView(book: book)
            }
        }
        .sheet(isPresented: $showingImport) {
            ImportView()
        }
        .onChange(of: selectedBook) { _, newBook in
            if let book = newBook {
                navigationPath.append(book)
                selectedBook = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .importBook)) { _ in
            showingImport = true
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Book.self, ReadingProgress.self, Bookmark.self], inMemory: true)
}
