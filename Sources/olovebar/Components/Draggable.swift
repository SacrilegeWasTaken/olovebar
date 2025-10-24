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
private final class MouseDragView: NSView {
    private var initialLocation: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        guard let window = self.window else { return }

        // Click location on a window
        let windowFrame = window.frame
        let clickLocation = window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin
        initialLocation = NSPoint(x: clickLocation.x - windowFrame.origin.x,
                                  y: clickLocation.y - windowFrame.origin.y)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = self.window else { return }

        // Cursor location on a screen
        let screenLocation = window.convertToScreen(NSRect(origin: event.locationInWindow, size: .zero)).origin

        // new window origin
        var newOrigin = NSPoint(x: screenLocation.x - initialLocation.x,
                                y: screenLocation.y - initialLocation.y)

        // Movement bounds
        if let screen = window.screen {
            let visibleFrame = screen.visibleFrame
            newOrigin.x = max(visibleFrame.minX, min(newOrigin.x, visibleFrame.maxX - window.frame.width))
            newOrigin.y = max(visibleFrame.minY, min(newOrigin.y, visibleFrame.maxY - window.frame.height))
        }

        window.setFrameOrigin(newOrigin)
    }
}
