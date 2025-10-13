import SwiftUI

struct BarContentView: View {
    @State private var toggle = false
    @StateObject private var aerospaceModel = AerospaceModel() // ObservableObject для спейсов

    var body: some View {
        let appleButtonWidth: CGFloat = 45
        let timeButtonWidth: CGFloat = 190
        let widgetHeight: CGFloat = 33
        let cornerRadius: CGFloat = 16

        GlassEffectContainer {
            HStack(spacing: 0) {
                // Left: Apple logo
                appleButton(width: appleButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)

                // Aerospace widget
                aerospaceWidget(width: widgetHeight, height: widgetHeight, cornerRadius: cornerRadius)

                Spacer()

                // Right: live-updating clock
                timeButton(width: timeButtonWidth, height: widgetHeight, cornerRadius: cornerRadius)
            }
            //.glassEffect()
        }
    }

    // MARK: - Apple Logo Button
    func appleButton(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        Button(action: {
            self.toggle.toggle()
        }) {
            Image(systemName: "apple.logo")
                .frame(width: width, height: height)
                .foregroundColor(.white)
                .background(.clear)
                .font(.system(size: 15, weight: .semibold))
                .cornerRadius(cornerRadius)
                .glassEffect()
        }
        .frame(width: width, height: height)
        .cornerRadius(cornerRadius)
    }

    // MARK: - Time Button
    func timeButton(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { timeline in
            Button(action: {
                let url = URL(fileURLWithPath: "/System/Applications/Calendar.app")
                NSWorkspace.shared.open(url)
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.white)
                        .background(.clear)
                        .font(.system(size: 12))
                    Text(timeline.date.formatted(date: .abbreviated, time: .standard))
                        .foregroundColor(.white)
                        .background(.clear)
                        .font(.system(size: 12))
                }
                .frame(width: width, height: height)
                .glassEffect()
            }
            .frame(width: width, height: height)
            .cornerRadius(cornerRadius)
        }
    }

    // MARK: - Aerospace Widget
    func aerospaceWidget(width: CGFloat, height: CGFloat, cornerRadius: CGFloat) -> some View {
        HStack(spacing: 4) { 
            ForEach(aerospaceModel.workspaces, id: \.self) { id in
                Button(action: {
                    aerospaceModel.focus(id)
                }) {
                    Text(id)
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: width, height: height)
                        .foregroundColor(.white)
                        .background(.clear)
                        .glassEffect(id == aerospaceModel.focused ? .clear.tint(.orange) : .clear)
                }
                .padding(2)
                .buttonStyle(.plain)
                .animation(.easeInOut(duration: 0.15), value: aerospaceModel.focused)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: height)
        .onAppear {
            aerospaceModel.startTimer(interval: 0.1) // запускаем обновление каждые 0.1 сек
        }
    }
}

// MARK: - Aerospace Model

final class AerospaceModel: ObservableObject {
    @Published var workspaces: [String] = []
    @Published var focused: String?

    private var timer: Timer?

    @MainActor
    func startTimer(interval: TimeInterval) {
        timer?.invalidate()
        updateData()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.updateData()
            }
        }
    }


    private func runCommand(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.arguments = ["-c", command]
        task.launchPath = "/bin/zsh"
        task.launch()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @MainActor
    func updateData() {
        let all = runCommand("aerospace list-workspaces --all")
        let focused = runCommand("aerospace list-workspaces --focused")
        DispatchQueue.main.async {
            self.workspaces = all.components(separatedBy: .newlines).filter { !$0.isEmpty }
            self.focused = focused
        }
    }

    func focus(_ id: String) {
        _ = runCommand("aerospace workspace \(id)")
    }
}
