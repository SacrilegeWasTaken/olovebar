import SwiftUI
import MacroAPI
import AVFoundation

@LogFunctions(.Widgets([.volumeModel]))
struct VolumeWidgetView: View {
    @ObservedObject var model: VolumeModel
    @ObservedObject var config: Config
    var body: some View {
        LiquidGlassBackground(
            variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
            cornerRadius: config.widgetCornerRadius
        ) {
            Button(action: { withAnimation { model.isPopoverPresented.toggle() } }) {
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
            .popover(isPresented: Binding(get: { model.isPopoverPresented }, set: { model.isPopoverPresented = $0 })) {
                VStack(spacing: 2.5) {
                    Text("Sound").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12)
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.slash.fill")
                            .frame(height: config.widgetHeight, alignment: .center)
                            .foregroundColor(.white)
                            .cornerRadius(config.widgetCornerRadius)
                        Slider(value: Binding(get: { model.level }, set: { val in model.set_volume(val) }), in: 0...1)
                            .frame(width: 235)
                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundColor(.white)
                            .frame(height: config.widgetHeight)
                            .cornerRadius(config.widgetCornerRadius)
                    }
                    Divider()
                    Text("Output").fontWeight(.semibold).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 12).padding(.top, 6)
                    ForEach(model.outputDevices) { device in
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
                    }
                    Divider()
                    Button {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.sound")!)
                    } label: {
                        Text("Sound Settings")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                    }
                    .buttonStyle(.plain)
                    .frame(height: config.widgetHeight - 10)
                    .padding(.horizontal, 8)
                }
                .frame(width: 300)
                .padding(.vertical, 4)
                .padding(.top, 6)
            }
        }
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