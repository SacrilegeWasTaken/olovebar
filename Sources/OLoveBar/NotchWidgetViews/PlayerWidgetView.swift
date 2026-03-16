import SwiftUI

// MARK: - Marquee Text

private struct MarqueeText: View {
    let text: String
    let font: Font
    let fontSize: CGFloat
    let color: Color
    var speed: Double = 30

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var animating = false

    private var overflow: CGFloat {
        max(0, textWidth - containerWidth)
    }

    var body: some View {
        GeometryReader { geo in
            Text(text)
                .font(font)
                .foregroundColor(color)
                .lineLimit(1)
                .fixedSize()
                .offset(x: offset)
                .onAppear { containerWidth = geo.size.width }
                .onChange(of: geo.size.width) { _, w in containerWidth = w }
                .background {
                    Text(text)
                        .font(font)
                        .lineLimit(1)
                        .fixedSize()
                        .hidden()
                        .background(GeometryReader { g in
                            Color.clear.onAppear { textWidth = g.size.width }
                                .onChange(of: text) { _, _ in
                                    textWidth = g.size.width
                                }
                        })
                }
                .onChange(of: text) { _, _ in resetAndStart() }
                .onChange(of: overflow) { _, _ in resetAndStart() }
                .onAppear { startCycle() }
        }
        .frame(height: lineHeight)
        .clipped()
    }

    private func resetAndStart() {
        animating = false
        offset = 0
        startCycle()
    }

    private func startCycle() {
        guard overflow > 0, !animating else { return }
        animating = true
        scrollForward()
    }

    private func scrollForward() {
        guard overflow > 0 else { animating = false; return }
        let duration = overflow / speed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.linear(duration: duration)) {
                offset = -overflow
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration + 1.5) {
                scrollBack()
            }
        }
    }

    private func scrollBack() {
        guard animating else { return }
        let duration = overflow / speed
        withAnimation(.linear(duration: duration)) {
            offset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard animating else { return }
            scrollForward()
        }
    }

    private var lineHeight: CGFloat {
        let nsFont = NSFont.systemFont(ofSize: fontSize)
        return ceil(nsFont.ascender - nsFont.descender + nsFont.leading)
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
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)

                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.white)
                                .frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)

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
