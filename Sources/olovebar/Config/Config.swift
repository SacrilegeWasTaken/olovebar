import Foundation
import TOMLKit
import MacroAPI

@LogFunctions(.Config)
public final class Config {


    private var path: String
    private var data: TOMLTable?
    // Configurable
    public private(set) var barHeight: CGFloat = 35
    public private(set) var barHorizontalCut: CGFloat = 10
    public private(set) var barVerticalCut: CGFloat = 2
    // Unconfigurable
    public let appleButtonWidth: CGFloat = 45
    public let timeButtonWidth: CGFloat = 190
    public let widgetHeight: CGFloat = 33
    public let cornerRadius: CGFloat = 16
    public let wifiWidth: CGFloat = 90
    public let batteryWidth: CGFloat = 70
    public let languageWidth: CGFloat = 35
    public let volumeWidth: CGFloat = 48
    public let glassVariant: Int = 48


    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".config/olovebar/olovebar.toml").path
        self.path = configPath
        load()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: path) else {
            debug("⚠️ Config not found at \(path)")
            return
        }

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let table = try TOMLTable(string: content)
            self.data = table
            info("✅ Config loaded from \(path)")
        } catch {
            warn("❌ Failed to parse TOML: \(error)")
            return
        }


    }

    private func value<T>(_ key: String) -> T? {
        data?[key] as? T
    }
}
