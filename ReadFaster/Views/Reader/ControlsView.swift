import SwiftUI

struct ControlsView: View {
    @ObservedObject var engine: RSVPEngine

    var body: some View {
        VStack(spacing: 16) {
            // Playback controls
            HStack(spacing: 32) {
                // Previous sentence
                Button {
                    engine.previousSentence()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(!engine.hasContent)

                // Skip backward
                Button {
                    engine.skipBackward()
                } label: {
                    Image(systemName: "gobackward.10")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(engine.isAtStart)

                // Play/Pause
                Button {
                    engine.toggle()
                } label: {
                    Image(systemName: engine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                }
                .buttonStyle(.plain)
                .disabled(!engine.hasContent)
                .keyboardShortcut(.space, modifiers: [])

                // Skip forward
                Button {
                    engine.skipForward()
                } label: {
                    Image(systemName: "goforward.10")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(engine.isAtEnd)

                // Next sentence
                Button {
                    engine.nextSentence()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .disabled(!engine.hasContent)
            }

            // WPM slider
            WPMSlider(wpm: $engine.wordsPerMinute)
        }
    }
}

struct WPMSlider: View {
    @Binding var wpm: Int

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("\(RSVPEngine.minWPM)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Slider(
                    value: Binding(
                        get: { Double(wpm) },
                        set: { wpm = Int($0) }
                    ),
                    in: Double(RSVPEngine.minWPM)...Double(RSVPEngine.maxWPM),
                    step: 25
                )

                Text("\(RSVPEngine.maxWPM)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("\(wpm) WPM")
                .font(.headline)
                .monospacedDigit()
        }
    }
}

struct ProgressSlider: View {
    @Binding var value: Double
    let isPlaying: Bool

    @State private var isDragging = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 4)

                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * value, height: 4)

                // Thumb (only visible when dragging or paused)
                if isDragging || !isPlaying {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 16)
                        .offset(x: (geometry.size.width - 16) * value)
                }
            }
            .frame(height: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let newValue = gesture.location.x / geometry.size.width
                        value = min(max(newValue, 0), 1)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 20)
    }
}

#Preview {
    VStack {
        ControlsView(engine: {
            let engine = RSVPEngine()
            engine.load(content: "Sample content for testing the controls view with multiple words.")
            return engine
        }())
    }
    .padding()
}
