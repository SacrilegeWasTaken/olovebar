import SwiftUI
import MacroAPI
import AppKit

@LogFunctions(.Widgets([.aerospaceModel]))
struct AerospaceWidgetView: View {
    @ObservedObject var model: AerospaceModel
    @ObservedObject var config: Config
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
        HStack(spacing: 4) {
            let _ = debug("Updating UI. Focused: \(String(describing: model.focused))")
            ForEach(model.workspaces) { workspace in
                Button(action: { model.focus(workspace.id) }) {
                    HStack(spacing: 4) {
                        // Workspace number with fixed width to prevent disappearing
                        Text(workspace.id)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(workspace.id == model.focused ? .purple : .white)
                            .frame(minWidth: 12, alignment: .center)
                            .fixedSize()
                        
                        // App icons
                        ForEach(workspace.apps) { app in
                            if let icon = app.icon {
                                Image(nsImage: icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)
                                    .clipped()
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(height: config.widgetHeight)
                    .background(.clear)
                    
                }
                .buttonStyle(.plain)
                .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
                .background(.clear)
            }
        }
        .padding(.horizontal, 4)
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        .frame(height: config.widgetHeight)
        }
    }
}