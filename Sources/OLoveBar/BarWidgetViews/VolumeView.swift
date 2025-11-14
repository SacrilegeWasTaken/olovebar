import SwiftUI
import MacroAPI
import AVFoundation

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
            Image(systemName: "speaker.wave.3.fill")
                .foregroundColor(.white)
        }
    }
}

@LogFunctions(.Widgets([.volumeModel]))
struct VolumeWidgetView: View {
    @ObservedObject var config: Config
    @ObservedObject var model = GlobalModels.shared.volumeModel
    @State private var widgetFrame: CGRect = .zero
    @State private var cachedMenu: NSMenu? = nil

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
                }
            }
        )
    }
    
    private func showVolumeMenu() {
        guard let window = NSApp.windows.first(where: { $0 is OLoveBarWindow }),
              let contentView = window.contentView else { return }
        
        // Создаём меню только один раз
        if cachedMenu == nil {
            cachedMenu = Menu.buildNSMenu(from: menuItems())
        }
        
        guard let menu = cachedMenu else { return }
        
        // Вычисляем позицию меню по центру виджета
        let menuWidth: CGFloat = 320
        let widgetCenterX = widgetFrame.midX
        let menuX = widgetCenterX - (menuWidth / 2)
        let menuY: CGFloat = -10
        
        let point = CGPoint(x: menuX, y: menuY)
        menu.popUp(positioning: nil, at: point, in: contentView)
    }
    
    private func menuItems() -> [MenuItem] {
        var items: [MenuItem] = []
        
        // Заголовок
        items.append(MenuItem(view: 
            Text("Sound")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
        ))
        
        // Слайдер громкости
        items.append(MenuItem(view:
            VolumeSliderView(model: model)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        ))
        
        items.append(.separator)
        
        // Заголовок Output
        items.append(MenuItem(view:
            Text("Output")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)
        ))
        
        // Устройства вывода
        for device in model.outputDevices {
            items.append(MenuItem(view:
                Button {
                    model.setOutputDevice(device.id)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: deviceIcon(for: device.name))
                            .frame(width: 20)
                        Text(device.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if device.id == model.currentDeviceID {
                            Image(systemName: "checkmark")
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(height: config.widgetHeight - 10)
                }
                .buttonStyle(.plain)
            ))
        }
        
        items.append(.separator)
        
        // Настройки звука
        items.append(MenuItem(title: "Sound Settings", action: {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.sound")!)
        }))
        
        return items
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