import Foundation
import TOMLKit
import MacroAPI

@LogFunctions(.Config)
public final class Config {

    public private(set) var path: String
    public private(set) var data: TOMLTable?

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
        }
    }

    /// Достаём значение по ключу
    public func value<T>(_ key: String) -> T? {
        data?[key] as? T
    }
}
