import SwiftUI
import MacroAPI


struct NotchContentView: View {
    @StateObject var config: Config
    @ObservedObject var state: NotchWindowState
    @ObservedObject var activeAppModel = GlobalModels.shared.activeAppModel

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

                HStack(spacing: 4) {
                    if state.isExpanded { // Avoiding layout hallucinations 
                        MenuWidgetView(config: config)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: 35)
                .background(.black)
            }
            .background(.black)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(state.isExpanded ? 1 : 0)
            .animation(.easeInOut(duration: 0.3), value: state.isExpanded)
            .onAppear {
                activeAppModel.ensureMenuItemsLoaded()
            }
            .onChange(of: state.isExpanded, initial: false) { _, expanded in
                if expanded {
                    activeAppModel.ensureMenuItemsLoaded()
                }
            }
        }
    }
}
