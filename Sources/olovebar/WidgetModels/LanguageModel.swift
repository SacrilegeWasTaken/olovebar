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
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
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
        guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return }
        
        guard let sourceList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource] else { return }
        
        let enabledSources = sourceList.filter { source in
            guard let isEnabled = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsEnabled),
                  Unmanaged<CFBoolean>.fromOpaque(isEnabled).takeUnretainedValue() == kCFBooleanTrue,
                  let category = TISGetInputSourceProperty(source, kTISPropertyInputSourceCategory) else {
                return false
            }
            let cat = Unmanaged<CFString>.fromOpaque(category).takeUnretainedValue() as String
            return cat == kTISCategoryKeyboardInputSource as String
        }
        
        guard enabledSources.count > 1,
              let currentIndex = enabledSources.firstIndex(where: { $0 == currentSource }) else { return }
        
        let nextIndex = (currentIndex + 1) % enabledSources.count
        TISSelectInputSource(enabledSources[nextIndex])
    }
}
