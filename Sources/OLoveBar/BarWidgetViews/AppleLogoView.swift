import SwiftUI
import AppKit
import TOMLKit
import MacroAPI

// MARK: - AppleLogoWidgetView

@LogFunctions(.Widgets([.appleLogoModel]))
struct AppleLogoWidgetView: View {
    @ObservedObject var config:         Config
    @ObservedObject var controller:     ConfigWindowController
    @Binding        var themeToggle:    Bool


    @ObservedObject var model = GlobalModels.shared.appleLogoModel


    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Button(action: {
                themeToggle.toggle()
            }) {
                Image(systemName: "apple.logo")
                    .frame(width: config.appleLogoWidth, height: config.widgetHeight)
                    .foregroundColor(.white)
                    .background(.clear)
                    .font(.system(size: 15, weight: .semibold))
                    .cornerRadius(config.widgetCornerRadius)
            }
            .buttonStyle(.plain)
            .background(.clear)
            .frame(width: config.appleLogoWidth, height: config.widgetHeight)
            .cornerRadius(config.widgetCornerRadius)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
            .contextMenu {
                Button("Settings") {
                    controller.show()
                }
                Button("Quit OLoveBar") {
                    DispatchQueue.main.async {
                        NSApplication.shared.terminate(nil)
                    }
                }
            }
        }
    }
}

// MARK: - Config Editor View

fileprivate struct ConfigEditorView: View {
    @ObservedObject var controller: ConfigWindowController
    @ObservedObject var config: Config
    @State private var selectedTab = 0

    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: 16
        ) {
            ZStack {
                DragWindowArea()
                VStack(spacing: 0) {
                    ZStack {
                        HStack {
                            Text("OLoveBar")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            Button(action: { controller.close() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }                
                        Picker("", selection: $selectedTab) {
                            Text("Window").tag(0).glassEffect()
                            Text("Widgets").tag(1).glassEffect()
                        }
                    }
                    .padding(20)
                    
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if selectedTab == 0 {
                                SettingsSection(title: "Window") {
                                    GlassStepper(title: "Height", value: $config.barHeight, range: 20...80)
                                    GlassStepper(title: "Horizontal Padding", value: $config.barHorizontalCut, range: 0...50)
                                    GlassStepper(title: "Vertical Padding", value: $config.barVerticalCut, range: 0...50)
                                    GlassStepper(title: "Corner Radius", value: $config.windowCornerRadius, range: 0...40)
                                    GlassStepper(title: "Glass Variant", value: $config.windowGlassVariant, range: 0...19)
                                }
                            } else {
                                SettingsSection(title: "Appearance") {
                                    GlassStepper(title: "Glass Variant", value: $config.widgetGlassVariant, range: 0...19)
                                    GlassStepper(title: "Height", value: $config.widgetHeight, range: 20...60)
                                    GlassStepper(title: "Corner Radius", value: $config.widgetCornerRadius, range: 0...40)
                                }
                                
                                SettingsSection(title: "Widget Widths") {
                                    GlassStepper(title: "Apple Logo", value: $config.appleLogoWidth, range: 20...100)
                                    GlassStepper(title: "Aerospace", value: $config.aerospaceWidth, range: 20...100)
                                    GlassStepper(title: "Active App", value: $config.activeAppWidth, range: 20...100)
                                    GlassStepper(title: "Date & Time", value: $config.dateTimeWidth, range: 50...250)
                                    GlassStepper(title: "WiFi", value: $config.wifiWidth, range: 20...150)
                                    GlassStepper(title: "Battery", value: $config.batteryWidth, range: 20...150)
                                    GlassStepper(title: "Language", value: $config.languageWidth, range: 20...100)
                                    GlassStepper(title: "Volume", value: $config.volumeWidth, range: 20...100)
                                }
                                
                                SettingsSection(title: "Spacing") {
                                    GlassStepper(title: "Right", value: $config.rightSpacing, range: 0...50)
                                    GlassStepper(title: "Left", value: $config.leftSpacing, range: 0...50)
                                }
                            }
                        }
                        .padding(20)
                    }
                    
                    HStack {
                        Spacer()
                        LiquidGlassButton(title: "Save", width: 120, height: 32, action: config.save)
                    }
                    .padding(20)
                }
                .frame(width: 480, height: 640)
            }
        }
    }
}

fileprivate struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .padding(.leading, 4)
            
            VStack(spacing: 1) {
                content
            }
        }
    }
}

@MainActor
final class ConfigWindowController: ObservableObject {
    @ObservedObject var config: Config
    private var window: NSWindow?

    public init(config: Config) {
        self.config = config
    }

    public func show() {
        if window != nil {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = ConfigEditorView(controller: self, config: config)
        let hosting = NSHostingController(rootView: view)

        let win = NSWindow(contentViewController: hosting)
        win.styleMask = [.closable, .fullSizeContentView]
        win.isOpaque = false
        win.backgroundColor = .clear
        win.hasShadow = true
        win.level = .floating
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.window = win
    }

    func close() {
        window?.close()
        window = nil
    }
}

fileprivate struct GlassStepper<Value: Strideable>: View where Value.Stride: SignedNumeric {
    let title: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value.Stride

    init(title: String, value: Binding<Value>, range: ClosedRange<Value>, step: Value.Stride = 1) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
    }

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: decrement) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                
                Text(formattedValue())
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(minWidth: 32)
                
                Button(action: increment) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    private func formattedValue() -> String {
        if let intValue = value as? Int {
            return "\(intValue)"
        } else if let doubleValue = value as? Double {
            return String(format: "%.1f", doubleValue)
        } else if let cgFloatValue = value as? CGFloat {
            return String(format: "%.1f", Double(cgFloatValue))
        } else {
            return "\(value)"
        }
    }

    private func increment() {
        let newValue = value.advanced(by: step)
        value = min(newValue, range.upperBound)
    }

    private func decrement() {
        let newValue = value.advanced(by: -step)
        value = max(newValue, range.lowerBound)
    }
}
