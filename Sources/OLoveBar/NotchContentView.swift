import SwiftUI
 
struct NotchContentView: View {
    @ObservedObject var state: NotchWindowState
    @StateObject var config: Config
    
    var body: some View {
        Group {
            if state.isExpanded {
                VStack(spacing: 0) {
                    HStack {

                    }
                    .background(.yellow)
                    .frame(maxWidth: .infinity, maxHeight: Globals.notchHeight)
                    
                    HStack {

                    }
                    .background(.pink)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: state.isExpanded)
    }
}