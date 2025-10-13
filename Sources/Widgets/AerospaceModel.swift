import Foundation
import SwiftUI

@MainActor
public final class AerospaceModel: ObservableObject {
    public init() {}
    @Published var workspaces: [String] = []
    @Published var focused: String?
    
    @Namespace private var aerospaceNamespace 
    @State private var isSingleShape: Bool = true
    var timer: Timer?

    func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        updateData()
        // Use selector-based timer to avoid Sendable capture issues
        timer = Timer.scheduledTimer(timeInterval: interval, target: self, selector: #selector(timerTick(_:)), userInfo: nil, repeats: true)
    }

    @objc private func timerTick(_ t: Timer) {
        updateData()
    }


    private func runCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func updateData() {
        let all = runCommand("aerospace list-workspaces --all")
        let focused = runCommand("aerospace list-workspaces --focused")
        DispatchQueue.main.async {
            self.workspaces = all.components(separatedBy: .newlines).filter { !$0.isEmpty }
            self.focused = focused
        }
    }

    func focus(_ id: String) {
        DispatchQueue.main.async {
            _ = self.runCommand("aerospace workspace \(id)")
        }
    }

    public func aerospaceWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        GlassEffectContainer {            
            HStack(spacing: 4) { 
                ForEach(self.workspaces, id: \.self) { id in
                    Button(action: {
                        withAnimation {
                            self.isSingleShape.toggle()
                            self.focus(id)
                        }
                    }) {
                        Text(id)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: width, height: height)
                            .foregroundColor(.white)
                            .background(.clear)
                            .glassEffect(id == self.focused ? .clear.tint(.orange) : .clear)
                            .glassEffectID(id, in: self.aerospaceNamespace)
                    }
                    .background(.clear)
                    .cornerRadius(cornerRadius)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .animation(.easeInOut(duration: 0.15), value: self.focused)
                }
            }
            .padding(.horizontal, 26)
            .frame(height: height)
            .onAppear {
                self.startTimer(interval: 0.1) // запускаем обновление каждые 0.1 сек
            }
        }
    }
}