import Foundation
import TOMLKit
import MacroAPI

@LogFunctions(.Config)
public final class Config {


    private var path: String
    private var data: TOMLTable?
    // Window Configuration
    public private(set) var barHeight: CGFloat = 35
    public private(set) var barHorizontalCut: CGFloat = 10
    public private(set) var barVerticalCut: CGFloat = 2
    public private(set) var glassVariant: Int = 11
    public private(set) var windowCornerRadius: CGFloat = 16

    // Widget configuration
    public private(set) var appleButtonWidth: CGFloat = 45
    public private(set) var timeButtonWidth: CGFloat = 190
    public private(set) var widgetHeight: CGFloat = 33
    public private(set) var widgetCornerRadius: CGFloat = 16
    public private(set) var wifiWidth: CGFloat = 90
    public private(set) var batteryWidth: CGFloat = 70
    public private(set) var languageWidth: CGFloat = 35
    public private(set) var volumeWidth: CGFloat = 48


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
            self.glassVariant = glassVariant
            info("Loaded widget.glass_variant = \(self.glassVariant)")
        }
    }


    private func load_widget() {
        if let appleButtonWidth: Double = value("widget", "apple_button_width") {
            self.appleButtonWidth = CGFloat(appleButtonWidth)
            info("Loaded widget.apple_button_width = \(self.appleButtonWidth)")
        }

        if let timeButtonWidth: Double = value("widget", "time_button_width") {
            self.timeButtonWidth = CGFloat(timeButtonWidth)
            info("Loaded widget.time_button_width = \(self.timeButtonWidth)")
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
