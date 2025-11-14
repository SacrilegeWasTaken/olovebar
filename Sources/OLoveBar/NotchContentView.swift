import SwiftUI
import MacroAPI


struct NotchContentView: View {
    @StateObject var config: Config
    @ObservedObject var state: NotchWindowState
    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel
    private var notchMenuExtraPadding: CGFloat {
        max(60, config.windowCornerRadius * 2)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                HStack {
                    if state.isExpanded { // Avoiding layout hallucinations 

                    }
                }
                .frame(maxWidth: .infinity, maxHeight: Globals.notchHeight)
                .background(.black)
                
                HStack(spacing: 4) {
                    if state.isExpanded { // Avoiding layout hallucinations 

                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)

                HStack(spacing: 0) {
                    MenuWidgetView(config: config)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .opacity(state.isExpanded ? 1 : 0)
                        .allowsHitTesting(state.isExpanded)
                }
                .frame(maxWidth: .infinity, maxHeight: config.widgetHeight)
                .background(.black)
                .onPreferenceChange(MenuWidthPreferenceKey.self) { width in
                    guard width > 0 else { return }
                    let paddedWidth = width + notchMenuExtraPadding
                    state.updatePreferredWidth(paddedWidth)
                }
            }
            .background(.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(state.isExpanded ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: state.isExpanded)
            .onAppear {
                activeAppModel.ensureMenuItemsLoaded()
                state.updateMinimumWidth(config.notchMinimumWidth)
            }
            .onChange(of: state.isExpanded, initial: false) { _, expanded in
                if expanded {
                    activeAppModel.ensureMenuItemsLoaded()
                }
            }
            .onChange(of: config.notchMinimumWidth, initial: true) { _, newValue in
                state.updateMinimumWidth(newValue)
            }
        }
    }
}
