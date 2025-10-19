import Foundation
import SwiftUI
import MacroAPI
import Carbon

@MainActor
@LogFunctions(.Widgets([.languageModel]))
public class LanguageModel: ObservableObject {
    @Published var current: String = "EN"
    nonisolated(unsafe) private var timer: Timer?

    public init() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.update()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
    }


    private func update() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
                let languages = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
                DispatchQueue.main.async {
                    self?.current = "EN"
                }
                return
            }
            let langs = Unmanaged<CFArray>.fromOpaque(languages).takeUnretainedValue() as! [String]
            let langCode = langs.first ?? "en"
            DispatchQueue.main.async {
                self?.current = langCode.uppercased()
            }
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
            }
            
            DispatchQueue.main.async {
                self?.update()
            }
        }
    }
}
