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
        ZStack(alignment: .top) {
            expandedContent
                // The content stays mounted and is laid out at the final expanded
                // size even while the window is still animating towards it: the
                // growing window merely reveals it, so nothing re-flows or shifts
                // mid-animation and the shape stays glued to the top edge.
                .frame(
                    width: state.expandedContentSize.width > 0 ? state.expandedContentSize.width : nil,
                    height: state.expandedContentSize.height > 0 ? state.expandedContentSize.height : nil,
                    alignment: .top
                )
                .scaleEffect(state.isExpanded ? 1 : 0.55, anchor: .top)
                .opacity(state.isExpanded ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: state.isExpanded)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private var expandedContent: some View {
        VStack(spacing: 0) {
            HStack {
                HStack { // Player
                    PlayerWidgetView()
                        .padding(.leading, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 0) {
                    // Reserved space under the physical notch (camera housing).
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: Globals.notchHeight)
                    HStack {
                        NotchControlCenterView()
                            .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: Globals.notchWidth)

                HStack { // Other menu controls

                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                MenuWidgetView(config: config)
                    .fixedSize(horizontal: true, vertical: false)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: config.widgetHeight)
            .onPreferenceChange(MenuWidthPreferenceKey.self) { width in
                guard width > 0 else { return }
                let paddedWidth = width + notchMenuExtraPadding
                state.updatePreferredWidth(paddedWidth)
            }
        }
        .background(.black)
        .contentShape(Rectangle())
        .onTapGesture {
            NotificationCenter.default.post(name: NSNotification.Name("NotchControlCenterShouldCollapse"), object: nil)
        }
    }
}
