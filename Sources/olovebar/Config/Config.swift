import Foundation
import TOMLKit
import MacroAPI

@LogFunctions(.Config)
public final class Config: ObservableObject {
    private var path: String
    private var data: TOMLTable?
    
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

    // MARK: - Init
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let configPath = home.appendingPathComponent(".config/olovebar/olovebar.toml").path
        self.path = configPath
        load()
    }

    // MARK: - Load
    private func load() {
        guard FileManager.default.fileExists(atPath: path) else {
            debug("⚠️ Config not found at \(path)")
            return
        }

        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let table = try TOMLTable(string: content)
            self.data = table
            info("✅ Config loaded from \(path), \(String(describing: self.data))")
            load_window()
            load_widget()
        } catch {
            warn("❌ Failed to parse TOML: \(error)")
        }
    }


    private func section(_ name: String) -> TOMLTable? {
        guard let node = data?[name] else {
            warn("Section not found: \(name)")
            return nil
        }
        
        if let table = node.table {
            return table
        } else {
            warn("Section \(name) is not a TOMLTable, got \(type(of: node))")
            return nil
        }
    }

    private func value(_ section: String, _ key: String) -> String? {
        guard let sectionTable = self.section(section) else { return nil }
        guard let node = sectionTable[key] else { return nil }
        
        return node.string ?? node.int.map { String($0) } ?? node.double.map { String($0) }
    }


    private func load_window() {
        load_section(
            name: "window",
            doubles: [
                ("bar_height", { self.barHeight = CGFloat($0) }),
                ("bar_horizontal_cut", { self.barHorizontalCut = CGFloat($0) }),
                ("bar_vertical_cut", { self.barVerticalCut = CGFloat($0) }),
                ("corner_radius", { self.windowCornerRadius = CGFloat($0) })
            ],
            ints: [
                ("glass_variant", { self.windowGlassVariant = $0 })
            ]
        )
    }


    private func load_widget() {
        load_section(
            name: "widget",
            doubles: [
                ("apple_button_width", { self.appleLogoWidth = CGFloat($0) }),
                ("aerospace_width", { self.aerospaceWidth = CGFloat($0) }),
                ("active_app_width", { self.activeAppWidth = CGFloat($0) }),
                ("time_button_width", { self.dateTimeWidth = CGFloat($0) }),
                ("widget_height", { self.widgetHeight = CGFloat($0) }),
                ("corner_radius", { self.widgetCornerRadius = CGFloat($0) }),
                ("wifi_width", { self.wifiWidth = CGFloat($0) }),
                ("battery_width", { self.batteryWidth = CGFloat($0) }),
                ("language_width", { self.languageWidth = CGFloat($0) }),
                ("volume_width", { self.volumeWidth = CGFloat($0) }),
                ("right_spacing", { self.rightSpacing = CGFloat($0) }),
                ("left_spacing", { self.leftSpacing = CGFloat($0) })
            ],
            ints: [
                ("glass_variant", { self.widgetGlassVariant = $0 })
            ]
        )
    }



    private func load_section(
        name: String,
        doubles: [(key: String, assign: (Double) -> Void)] = [],
        ints: [(key: String, assign: (Int) -> Void)] = []
    ) {
        info("Loading Sections")
        for (key, assign) in doubles {
            if let value = value(name, key) {
                debug("Value 1: \(value)")
                if let value: Double = Double(value) {
                    debug("Value 2: \(value)")
                    assign(value)
                    info("Loaded \(name).\(key) = \(value)")
                } else {
                    warn("NOT LOADED: \(name).\(key)")
                }
            }
        }
        
        for (key, assign) in ints {
            if let value = value(name, key) {
                debug("Value 11: \(value)")
                if let value: Int = Int(value) {
                    debug("Value 22: \(value)")
                    assign(value)
                    info("Loaded \(name).\(key) = \(value)")
                } else {
                    warn("NOT LOADED: \(name).\(key)")
                }
            }
        }
    }

    
    public func save() {
        let snapshot = (
            path: path,
            barHeight: barHeight,
            barHorizontalCut: barHorizontalCut,
            barVerticalCut: barVerticalCut,
            windowCornerRadius: windowCornerRadius,
            windowGlassVariant: windowGlassVariant,
            appleLogoWidth: appleLogoWidth,
            aerospaceWidth: aerospaceWidth,
            activeAppWidth: activeAppWidth,
            dateTimeWidth: dateTimeWidth,
            widgetHeight: widgetHeight,
            widgetCornerRadius: widgetCornerRadius,
            wifiWidth: wifiWidth,
            batteryWidth: batteryWidth,
            languageWidth: languageWidth,
            volumeWidth: volumeWidth,
            rightSpacing: rightSpacing,
            leftSpacing: leftSpacing,
            widgetGlassVariant: widgetGlassVariant
        )

        DispatchQueue.global(qos: .utility).async {
            let root = TOMLTable()

            // MARK: - Window section
            let window: TOMLTable = [
                "bar_height": Double(snapshot.barHeight),
                "bar_horizontal_cut": Double(snapshot.barHorizontalCut),
                "bar_vertical_cut": Double(snapshot.barVerticalCut),
                "corner_radius": Double(snapshot.windowCornerRadius),
                "glass_variant": snapshot.windowGlassVariant
            ]
            root["window"] = window

            // MARK: - Widget section
            let widget: TOMLTable = [
                "apple_button_width": Double(snapshot.appleLogoWidth),
                "aerospace_width": Double(snapshot.aerospaceWidth),
                "active_app_width": Double(snapshot.activeAppWidth),
                "time_button_width": Double(snapshot.dateTimeWidth),
                "widget_height": Double(snapshot.widgetHeight),
                "corner_radius": Double(snapshot.widgetCornerRadius),
                "wifi_width": Double(snapshot.wifiWidth),
                "battery_width": Double(snapshot.batteryWidth),
                "language_width": Double(snapshot.languageWidth),
                "volume_width": Double(snapshot.volumeWidth),
                "right_spacing": Double(snapshot.rightSpacing),
                "left_spacing": Double(snapshot.leftSpacing),
                "glass_variant": snapshot.widgetGlassVariant
            ]
            root["widget"] = widget

            // Serialize
            let tomlString = root.convert()

            do {
                let dir = (snapshot.path as NSString).deletingLastPathComponent
                if !FileManager.default.fileExists(atPath: dir) {
                    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                }

                try tomlString.write(toFile: snapshot.path, atomically: true, encoding: .utf8)

                Utilities.info("💾 Config saved to \(snapshot.path)", module: .Config, file: #file, function: #function, line: #line)
            } catch {
                Utilities.warn("❌ Failed to save config: \(error)", module: .Config, file: #file, function: #function, line: #line)
            }
        }
    }
}
