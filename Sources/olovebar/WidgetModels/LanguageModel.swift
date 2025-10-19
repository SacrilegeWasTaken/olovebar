import Foundation
import SwiftUI
import MacroAPI
import Carbon

@MainActor
@LogFunctions(.Widgets([.languageModel]))
public class LanguageModel: ObservableObject {
    @Published var current: String = "EN"
    nonisolated(unsafe) private var observer: Any?
    nonisolated(unsafe) private var timer: Timer?

    public init() {
        update()
        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleSelectedInputSourcesChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.update()
            }
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.update()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        timer?.invalidate()
    }

    private func update() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let languages = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
            current = "EN"
            return
        }
        let langs = Unmanaged<CFArray>.fromOpaque(languages).takeUnretainedValue() as! [String]
        let langCode = langs.first ?? "en"
        let newLang = langCode.uppercased()
        info("Language: \(newLang)")
        if current != newLang {
            current = newLang
        }
    }

    public func toggle() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
            
            let filter = [kTISPropertyInputSourceIsSelectCapable: true] as CFDictionary
            guard let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else { return }
            
            let enabledSources = sources.filter { source in
                let isSelectable = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsSelectCapable)
                return isSelectable != nil && Unmanaged<CFBoolean>.fromOpaque(isSelectable!).takeUnretainedValue() == kCFBooleanTrue
            }
            
            if let currentIndex = enabledSources.firstIndex(where: { $0 == currentSource }) {
                let nextIndex = (currentIndex + 1) % enabledSources.count
                TISSelectInputSource(enabledSources[nextIndex])
                
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(50))
                    self?.update()
                }
            }
        }
    }
}
