import AppKit
import SwiftUI

class OLoveBarWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
func setupWindow<Content: View>(
    frame: NSRect, 
    config: Config, 
    level: NSWindow.Level,
    _ color: CGColor = .clear, 
    @ViewBuilder view: @escaping () -> Content
    ) -> OLoveBarWindow 
    {
        let window = OLoveBarWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = level
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.hasShadow = false
        window.orderBack(nil)
        print()

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = color
        // ensure container's layer is not opaque so alpha can show through
        container.layer?.isOpaque = false
        container.layer?.cornerRadius = config.windowCornerRadius
        container.layer?.masksToBounds = true

        // Host a SwiftUI view inside AppKit
        let hostingView = NSHostingView(rootView: view()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)

        // Constrain hosting view to container
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: container.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        window.contentView = container
        window.makeKeyAndOrderFront(nil)
        return window
}