import SwiftUI

struct WordDisplay: View {
    let word: String

    @AppStorage("fontSize") private var fontSize: Double = 48
    @Environment(\.colorScheme) private var colorScheme

    private var orpWord: ORPWord {
        ORPWord(word: word)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Guide line above
            guideLine

            // Word display with ORP highlight
            HStack(spacing: 0) {
                // Before ORP (right-aligned to the focal point)
                Text(orpWord.before)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)

                // Focal character (red)
                if let focal = orpWord.focal {
                    Text(String(focal))
                        .foregroundStyle(.red)
                }

                // After ORP (left-aligned from focal point)
                Text(orpWord.after)
                    .foregroundStyle(.primary)
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.5)

            // Guide line below with focal indicator
            ZStack {
                guideLine

                // Focal point indicator
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: 12)
                    .offset(y: -4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 40)
        .accessibilityElement()
        .accessibilityLabel(word)
    }

    private var guideLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(height: 1)
    }
}

#Preview("Short word") {
    VStack(spacing: 40) {
        WordDisplay(word: "I")
        WordDisplay(word: "the")
        WordDisplay(word: "word")
    }
    .padding()
}

#Preview("Long word") {
    VStack(spacing: 40) {
        WordDisplay(word: "recognition")
        WordDisplay(word: "extraordinary")
        WordDisplay(word: "supercalifragilisticexpialidocious")
    }
    .padding()
}

#Preview("Empty") {
    WordDisplay(word: "")
        .padding()
}
