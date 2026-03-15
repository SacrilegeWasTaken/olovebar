import SwiftUI

enum ExpandedControl: Equatable {
    case none
    case display
    case keyboard
    case volume
}

struct NotchControlCenterView: View {
    @ObservedObject var displayModel = GlobalModels.shared.displayBrightnessModel
    @ObservedObject var keyboardModel = GlobalModels.shared.keyboardBrightnessModel
    @ObservedObject var volumeModel = GlobalModels.shared.volumeModel
    
    @State private var expanded: ExpandedControl = .none
    @Namespace private var animation
    
    private let circleSize: CGFloat = 28
    private let spacing: CGFloat = 8
    private var totalWidth: CGFloat {
        (circleSize * 3) + (spacing * 2)
    }
    
    var body: some View {
        ZStack {
            if expanded == .none {
                HStack(spacing: spacing) {
                    circleButton(icon: "sun.max.fill", type: .display, id: "display")
                    circleButton(icon: "light.min", type: .keyboard, id: "keyboard")
                    circleButton(icon: volumeIcon, type: .volume, id: "volume")
                }
            } else {
                if expanded == .display {
                    ExpandedSlider(
                        value: Binding(
                            get: { self.displayModel.level },
                            set: { self.displayModel.setBrightness($0) }
                        ),
                        icon: "sun.max.fill",
                        id: "display",
                        expanded: $expanded,
                        animation: animation,
                        width: totalWidth,
                        height: circleSize
                    )
                } else if expanded == .keyboard {
                    ExpandedSlider(
                        value: Binding(
                            get: { self.keyboardModel.level },
                            set: { self.keyboardModel.setBrightness($0) }
                        ),
                        icon: "light.min",
                        id: "keyboard",
                        expanded: $expanded,
                        animation: animation,
                        width: totalWidth,
                        height: circleSize
                    )
                } else if expanded == .volume {
                    ExpandedSlider(
                        value: Binding(
                            get: { self.volumeModel.level },
                            set: { self.volumeModel.setVolume($0) }
                        ),
                        icon: volumeIcon,
                        id: "volume",
                        expanded: $expanded,
                        animation: animation,
                        width: totalWidth,
                        height: circleSize
                    )
                }
            }
        }
        .frame(width: totalWidth, height: circleSize)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NotchControlCenterShouldCollapse"))) { _ in
            if expanded != .none {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    expanded = .none
                }
            }
        }
    }
    
    @ViewBuilder
    func circleButton(icon: String, type: ExpandedControl, id: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                expanded = type
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .matchedGeometryEffect(id: "bg_\(id)", in: animation)
                
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .matchedGeometryEffect(id: "icon_\(id)", in: animation)
            }
            .frame(width: circleSize, height: circleSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
    
    var volumeIcon: String {
        if volumeModel.isMuted || volumeModel.level == 0 {
            return "speaker.slash.fill"
        } else if volumeModel.level < 0.33 {
            return "speaker.wave.1.fill"
        } else if volumeModel.level < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
}

struct ExpandedSlider: View {
    @Binding var value: Float
    let icon: String
    let id: String
    @Binding var expanded: ExpandedControl
    let animation: Namespace.ID
    let width: CGFloat
    let height: CGFloat
    
    @GestureState private var isDragging: Bool = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.white.opacity(0.1))
                .matchedGeometryEffect(id: "bg_\(id)", in: animation)
            
            GeometryReader { geo in
                Capsule()
                    .fill(Color.white.opacity(0.8))
                    .frame(width: max(height, width * CGFloat(value)))
                    .animation(.interactiveSpring(), value: value)
            }
            .frame(width: width, height: height)
            
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(value > 0.15 ? .black : .primary)
                .frame(width: height, height: height, alignment: .center)
                .matchedGeometryEffect(id: "icon_\(id)", in: animation)
        }
        .clipShape(Capsule())
        .contentShape(Capsule())
        .gesture(
            DragGesture(minimumDistance: 0)
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { gesture in
                    let percent = min(max(0, gesture.location.x / width), 1)
                    value = Float(percent)
                }
        )
        .frame(width: width, height: height)
    }
}
