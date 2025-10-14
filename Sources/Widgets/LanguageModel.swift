import Foundation
import SwiftUI
import MacroAPI

@MainActor
public class LanguageModel: ObservableObject {
    @Published var current: String = "EN"

    public init() {
        update()
    }

    private func run(_ cmd: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", cmd]
        task.launchPath = "/bin/zsh"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func update() {
        // Try to get current input source using AppleScript
        let script = "osascript -e 'tell application \"System Events\" to get name of first input source whose selected is true'"
        let out = run(script)
        self.current = out.isEmpty ? "EN" : out
    }

    func toggle() {
        // Switch to the next input source using AppleScript
        let script = "osascript -e 'tell application \"System Events\" to select (first input source whose selected is false)'"
        // run synchronously (quick) and update
        let task = Process()
        let pipe = Pipe()
        task.standardError = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", script]
        task.launchPath = "/bin/zsh"
        task.launch()
        _ = pipe.fileHandleForReading.readDataToEndOfFile()
        Thread.sleep(forTimeInterval: 0.2)
        update()
    }

    public func languageWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            self.toggle()
        }) {
            Text(self.current)
                .foregroundColor(.white)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: width, height: height)
                .glassEffect()
        }
        .background(.clear)
        .cornerRadius(cornerRadius)
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { self.update() }
    }
}