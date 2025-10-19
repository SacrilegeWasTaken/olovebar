import Foundation
import SwiftUI
import MacroAPI
import Carbon

@MainActor
@LogFunctions(.Widgets([.languageModel]))
public class LanguageModel: ObservableObject {
    @Published var current: String = "EN"
    nonisolated(unsafe) private var observer: Any?

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
    }

    deinit {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
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
                self?.info("Language: \(langCode.uppercased())")
                self?.current = langCode.uppercased()
            }
        }
    }

    public func toggle() {
        DispatchQueue.global(qos: .userInitiated).async {
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
        }
    }
}
