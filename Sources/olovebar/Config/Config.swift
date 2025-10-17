import Foundation
import TOMLKit
import MacroAPI

@LogFunctions(.Config)
public final class Config: ObservableObject {
    private var path: String
    private var data: TOMLTable?
    // Window Configuration
    // MARK: - Window Configuration
    @Published public var barHeight: CGFloat = 35
    @Published public var barHorizontalCut: CGFloat = 10
    @Published public var barVerticalCut: CGFloat = 2
    @Published public var windowGlassVariant: Int = 12
    @Published public var windowCornerRadius: CGFloat = 16

    // MARK: - Widget Configuration
    @Published public var appleLogoWidth: CGFloat = 45
    @Published public var aerospaceWidth: CGFloat = 33
    @Published public var activeAppWidth: CGFloat = 70
    @Published public var dateTimeWidth: CGFloat = 190
    @Published public var widgetHeight: CGFloat = 33
    @Published public var widgetCornerRadius: CGFloat = 16
    @Published public var wifiWidth: CGFloat = 90
    @Published public var batteryWidth: CGFloat = 70
    @Published public var languageWidth: CGFloat = 48
    @Published public var volumeWidth: CGFloat = 48
    @Published public var rightSpacing: CGFloat = 16
    @Published public var widgetGlassVariant: Int = 11
    @Published public var leftSpacing: CGFloat = 8


    init() {
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
            load_window()
            load_widget()
            info("✅ Config loaded from \(path)")
        } catch {
            warn("❌ Failed to parse TOML: \(error)")
        }


    }


    private func value<T>(_ section: String, _ key: String) -> T? {
        guard
            let sectionTable = data?[section] as? TOMLTable,
            let value = sectionTable[key] as? T
        else { return nil }

        return value
    }


    private func load_window() {
        if let barHeightValue: Double = value("window", "bar_height") {
            self.barHeight = CGFloat(barHeightValue)
            info("Loaded window.bar_height = \(self.barHeight)")
        }

        if let barHorizontalCut: Double = value("window", "bar_horizontal_cut") {
            self.barHorizontalCut = CGFloat(barHorizontalCut)
            info("Loaded window.bar_horizontal_cut = \(self.barHorizontalCut)")
        }

        if let barVerticalCut: Double = value("window", "bar_vertical_cut") {
            self.barVerticalCut = CGFloat(barVerticalCut)
            info("Loaded window.bar_vertical_cut = \(self.barVerticalCut)")
        }

        if let windowCornerRadius: Double = value("window", "bar_vertical_cut") {
            self.windowCornerRadius = CGFloat(windowCornerRadius)
            info("Loaded window.bar_vertical_cut = \(self.windowCornerRadius)")
        }

        if let glassVariant: Int = value("widget", "glass_variant") {
            self.windowGlassVariant = glassVariant
            info("Loaded widget.glass_variant = \(self.windowGlassVariant)")
        }
    }


    private func load_widget() {
        if let appleLogoWidth: Double = value("widget", "apple_button_width") {
            self.appleLogoWidth = CGFloat(appleLogoWidth)
            info("Loaded widget.apple_button_width = \(self.appleLogoWidth)")
        }

        if let dateTimeWidth: Double = value("widget", "time_button_width") {
            self.dateTimeWidth = CGFloat(dateTimeWidth)
            info("Loaded widget.time_button_width = \(self.dateTimeWidth)")
        }

        if let widgetHeight: Double = value("widget", "widget_height") {
            self.widgetHeight = CGFloat(widgetHeight)
            info("Loaded widget.widget_height = \(self.widgetHeight)")
        }

        if let widgetCornerRadius: Double = value("widget", "corner_radius") {
            self.widgetCornerRadius = CGFloat(widgetCornerRadius)
            info("Loaded widget.corner_radius = \(self.widgetCornerRadius)")
        }

        if let wifiWidth: Double = value("widget", "wifi_width") {
            self.wifiWidth = CGFloat(wifiWidth)
            info("Loaded widget.wifi_width = \(self.wifiWidth)")
        }

        if let batteryWidth: Double = value("widget", "battery_width") {
            self.batteryWidth = CGFloat(batteryWidth)
            info("Loaded widget.battery_width = \(self.batteryWidth)")
        }

        if let languageWidth: Double = value("widget", "language_width") {
            self.languageWidth = CGFloat(languageWidth)
            info("Loaded widget.language_width = \(self.languageWidth)")
        }

        if let volumeWidth: Double = value("widget", "volume_width") {
            self.volumeWidth = CGFloat(volumeWidth)
            info("Loaded widget.volume_width = \(self.volumeWidth)")
        }
    }
}
