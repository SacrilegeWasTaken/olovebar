import SwiftUI
import Foundation
import Utilities
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.activeAppModel]))
public class ActiveAppModel: ObservableObject {
    @Published var bundleID: String = ""
    @Published var appName: String = ""

    nonisolated(unsafe) private var timer: Timer?

    public init() {
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    func startTimer() {
        timer?.invalidate()
        update()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.update()
            }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
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

    // UI moved to ActiveAppView in SwiftUI layer

}