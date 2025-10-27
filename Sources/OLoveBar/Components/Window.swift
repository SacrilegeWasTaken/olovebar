import AppKit
import SwiftUI

protocol WindowMarker: NSWindow {}

class NotchWindowState: ObservableObject {
    @Published var isExpanded = false
}

class NotchWindow: NSWindow, WindowMarker {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    let state = NotchWindowState()
    private var collapsedFrame: NSRect?
    private var expandedFrame: NSRect?
    private nonisolated(unsafe) var isAnimating = false
    
    func setupHoverTracking(collapsedFrame: NSRect, expandedFrame: NSRect) {
        self.collapsedFrame = collapsedFrame
        self.expandedFrame = expandedFrame
        
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView?.addTrackingArea(trackingArea)
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        guard !state.isExpanded, !isAnimating, let expanded = expandedFrame else { return }
        state.isExpanded = true
        animateFrame(to: expanded)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard state.isExpanded, !isAnimating, let collapsed = collapsedFrame else { return }
        state.isExpanded = false
        animateFrame(to: collapsed)
    }
    
    private func animateFrame(to newFrame: NSRect) {
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: false)
        }, completionHandler: {
            self.isAnimating = false
        })
    }
}

class OLoveBarWindow: NSWindow, WindowMarker {
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

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = color
        container.layer?.isOpaque = false
        container.layer?.cornerRadius = config.windowCornerRadius
        container.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: view()
                                            .frame(maxWidth: .infinity, maxHeight: .infinity))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)

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

@MainActor
func setupNotchWindow<Content: View>(
    frame: NSRect, 
    config: Config, 
    level: NSWindow.Level,
    _ color: CGColor = .clear, 
    @ViewBuilder view: @escaping (NotchWindowState) -> Content
    ) -> NotchWindow 
    {
        let window = NotchWindow(
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

        let container = NSView(frame: frame)
        container.wantsLayer = true
        container.layer?.backgroundColor = color
        container.layer?.isOpaque = false
        container.layer?.cornerRadius = config.windowCornerRadius
        container.layer?.masksToBounds = true

        let hostingView = NSHostingView(rootView: view(window.state)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingView)

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