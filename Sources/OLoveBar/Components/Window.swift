import AppKit
import SwiftUI
import Combine

protocol WindowMarker: NSWindow {}


@MainActor
final class NotchWindowState: ObservableObject {
    static let shared = NotchWindowState()

    @Published var isExpanded = false
    @Published var isAnimating = false
    @Published var isHoveringPopover = false
    @Published var preferredContentWidth: CGFloat = 0

    var isFullyExpanded: Bool {
        isExpanded && !isAnimating
    }

    func updatePreferredWidth(_ width: CGFloat) {
        let sanitizedWidth = max(0, width)
        guard abs(preferredContentWidth - sanitizedWidth) > 1 else { return }
        preferredContentWidth = sanitizedWidth
    }
}


final class NotchWindow: NSWindow, WindowMarker {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    let state = NotchWindowState.shared
    private var collapsedFrame: NSRect?
    private var expandedFrame: NSRect?
    private var baseExpandedFrame: NSRect?
    private nonisolated(unsafe) var isAnimating = false
    private var collapseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    override init(
        contentRect: NSRect,
        styleMask style: NSWindow.StyleMask,
        backing backingStoreType: NSWindow.BackingStoreType,
        defer flag: Bool
    ) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        observePreferredWidth()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupHoverTracking(collapsedFrame: NSRect, expandedFrame: NSRect) {
        self.collapsedFrame = collapsedFrame
        self.expandedFrame = expandedFrame
        self.baseExpandedFrame = expandedFrame
        
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
        collapseTimer?.invalidate()
        guard !state.isExpanded, !isAnimating, let expanded = expandedFrame else { return }
        state.isExpanded = true
        animateFrame(to: expanded)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        guard state.isExpanded, !isAnimating else { return }
        
        collapseTimer?.invalidate()
        collapseTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if !self.state.isHoveringPopover, let collapsed = self.collapsedFrame {
                    self.state.isExpanded = false
                    self.animateFrame(to: collapsed)
                }
            }
        }
    }
    
    private func animateFrame(to newFrame: NSRect) {
        state.isAnimating = true 
        isAnimating = true
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.animator().setFrame(newFrame, display: false)
        }, completionHandler: {
            self.isAnimating = false
            Task { @MainActor in
                self.state.isAnimating = false
                self.checkMousePosition()
            }
        })
    }
    
    private func checkMousePosition() {
        guard let window = NSApp.windows.first(where: { $0 == self }) else { return }
        let mouseLocation = NSEvent.mouseLocation
        let isInside = window.frame.contains(mouseLocation)
        
        if isInside && !state.isExpanded, let expanded = expandedFrame {
            state.isExpanded = true
            animateFrame(to: expanded)
        } else if !isInside && state.isExpanded && !state.isHoveringPopover, let collapsed = collapsedFrame {
            state.isExpanded = false
            animateFrame(to: collapsed)
        }
    }

    private func observePreferredWidth() {
        state.$preferredContentWidth
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] width in
                self?.applyPreferredWidth(width)
            }
            .store(in: &cancellables)
    }

    private func applyPreferredWidth(_ width: CGFloat) {
        guard width > 0,
              let collapsed = collapsedFrame,
              let baseExpanded = baseExpandedFrame else { return }

        let baselineWidth = max(baseExpanded.width, collapsed.width)
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: Globals.screenWidth, height: Globals.screenHeight)
        let screenWidthLimit = max(screenFrame.width - 20, baselineWidth)
        let clampedWidth = min(max(width, baselineWidth), screenWidthLimit)
        let centerX = collapsed.midX
        let desiredOriginX = centerX - (clampedWidth / 2)
        let safeMargin: CGFloat = 10
        let minX = screenFrame.minX + safeMargin
        let maxX = screenFrame.maxX - clampedWidth - safeMargin
        let constrainedOriginX = min(max(desiredOriginX, minX), maxX)
        let newFrame = NSRect(
            x: constrainedOriginX,
            y: baseExpanded.origin.y,
            width: clampedWidth,
            height: baseExpanded.height
        )

        expandedFrame = newFrame

        if state.isExpanded {
            animateFrame(to: newFrame)
        }
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
        container.layer?.backgroundColor = .clear
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