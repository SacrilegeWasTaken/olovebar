import SwiftUI
import MacroAPI
import AVFoundation
import Combine

struct VolumeSliderView: View {
    @ObservedObject var model: VolumeModel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "speaker.slash.fill")
                .foregroundColor(.white)
            Slider(value: Binding(
                get: { Double(model.level ?? 0) },
                set: { val in
                    if model.isMuted && val > 0 {
                        model.setMuted(false)
                    }
                    model.setVolume(Float(val))
                }
            ), in: 0...1)
                .frame(width: 260)
                .fixedSize() // Фиксируем размер слайдера
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.white)
        }
        .frame(width: 300, alignment: .center) // Фиксируем ширину всего контейнера
        .fixedSize(horizontal: true, vertical: true) // Предотвращаем изменение размера
    }
}

@LogFunctions(.Widgets([.volumeModel]))
struct VolumeWidgetView: View {
    @ObservedObject var config: Config
    @ObservedObject var model = GlobalModels.shared.volumeModel
    @State private var widgetFrame: CGRect = .zero

    var body: some View {
        Button(action: { showVolumeMenu() }) {
            var image = switch Double(model.level) {
                case 0:
                    "speaker.slash.fill"
                case 0.00000001..<0.33:
                    "speaker.wave.1.fill"
                case 0.33..<0.77:
                    "speaker.wave.2.fill"
                default:
                    "speaker.wave.3.fill"
            }
            if model.isMuted {
                let _ = image = "speaker.slash.fill"
            }
            Image(systemName: image)
                .foregroundColor(.white)
                .frame(width: config.volumeWidth, height: config.widgetHeight)
                .background(
                    LiquidGlassBackground(
                        variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
                        cornerRadius: config.widgetCornerRadius
                    ) {}
                )
                .cornerRadius(config.widgetCornerRadius)
                .contentShape(Rectangle())
                .animation(.easeInOut(duration: 0.3), value: image)
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    widgetFrame = geo.frame(in: .global)
                }.onChange(of: geo.frame(in: .global)) {
                    widgetFrame = geo.frame(in: .global)
                }
            }
        )
    }
    
    private func showVolumeMenu() {
        guard let window = NSApp.windows.first(where: { $0 is OLoveBarWindow }),
              let contentView = window.contentView else { return }
        
        // Создаём чистое AppKit меню
        let menu = VolumeMenuView.createMenu(model: model, config: config)

        // Вычисляем позицию: центр виджета по X, чуть ниже по Y
        let menuWidth: CGFloat = 320
        let widgetCenterX = widgetFrame.midX
        let menuX = widgetCenterX - (menuWidth / 2)
        let menuY: CGFloat = -12 // Чуть ниже виджета
        
        let point = CGPoint(x: menuX, y: menuY)
        menu.popUp(positioning: nil, at: point, in: contentView)
    }
    
    private func deviceIcon(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("airpods pro") {
            return "airpodspro"
        } else if lowercased.contains("airpods max") {
            return "airpodsmax"
        } else if lowercased.contains("airpods") {
            return "airpods"
        } else if lowercased.contains("macbook") || lowercased.contains("built-in") {
            return "laptopcomputer"
        } else if lowercased.contains("bluetooth") || lowercased.contains("headphone") {
            return "headphones"
        } else {
            return "speaker.wave.2"
        }
    }
}


import AppKit
import AVFoundation

/// Чистая AppKit реализация меню громкости без SwiftUI
@MainActor
final class VolumeMenuView {
    
    static func createMenu(model: VolumeModel, config: Config) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        // Заголовок "Sound"
        let titleItem = NSMenuItem()
        titleItem.view = createTitleView(text: "Sound")
        menu.addItem(titleItem)
        
        // Слайдер громкости
        let sliderItem = NSMenuItem()
        sliderItem.view = createVolumeSlider(model: model)
        menu.addItem(sliderItem)
        
        menu.addItem(.separator())
        
        // Заголовок "Output"
        let outputTitleItem = NSMenuItem()
        outputTitleItem.view = createTitleView(text: "Output")
        menu.addItem(outputTitleItem)
        
        // Устройства вывода
        for device in model.outputDevices {
            let deviceItem = NSMenuItem()
            deviceItem.view = createDeviceView(
                device: device,
                isSelected: device.id == model.currentDeviceID,
                model: model,
                config: config
            )
            menu.addItem(deviceItem)
        }
        
        menu.addItem(.separator())
        
        // Sound Settings
        let settingsItem = NSMenuItem(
            title: "Sound Settings",
            action: #selector(VolumeMenuTarget.openSettings),
            keyEquivalent: ""
        )
        let target = VolumeMenuTarget()
        settingsItem.target = target
        objc_setAssociatedObject(settingsItem, "target", target, .OBJC_ASSOCIATION_RETAIN)
        menu.addItem(settingsItem)
        
