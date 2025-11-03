import SwiftUI
import MacroAPI
import AppKit

@LogFunctions(.Widgets([.aerospaceModel]))
struct AerospaceWidgetView: View {
    @ObservedObject var config: Config


    @ObservedObject var model = GlobalModels.shared.aerospaceModel

    
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
        HStack(spacing: 2) {
            let _ = debug("Updating UI. Focused: \(String(describing: model.focused))")
            ForEach(model.workspaces) { workspace in
                Button(action: { model.focus(workspace.id) }) {
                    HStack(spacing: 4) {
                        // Workspace number with fixed width to prevent disappearing
                        Text(workspace.id)
                            .font(.system(size: 12, weight: workspace.id == model.focused ? .semibold : .medium))
                            .foregroundColor(.white)
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
                                    .opacity(workspace.id == model.focused ? 1.0 : 0.75)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(height: config.widgetHeight)
                    .background(
                        ZStack {
                            // Base gradient for all
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.gray.opacity(0.2)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            
                            // Extra glow for active workspace
                            if workspace.id == model.focused {
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.clear,
                                        Color.clear,
                                        Color.purple.opacity(0.2),
                                        Color.purple.opacity(0.4),
                                        Color.blue.opacity(0.4)
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .background(.clear)
        .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
        .frame(height: config.widgetHeight)
        }
    }
}