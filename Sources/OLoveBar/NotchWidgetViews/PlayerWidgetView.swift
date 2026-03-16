import SwiftUI

struct PlayerWidgetView: View {
    @StateObject private var model = PlayerModel.shared
    
    private var progress: Double {
        guard model.duration > 0 else { return 0 }
        return model.elapsedTime / model.duration
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Artwork (Green box in user screenshot)
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
                    .stroke(Color.green.opacity(0.5), lineWidth: 1) // Purely for reference/styling
            )
            
            VStack(alignment: .leading, spacing: 4) {
                // Track Info (Blue box in user screenshot)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(model.artist)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                // .border(Color.blue.opacity(0.5)) // Purely for reference
                
                // Controls and Timeline (Pink box in user screenshot)
                VStack(spacing: 6) {
                    // Timeline
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
                    
                    // Control Buttons
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
                // .border(Color.hotPink.opacity(0.5)) // Purely for reference
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}
