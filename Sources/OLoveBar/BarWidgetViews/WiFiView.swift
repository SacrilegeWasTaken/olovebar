import SwiftUI
import MacroAPI

/// Exposes the AppKit view backing the widget so menus can anchor to it exactly.
private final class AnchorBox {
    weak var view: NSView?
}

private struct AnchorViewAccessor: NSViewRepresentable {
    let box: AnchorBox

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        box.view = view
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        box.view = nsView
    }
}

@LogFunctions(.Widgets([.wifiModel]))
struct WiFiWidgetView: View {
    @ObservedObject var config: Config


    @ObservedObject var model = GlobalModels.shared.wifiModel

    @State private var anchorBox = AnchorBox()

    var body: some View {
        Button(action: {
            model.update()
            if let anchor = anchorBox.view {
                WiFiMenuPresenter.shared.toggle(below: anchor)
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: model.stateIcon)
                    .foregroundColor(.white)
                    .font(.system(size: 14))
                if config.showWiFiName {
                    Text(model.ssid ?? "No Wi‑Fi")
                        .foregroundColor(.white)
                        .font(.system(size: 12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(height: config.widgetHeight)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                LiquidGlassBackground(
                    variant: GlassVariant.safe(from: config.widgetGlassVariant),
                    cornerRadius: config.widgetCornerRadius
                ) {}
            )
            .cornerRadius(config.widgetCornerRadius)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(AnchorViewAccessor(box: anchorBox))
        .onAppear { model.update() }
    }
}