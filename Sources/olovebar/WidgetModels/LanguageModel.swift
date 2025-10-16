import Foundation
import SwiftUI
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.languageModel]))
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
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func update() {
        let script = "osascript -e 'tell application \"System Events\" to get name of first input source whose selected is true'"
        let out = self.run(script)
        self.current = out.isEmpty ? "EN" : out
    }

    func toggle() {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = "osascript -e 'tell application \"System Events\" to select (first input source whose selected is false)'"
            let task = Process()
            let pipe = Pipe()
            task.standardError = Pipe()
            task.standardOutput = pipe
            task.arguments = ["-c", script]
            task.launchPath = "/bin/zsh"
            do { try task.run(); task.waitUntilExit() } catch {}
            Thread.sleep(forTimeInterval: 0.2)
            DispatchQueue.main.async { [weak self] in
                self?.update()
            }
        }
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