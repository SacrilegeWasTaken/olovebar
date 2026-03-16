import SwiftUI

// MARK: - Marquee Text

private struct MarqueeText: View {
    let text: String
    let font: Font
    let fontSize: CGFloat
    let color: Color
    var speed: Double = 30
    var gap: CGFloat = 40

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    private var needsScroll: Bool { textWidth > containerWidth }
    private var scrollDistance: CGFloat { textWidth + gap }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                label
                if needsScroll {
                    Spacer().frame(width: gap)
                    label
                }
            }
            .offset(x: offset)
            .onAppear { containerWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, w in containerWidth = w }
            .onChange(of: text) { _, _ in resetAndStart() }
            .onChange(of: needsScroll) { _, _ in resetAndStart() }
            .onAppear { startCycle() }
        }
        .frame(height: lineHeight)
        .clipped()
    }

    private var label: some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .lineLimit(1)
            .fixedSize()
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { textWidth = g.size.width }
                    .onChange(of: text) { _, _ in textWidth = g.size.width }
            })
    }

    private func resetAndStart() {
        animating = false
        offset = 0
        DispatchQueue.main.async { startCycle() }
    }

    private func startCycle() {
        guard needsScroll, !animating else { return }
        animating = true
        tick()
    }

    private func tick() {
        guard needsScroll, animating else { animating = false; return }
        let duration = scrollDistance / speed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard self.animating else { return }
            withAnimation(.linear(duration: duration)) {
                self.offset = -self.scrollDistance
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                guard self.animating else { return }
                self.offset = 0
                self.tick()
            }
        }
    }

    private var lineHeight: CGFloat {
        let nsFont = NSFont.systemFont(ofSize: fontSize)
        return ceil(nsFont.ascender - nsFont.descender + nsFont.leading)
    }
}

// MARK: - Seek Slider

private struct SeekSlider: View {
    let progress: Double
    let duration: Double
    let onSeek: (Double) -> Void

    @State private var isDragging = false
    @State private var dragProgress: Double?

    private var displayProgress: Double {
        if isDragging, let p = dragProgress { return p }
        return progress
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white)
                    .frame(width: max(0, w * displayProgress), height: 4)
            }
            .frame(height: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard w > 0 else { return }
                let fraction = max(0, min(1, location.x / w))
                onSeek(fraction)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard w > 0 else { return }
                        isDragging = true
                        let fraction = max(0, min(1, value.location.x / w))
                        dragProgress = fraction
                    }
                    .onEnded { value in
                        guard w > 0 else { return }
                        let fraction = max(0, min(1, value.location.x / w))
                        onSeek(fraction)
                        isDragging = false
                        dragProgress = nil
                    }
            )
        }
    }
}

// MARK: - Player Widget

struct PlayerWidgetView: View {
    @StateObject private var model = PlayerModel.shared

    private var progress: Double {
        guard model.duration > 0 else { return 0 }
        return model.elapsedTime / model.duration
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let image = model.artwork {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 24))
                        }
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.5), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    MarqueeText(
                        text: model.title,
                        font: .system(size: 14, weight: .semibold),
                        fontSize: 14,
                        color: .white
                    )

                    MarqueeText(
                        text: model.artist,
                        font: .system(size: 12),
                        fontSize: 12,
                        color: .white.opacity(0.7)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 6) {
                    SeekSlider(progress: progress, duration: model.duration) { fraction in
                        model.seek(to: fraction)
                    }
                    .frame(height: 8)

                    HStack(spacing: 20) {
                        Button(action: { model.previous() }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)

                        Button(action: { model.playPause() }) {
                            Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 18))
                        }
                        .buttonStyle(.plain)

                        Button(action: { model.next() }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
