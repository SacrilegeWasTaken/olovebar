import SwiftUI
import Foundation
import Utilities
import MacroAPI

@MainActor
public class ActiveAppModel: ObservableObject {
    @Published var bundleID: String = ""
    @Published var appName: String = ""

    var timer: Timer?

    public init() {
        startTimer()
    }

    func startTimer() {
        
        timer?.invalidate()
        update()
        timer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(tick(_:)), userInfo: nil, repeats: true)
    }

    @objc private func tick(_ t: Timer) {
        update()
    }

    func update() {
        if let app = NSWorkspace.shared.frontmostApplication {
            let name = app.localizedName ?? ""
            let bid = app.bundleIdentifier ?? ""
            self.appName = name
            self.bundleID = bid
        } else {
            self.appName = "None"
            self.bundleID = ""
        }
    }

    public func activeApp(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            // lol
        }) {
            HStack(spacing: 0) {
                Text(appName)
                    .foregroundColor(.white)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .fixedSize() // текст задаёт ширину HStack
            }
            .frame(minWidth: width) // минимальная ширина
            .frame(height: height)
            .background(.clear)
            .padding(.horizontal, 16)
            .glassEffect() // применяем к HStack
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

}