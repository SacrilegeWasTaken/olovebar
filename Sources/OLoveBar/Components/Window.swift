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
    @Published var minimumContentWidth: CGFloat = 350

    private var widthAnimationTask: Task<Void, Never>?

    var isFullyExpanded: Bool {
        isExpanded && !isAnimating
    }

    func updatePreferredWidth(_ width: CGFloat) {
        let sanitizedWidth = max(0, width)
        guard abs(preferredContentWidth - sanitizedWidth) > 1 else { return }
        // Cancel any running interpolation
        widthAnimationTask?.cancel()

        // Do a small immediate step to kick the animation without waiting
        let current = preferredContentWidth
        let target = sanitizedWidth
        let initialProgress: Double = 0.15
        let immediate = CGFloat(Double(current) + (Double(target - current) * initialProgress))
        // Apply immediate step synchronously on main thread
        DispatchQueue.main.async { [weak self] in
            self?.preferredContentWidth = immediate
        }

        // Smoothly interpolate preferredContentWidth to the new value (shorter duration)
        widthAnimationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            let start = self.preferredContentWidth
            let end = target
            let duration: Double = 0.1
            let fps: Double = 120
            let steps = max(1, Int(duration * fps))

            func easeInOutCubic(_ t: Double) -> Double {
                return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
            }

            for i in 1...steps {
                if Task.isCancelled { return }
                let t = Double(i) / Double(steps)
                let eased = easeInOutCubic(t)
                let value = CGFloat(Double(start) + (Double(end - start) * eased))
                self.preferredContentWidth = value
                try? await Task.sleep(nanoseconds: UInt64((duration / Double(steps)) * 1_000_000_000))
            }

            // Ensure final value
            self.preferredContentWidth = end
            widthAnimationTask = nil
        }
    }

    func updateMinimumWidth(_ width: CGFloat) {
        let sanitizedWidth = max(0, width)
        minimumContentWidth = sanitizedWidth
    }
}


final class NotchWindow: NSWindow, WindowMarker {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    let state = NotchWindowState.shared
    private var collapsedFrame: NSRect?
    private var expandedFrame: NSRect?
    private var expandedTemplateFrame: NSRect?
    private var collapsedTemplateFrame: NSRect?
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
        NotificationCenter.default.addObserver(self, selector: #selector(screenParametersChanged(_:)), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setupHoverTracking(collapsedFrame: NSRect, expandedFrame: NSRect) {
        self.collapsedFrame = collapsedFrame
        self.expandedFrame = expandedFrame
        self.expandedTemplateFrame = expandedFrame
        self.collapsedTemplateFrame = collapsedFrame
        
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        contentView?.addTrackingArea(trackingArea)

        applyPreferredWidth(state.preferredContentWidth)
    }

    @objc private func screenParametersChanged(_ note: Notification) {
        Task { @MainActor in
            await self.recomputeFramesForScreenChange()
        }
    }

    private func recomputeFramesForScreenChange() async {
        guard collapsedTemplateFrame != nil else { return }

        // Recompute collapsed frame based on current Globals
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: Globals.screenWidth, height: Globals.screenHeight)
        let collapsedWidth = Globals.notchWidth - 10
        let collapsedX = Globals.screenWidth / 2 - Globals.notchWidth / 2 + 5
        let collapsedY = screenFrame.height - Globals.notchHeight + 5
        let collapsedHeight = Globals.notchHeight - 5
        let newCollapsed = NSRect(x: collapsedX, y: collapsedY, width: collapsedWidth, height: collapsedHeight)

        // Recompute expanded template from collapsed
        let newExpandedTemplate = NSRect(
            x: newCollapsed.minX - 250,
            y: newCollapsed.minY - 100,
            width: newCollapsed.width + 500,
            height: newCollapsed.height + 100
        )

        self.collapsedTemplateFrame = newCollapsed
        self.expandedTemplateFrame = newExpandedTemplate

        // Update collapsed/expanded actual frames and animate if size changes
        if state.isExpanded {
            // Re-apply preferred width which will animate expanded frame
            applyPreferredWidth(state.preferredContentWidth)
        } else {
            if let currentCollapsed = self.collapsedFrame, !NSEqualRects(currentCollapsed, newCollapsed) {
                self.collapsedFrame = newCollapsed
                animateFrame(to: newCollapsed)
            }
        }
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

        state.$minimumContentWidth
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.applyPreferredWidth(self.state.preferredContentWidth)
            }
            .store(in: &cancellables)
    }

    private func applyPreferredWidth(_ width: CGFloat) {
        guard let collapsed = collapsedFrame,
              let template = expandedTemplateFrame else { return }

        let configuredMinimum = max(state.minimumContentWidth, collapsed.width)
        let contentWidth = max(width, 0)
        let desiredWidth = max(contentWidth, configuredMinimum)
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: Globals.screenWidth, height: Globals.screenHeight)
        let screenWidthLimit = max(screenFrame.width - 20, collapsed.width)
        let clampedWidth = min(desiredWidth, screenWidthLimit)
        let centerX = collapsed.midX
        let desiredOriginX = centerX - (clampedWidth / 2)
        let safeMargin: CGFloat = 10
        let minX = screenFrame.minX + safeMargin
        let maxX = screenFrame.maxX - clampedWidth - safeMargin
        let constrainedOriginX = min(max(desiredOriginX, minX), maxX)
        let newFrame = NSRect(
            x: constrainedOriginX,
            y: template.origin.y,
            width: clampedWidth,
            height: template.height
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
    window.state.updateMinimumWidth(config.notchMinimumWidth)
        window.makeKeyAndOrderFront(nil)
        return window
}