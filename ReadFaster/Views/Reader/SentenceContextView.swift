import SwiftUI

/// Displays the current sentence with the active word highlighted
/// Renders as a natural paragraph with smooth underline highlight
struct SentenceContextView: View {
    let words: [String]
    let currentWordIndex: Int
    
    var body: some View {
        if words.isEmpty {
            EmptyView()
        } else {
            ParagraphFlowLayout(spacing: 5, lineSpacing: 10) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    wordView(word: word, index: index)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .clipped() // Prevent overflow
        }
    }
    
    @ViewBuilder
    private func wordView(word: String, index: Int) -> some View {
        let isCurrent = index == currentWordIndex
        let isPast = index < currentWordIndex
        
        Text(word)
            .font(AppFont.regular(size: 16))
            .foregroundStyle(wordColor(isCurrent: isCurrent, isPast: isPast))
            .overlay(alignment: .bottom) {
                if isCurrent {
                    // Smooth underline highlight
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: 2)
                        .offset(y: 2)
                }
            }
    }
    
    private func wordColor(isCurrent: Bool, isPast: Bool) -> Color {
        if isCurrent {
            return .primary
        } else if isPast {
            return .primary.opacity(0.5)
        } else {
            return .primary.opacity(0.35)
        }
    }
}

/// A flow layout optimized for paragraph-like text display
struct ParagraphFlowLayout: Layout {
    var spacing: CGFloat = 5
    var lineSpacing: CGFloat = 10
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        
        // Center the content vertically within bounds
        let contentHeight = result.size.height
        let verticalOffset = max(0, (bounds.height - contentHeight) / 2)
        
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y + verticalOffset),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }
    
    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var lineWidths: [CGFloat] = []
        var lineStartIndices: [Int] = [0]
        
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var currentLineWidth: CGFloat = 0
        
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)
            
            // Check if we need to wrap to next line
            if currentX + size.width > maxWidth && currentX > 0 {
                lineWidths.append(currentLineWidth - spacing)
                lineStartIndices.append(index)
                currentX = 0
                currentY += lineHeight + lineSpacing
                lineHeight = 0
                currentLineWidth = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            
            currentX += size.width + spacing
            currentLineWidth = currentX
            lineHeight = max(lineHeight, size.height)
        }
        
        // Don't forget the last line
        lineWidths.append(currentLineWidth - spacing)
        
        let totalHeight = currentY + lineHeight
        
        // Center each line horizontally
        for (lineIndex, startIndex) in lineStartIndices.enumerated() {
            let endIndex = lineIndex + 1 < lineStartIndices.count ? lineStartIndices[lineIndex + 1] : positions.count
            let lineWidth = lineWidths[lineIndex]
            let horizontalOffset = max(0, (maxWidth - lineWidth) / 2)
            
            for i in startIndex..<endIndex {
                positions[i].x += horizontalOffset
            }
        }
        
        return LayoutResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }
    
    private struct LayoutResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}

// MARK: - Preview

#Preview("Paragraph style") {
    VStack(spacing: 20) {
        SentenceContextView(
            words: ["System", "Architecture", "A", "system's", "architecture", "is", "a", "representation", "of", "a", "system", "in", "which", "there", "is", "a", "mapping", "of", "the", "software", "architecture", "onto", "the", "hardware", "architecture."],
            currentWordIndex: 18
        )
        .frame(maxHeight: 150)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 600)
        
        Text("the")
            .font(AppFont.rsvpWord(size: 48))
    }
    .padding()
}

#Preview("Short sentence") {
    VStack(spacing: 20) {
        SentenceContextView(
            words: ["The", "quick", "brown", "fox", "jumps."],
            currentWordIndex: 2
        )
        .frame(maxHeight: 100)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 400)
    }
    .padding()
}
