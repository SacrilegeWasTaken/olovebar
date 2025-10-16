import SwiftUI
import MacroAPI

@LogFunctions(.Widgets([.languageModel]))
struct LanguageWidgetView: View {
    @ObservedObject var model: LanguageModel
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    var body: some View {
        Button(action: { model.toggle() }) {
            Text(model.current)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: width, height: height)
                .glassEffect()
        }
        .buttonStyle(.plain)
        .cornerRadius(cornerRadius)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { model.update() }
    }
}