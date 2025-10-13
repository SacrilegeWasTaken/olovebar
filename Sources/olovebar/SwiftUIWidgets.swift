import SwiftUI

struct BarContentView: View {
    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 0) {
                let buttonHeight: CGFloat = 33
                let buttonWidth: CGFloat = 45
                Button(action: {
                    // Action for the button
                }) {
                    Image(systemName: "apple.logo")
                        .frame(width: buttonWidth, height: buttonHeight)
                        .foregroundColor(.white)
                        .background(.clear)
                        .font(.system(size: 15, weight: .semibold))
                        .cornerRadius(16)
                        .glassEffect()
                }
                    .frame(width: buttonWidth, height: buttonHeight)
                    .cornerRadius(16)

                Spacer()
                HStack(spacing: 8) {
                    Text(Date(), style: .date)
                        .foregroundColor(.white.opacity(0.8))
                        .font(.system(size: 12))
                }.padding(.horizontal, 8).cornerRadius(12)
            }
        }
    }
}