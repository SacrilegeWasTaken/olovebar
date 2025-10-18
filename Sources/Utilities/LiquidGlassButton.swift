import SwiftUI

public struct LiquidGlassButton: View {
    var title: String = "Save"
    var width: CGFloat = 200
    var height: CGFloat = 40
    var action: () -> Void
    
    public init(title: String = "Save", width: CGFloat = 200, height: CGFloat = 40, action: @escaping () -> Void) {
        self.title = title
        self.width = width
        self.height = height
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: width, height: height)
                .background(
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: height / 2)
                                .fill(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: Color.white.opacity(0.2), radius: 4, x: -2, y: -2)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 2, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: height / 2)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .blur(radius: 1)
                        .mask(RoundedRectangle(cornerRadius: height / 2).fill(
                            LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .bottom)
                        ))
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
