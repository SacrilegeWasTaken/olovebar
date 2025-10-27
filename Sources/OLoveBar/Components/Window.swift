import AppKit
import SwiftUI

class OLoveBarWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    private var collapsedFrame: NSRect?
    private var expandedFrame: NSRect?
    private var isExpanded = false
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
        guard !isExpanded, !isAnimating, let expanded = expandedFrame else { return }
        isExpanded = true
        animateFrame(to: expanded)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard isExpanded, !isAnimating, let collapsed = collapsedFrame else { return }
        isExpanded = false
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