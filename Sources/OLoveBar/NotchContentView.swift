import SwiftUI
 
struct NotchContentView: View {
    @ObservedObject var state: NotchWindowState
    
    var body: some View {
        ZStack {
            Text(state.isExpanded ? "Expanded" : "Collapsed")
                .foregroundColor(.black)
        }
    }
}