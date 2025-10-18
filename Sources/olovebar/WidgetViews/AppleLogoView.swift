import SwiftUI
import AppKit
import TOMLKit
import MacroAPI

// MARK: - AppleLogoWidgetView

@LogFunctions(.Widgets([.appleLogoModel]))
struct AppleLogoWidgetView: View {
    @ObservedObject var model: AppleLogoModel
    @ObservedObject var config: Config
    @ObservedObject var controller: ConfigWindowController
    @Binding var theme_toggle: Bool

    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Button(action: {
                theme_toggle.toggle()
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
            }
        }
    }
}

// MARK: - Config Editor View

struct ConfigEditorView: View {
    @ObservedObject var controller: ConfigWindowController
    @ObservedObject var config: Config

    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            ZStack {
                DragWindowArea().frame(width: .infinity, height: .infinity)
                VStack(alignment: .trailing, spacing: 12) {
                    HStack {
                        Text("⚙️ OLoveBar settings")
                            .font(.title2.bold())
                        Spacer()
                        Button(action: { controller.close() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.bottom, 6)
                    Spacer()
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            // Window Configuration
                            GlassStepper(title: "Высота панели", value: $config.barHeight, range: 20...80)
                            GlassStepper(title: "Горизонтальный отступ", value: $config.barHorizontalCut, range: 0...50)
                            GlassStepper(title: "Вертикальный отступ", value: $config.barVerticalCut, range: 0...50)
                            GlassStepper(title: "Радиус углов окна", value: $config.windowCornerRadius, range: 0...40)
                            GlassStepper(title: "Вариант стекла", value: $config.windowGlassVariant, range: 0...19)
                        }

                        VStack(spacing: 4) {
                            // Widget Configuration
                            GlassStepper(title: "Вариант стекла", value: $config.widgetGlassVariant, range: 0...19)
                            GlassStepper(title: "Высота виджета", value: $config.widgetHeight, range: 20...60)
                            GlassStepper(title: "Радиус виджета", value: $config.widgetCornerRadius, range: 0...40)
                            GlassStepper(title: "Ширина логотипа Apple", value: $config.appleLogoWidth, range: 20...100)
                            GlassStepper(title: "Ширина Aerospace", value: $config.aerospaceWidth, range: 20...100)
                            GlassStepper(title: "Ширина ActiveApp", value: $config.activeAppWidth, range: 20...100)
                            GlassStepper(title: "Ширина DateTime", value: $config.dateTimeWidth, range: 50...250)
                            GlassStepper(title: "Ширина WiFi", value: $config.wifiWidth, range: 20...150)
                            GlassStepper(title: "Ширина батареи", value: $config.batteryWidth, range: 20...150)
                            GlassStepper(title: "Ширина языка", value: $config.languageWidth, range: 20...100)
                            GlassStepper(title: "Ширина громкости", value: $config.volumeWidth, range: 20...100)
                            GlassStepper(title: "Правый отступ", value: $config.rightSpacing, range: 0...50)
                            GlassStepper(title: "Левый отступ", value: $config.leftSpacing, range: 0...50)
                        }
                    }
                    LiquidGlassButton(title: "Save", width: 200, height: config.widgetHeight, action: self.config.save)
                }
                .padding(16)
                .frame(width: 600, height: 800)
                .background(.clear)        
            }
            .id(config.widgetGlassVariant + config.windowGlassVariant)
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

struct GlassStepper<Value: Strideable>: View where Value.Stride: SignedNumeric {
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
            Text("\(title): \(formattedValue())")
                .font(.system(.body, weight: .semibold))
            
            Spacer()
            
            HStack(spacing: 6) {
                Button(action: decrement) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                        .glassEffect()
                        .cornerRadius(8)
                }
                
                Button(action: increment) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                        .glassEffect()
                        .cornerRadius(8)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
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
