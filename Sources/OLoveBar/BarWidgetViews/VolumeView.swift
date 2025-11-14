import SwiftUI
import MacroAPI
import AVFoundation

@LogFunctions(.Widgets([.volumeModel]))
struct VolumeWidgetView: View {
    @ObservedObject var config: Config
    @ObservedObject var model = GlobalModels.shared.volumeModel
    @State private var widgetFrame: CGRect = .zero

    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
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
                    .frame(width: config.volumeWidth, height: config.widgetHeight)
                    .foregroundColor(.white)
                    .cornerRadius(config.widgetCornerRadius)
                    .animation(.easeInOut(duration: 0.3), value: image)
            }
            .background(.clear)
            .buttonStyle(.plain)
            .cornerRadius(config.widgetCornerRadius)
            .frame(width: config.volumeWidth, height: config.widgetHeight)
            .clipShape(RoundedRectangle(cornerRadius: config.widgetCornerRadius, style: .continuous))
            .background(
                GeometryReader { geo in
                    Color.clear.onAppear {
                        widgetFrame = geo.frame(in: .global)
                    }
                }
            )
        }
    }
    
    private func showVolumeMenu() {
        guard let window = NSApp.windows.first(where: { $0 is OLoveBarWindow }),
              let contentView = window.contentView else { return }
        
        let menu = Menu.buildNSMenu(from: menuItems())
        
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
            HStack(spacing: 4) {
                Image(systemName: "speaker.slash.fill")
                    .foregroundColor(.white)
                Slider(value: Binding(
                    get: { model.level },
                    set: { val in
                        if model.isMuted && val > 0 {
                            model.setMuted(false)
                            model.isMuted = false
                        }
                        model.setVolume(val)
                    }
                ), in: 0...1)
                    .frame(width: 260)
                Image(systemName: "speaker.wave.3.fill")
                    .foregroundColor(.white)
            }
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