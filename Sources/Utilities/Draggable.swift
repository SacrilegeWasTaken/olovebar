import AppKit
import SwiftUI

public struct DragWindowArea: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> NSView {
        let view = MouseDragView()
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}
}

@MainActor
final class MouseDragView: NSView {
    private var initialLocation: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        // Получаем позицию клика относительно окна
        let windowFrame = window.frame
        let clickLocation = window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        initialLocation = NSPoint(x: clickLocation.x - windowFrame.origin.x,
                                  y: clickLocation.y - windowFrame.origin.y)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }

        // Текущее положение курсора на экране
        let screenLocation = window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin

        // Новая позиция окна — текущее положение минус начальное смещение
        var newOrigin = NSPoint(x: screenLocation.x - initialLocation.x,
                                y: screenLocation.y - initialLocation.y)

        // Немного ограничим движение, чтобы окно не вылетало за экран (опционально)
        if let screen = window.screen {
            let visibleFrame = screen.visibleFrame
            newOrigin.x = max(visibleFrame.minX, min(newOrigin.x, visibleFrame.maxX - window.frame.width))
            newOrigin.y = max(visibleFrame.minY, min(newOrigin.y, visibleFrame.maxY - window.frame.height))
        }

        window.setFrameOrigin(newOrigin)
    }
}
