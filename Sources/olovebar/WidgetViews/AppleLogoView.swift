import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.appleLogoModel]))
struct AppleLogoWidgetView: View {
    @ObservedObject var model: AppleLogoModel
    @Binding var theme_toggle: Theme 
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Button(action: {
            theme_toggle = theme_toggle.next()
        }) {
            Image(systemName: "apple.logo")
                .frame(width: width, height: height)
                .foregroundColor(.white)
                .background(.clear)
                .font(.system(size: 15, weight: .semibold))
                .cornerRadius(cornerRadius)
                .glassEffect()
        }
        .buttonStyle(.plain)
        .background(.clear)
        .frame(width: width, height: height)
        .cornerRadius(cornerRadius)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}