        return menu
    }
    
    private static func createTitleView(text: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 10, width: 320, height: 20))
        
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.frame = NSRect(x: 12, y: -2, width: 296, height: 16)
        
        container.addSubview(label)
        return container
    }
    
    private static func createVolumeSlider(model: VolumeModel) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 32))
        
        // Иконка слева
        let leftIcon = NSImageView(frame: NSRect(x: 12, y: 8, width: 16, height: 16))
        leftIcon.image = NSImage(systemSymbolName: "speaker.slash.fill", accessibilityDescription: nil)
        leftIcon.contentTintColor = .labelColor
        
        // Слайдер
        let slider = NSSlider(frame: NSRect(x: 36, y: 8, width: 248, height: 16))
        slider.minValue = 0
        slider.maxValue = 1
        slider.doubleValue = Double(model.level ?? 0)
        slider.isContinuous = true
        
        // Скругление слайдера
        slider.wantsLayer = true
        slider.layer?.cornerRadius = 6
        
        let sliderTarget = VolumeSliderTarget(model: model, slider: slider)
        slider.target = sliderTarget
        slider.action = #selector(VolumeSliderTarget.sliderChanged(_:))
        objc_setAssociatedObject(slider, "target", sliderTarget, .OBJC_ASSOCIATION_RETAIN)
        
        // Иконка справа
        let rightIcon = NSImageView(frame: NSRect(x: 292, y: 8, width: 16, height: 16))
        rightIcon.image = NSImage(systemSymbolName: "speaker.wave.3.fill", accessibilityDescription: nil)
        rightIcon.contentTintColor = .labelColor
        
        container.addSubview(leftIcon)
        container.addSubview(slider)
        container.addSubview(rightIcon)
        
        return container
    }
    
    private static func createDeviceView(
        device: AudioDevice,
        isSelected: Bool,
        model: VolumeModel,
        config: Config
    ) -> NSView {
        let height = config.widgetHeight - 10
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: height))
        
        let button = NSButton(frame: container.bounds)
        button.isBordered = false
        button.bezelStyle = .rounded
        button.title = ""
        
        // Иконка устройства
        let iconName = deviceIcon(for: device.name)
        let icon = NSImageView(frame: NSRect(x: 12, y: (height - 16) / 2, width: 20, height: 16))
        icon.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        icon.contentTintColor = .labelColor
        
        // Название устройства
        let label = NSTextField(labelWithString: device.name)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.frame = NSRect(x: 40, y: (height - 16) / 2, width: 240, height: 16)
        
        container.addSubview(icon)
        container.addSubview(label)
        
        // Чекмарк если выбран
        if isSelected {
            let checkmark = NSImageView(frame: NSRect(x: 288, y: (height - 16) / 2, width: 20, height: 16))
            checkmark.image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)
            checkmark.contentTintColor = .labelColor
            container.addSubview(checkmark)
        }
        
        // Кликабельность
        let clickTarget = DeviceClickTarget(deviceID: device.id, model: model)
        let clickGesture = NSClickGestureRecognizer(target: clickTarget, action: #selector(DeviceClickTarget.clicked))
        container.addGestureRecognizer(clickGesture)
        objc_setAssociatedObject(container, "clickTarget", clickTarget, .OBJC_ASSOCIATION_RETAIN)
        
        // Подсветка при наведении
        container.addTrackingArea(NSTrackingArea(
            rect: container.bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp],
            owner: container,
            userInfo: nil
        ))
        
        return container
    }
    
    private static func deviceIcon(for name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("airpods pro") {
            return "airpodspro"
        } else if lowercased.contains("airpods max") {
            return "airpodsmax"
        } else if lowercased.contains("airpods") {
            return "airpods"
        } else if lowercased.contains("macbook") || lowercased.contains("built-in") {
            return "laptopcomputer"
        } else if lowercased.contains("bluetooth") || lowercased.contains("headphone") {
            return "headphones"
        } else {
            return "speaker.wave.2"
        }
    }
}

// MARK: - Targets

private class VolumeSliderTarget: NSObject {
    let model: VolumeModel
    weak var slider: NSSlider?
    private var cancellable: AnyCancellable?
    
    @MainActor
    init(model: VolumeModel, slider: NSSlider) {
        self.model = model
        self.slider = slider
        super.init()
        
        // Подписываемся на изменения model.level для реактивного обновления слайдера
        self.cancellable = model.$level.sink { [weak slider] newValue in
            Task { @MainActor in
                if let newValue = newValue {
                    slider?.doubleValue = Double(newValue)
                }
            }
        }
    }
    
    @MainActor
    @objc func sliderChanged(_ slider: NSSlider) {
        let value = Float(slider.doubleValue)
        if model.isMuted && value > 0 {
            model.setMuted(false)
        }
        model.setVolume(value)
    }
}

private class DeviceClickTarget: NSObject {
    let deviceID: AudioDeviceID
    let model: VolumeModel
    
    init(deviceID: AudioDeviceID, model: VolumeModel) {
        self.deviceID = deviceID
        self.model = model
    }
    
    @MainActor
    @objc func clicked() {
        model.setOutputDevice(deviceID)
    }
}

private class VolumeMenuTarget: NSObject {
    @objc func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.sound")!)
    }
}
