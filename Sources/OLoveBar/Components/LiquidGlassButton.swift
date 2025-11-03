import SwiftUI

struct LiquidGlassButton: View {
    var title: String = "Save"
    var width: CGFloat = 200
    var height: CGFloat = 40
    var action: () -> Void
    @State private var isHovered = false
    
    init(title: String = "Save", width: CGFloat = 200, height: CGFloat = 40, action: @escaping () -> Void) {
        self.title = title
        self.width = width
        self.height = height
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: width, height: height)
                .glassEffect(.clear)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}
