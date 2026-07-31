import AppKit

/// Wi-Fi menu with rich custom rows (badge + SSID + lock) matching the volume
/// widget's idiom. Hover highlight is driven by a mouse-position poll on a
/// .common-mode timer, because NSView.mouseEntered doesn't fire inside an
/// NSMenu's tracking run loop.
@MainActor
final class WiFiMenuHandler: NSObject {
    let menu = NSMenu()

    private let controller: WiFiNetworksController
    private let rowWidth: CGFloat = 300
    private var othersExpanded = false

    private var pollTimer: Timer?
    private var hoverTimer: Timer?
    private var lastSignature = ""
    /// Rich rows currently in the menu (main list + expanded section), tracked
    /// for hover updates. Cleared and refilled on every rebuild.
    private var rows: [HoverRowView] = []
    /// Keeps switch/click targets alive across the current build.
    private var retainedTargets: [Any] = []

    init(controller: WiFiNetworksController) {
        self.controller = controller
        super.init()
        menu.autoenablesItems = false
        menu.minimumWidth = rowWidth
        rebuild()

        // Rebuild when scan data changes (async results propagate during
        // menu tracking, verified).
        let poll = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuildIfChanged() }
        }
        RunLoop.main.add(poll, forMode: .common)
        pollTimer = poll

        // Drive hover highlight from the live cursor position.
        let hover = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateHover() }
        }
        RunLoop.main.add(hover, forMode: .common)
        hoverTimer = hover
    }

    func invalidate() {
        pollTimer?.invalidate()
        pollTimer = nil
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    // MARK: - Hover

    private func updateHover() {
        let mouse = NSEvent.mouseLocation
        for row in rows {
            guard let window = row.window else { row.setHovered(false); continue }
            let inWindow = row.convert(row.bounds, to: nil)
            let onScreen = window.convertToScreen(inWindow)
            row.setHovered(onScreen.contains(mouse))
        }
    }

    // MARK: - Change detection

    private func currentSignature() -> String {
        let networks = ([controller.hotspots, controller.known, controller.others].joined())
            .map { "\($0.ssid):\($0.rssi ?? 0)" }
            .joined(separator: ",")
        return [
            "\(controller.isPowerOn)",
            controller.currentSSID ?? "",
            "\(controller.isScanning)",
            controller.connectingSSID ?? "",
            "\(othersExpanded)",
            controller.lastError ?? "",
            networks
        ].joined(separator: "|")
    }

    private func rebuildIfChanged() {
        if currentSignature() != lastSignature {
            rebuild()
        }
    }

    // MARK: - Build

    private func rebuild() {
        lastSignature = currentSignature()
        retainedTargets.removeAll()
        rows.removeAll()
        menu.removeAllItems()

        let header = NSMenuItem()
        header.view = headerView()
        menu.addItem(header)
        menu.addItem(.separator())

        if controller.isPowerOn {
            addNetworkSections()
        } else {
            addDisabledItem("Wi-Fi is off")
        }

        if let error = controller.lastError {
            addDisabledItem(error)
        }

        menu.addItem(.separator())
        addActionItem("Wi-Fi Settings…") {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.wifi-settings-extension")!)
        }
    }

    private func addNetworkSections() {
        if !controller.hotspots.isEmpty {
            menu.addItem(.sectionHeader(title: "Personal Hotspots"))
            for network in controller.hotspots {
                addRow(for: network)
            }
        }

        if controller.currentSSID != nil || !controller.known.isEmpty {
            menu.addItem(.sectionHeader(title: "Known Networks"))
            if let currentSSID = controller.currentSSID {
                addConnectedRow(ssid: currentSSID)
            }
            for network in controller.known {
                addRow(for: network)
            }
        }

        if !controller.others.isEmpty {
            addDisclosureRow(expanded: othersExpanded) { [weak self] in
                guard let self else { return }
                self.othersExpanded.toggle()
                self.rebuild()
            }
            if othersExpanded {
                for network in controller.others {
                    addRow(for: network)
                }
            }
        }
    }

    // MARK: - Rows

    private func addConnectedRow(ssid: String) {
        let entry = controller.currentNetwork
        let row = networkRow(
            ssid: ssid,
            isSecure: entry?.isSecure ?? true,
            isHotspot: entry?.isHotspot ?? false,
            signalFraction: entry?.signalFraction ?? 1.0,
            isConnected: true,
            isConnecting: false,
            onClick: nil
        )
        addItem(row)
    }

    private func addRow(for network: ScannedNetwork) {
        let controller = self.controller
        let row = networkRow(
            ssid: network.ssid,
            isSecure: network.isSecure,
            isHotspot: network.isHotspot,
            signalFraction: network.signalFraction,
            isConnected: false,
            isConnecting: controller.connectingSSID == network.ssid,
            onClick: { [weak self] in
                self?.menu.cancelTracking()
                DispatchQueue.main.async {
                    if network.isSecure && !network.isKnown {
                        WiFiMenuHandler.promptForPassword(network, controller: controller)
                    } else {
                        controller.connect(to: network)
                    }
                }
            }
        )
        addItem(row)
    }

    // MARK: - View builders

    private func networkRow(
        ssid: String,
        isSecure: Bool,
        isHotspot: Bool,
        signalFraction: Double?,
        isConnected: Bool,
        isConnecting: Bool,
        onClick: (() -> Void)?
    ) -> HoverRowView {
        let height: CGFloat = 34
        let row = HoverRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        row.onClick = onClick
        rows.append(row)

        let badge = NSView(frame: NSRect(x: 12, y: (height - 26) / 2, width: 26, height: 26))
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 13
        badge.layer?.backgroundColor = (isConnected
            ? NSColor.controlAccentColor
            : NSColor.systemGray.withAlphaComponent(0.4)).cgColor

        let glyph = NSImageView(frame: NSRect(x: 5, y: 5, width: 16, height: 16))
        let name = isHotspot ? "personalhotspot" : "wifi"
        if let signalFraction, !isHotspot {
            glyph.image = NSImage(systemSymbolName: name, variableValue: signalFraction, accessibilityDescription: nil)
        } else {
            glyph.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }
        glyph.contentTintColor = .white
        badge.addSubview(glyph)
        row.addSubview(badge)

        var trailing = rowWidth - 14

        if isConnecting {
            let spinner = NSProgressIndicator(frame: NSRect(x: trailing - 16, y: (height - 16) / 2, width: 16, height: 16))
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.startAnimation(nil)
            row.addSubview(spinner)
            trailing -= 22
        }

        if isSecure {
            let lock = NSImageView(frame: NSRect(x: trailing - 12, y: (height - 14) / 2, width: 12, height: 14))
            lock.image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil)
            lock.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            lock.contentTintColor = .secondaryLabelColor
            row.addSubview(lock)
            trailing -= 20
        }

        let label = NSTextField(labelWithString: ssid)
        label.font = .systemFont(ofSize: 13, weight: isConnected ? .medium : .regular)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 48, y: (height - 16) / 2, width: max(0, trailing - 48), height: 16)
        row.addSubview(label)

        return row
    }

    private func addDisclosureRow(expanded: Bool, onClick: @escaping () -> Void) {
        let height: CGFloat = 28
        let row = HoverRowView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: height))
        row.onClick = onClick
        rows.append(row)

        let label = NSTextField(labelWithString: "Other Networks")
        label.font = .systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.frame = NSRect(x: 16, y: (height - 16) / 2, width: rowWidth - 60, height: 16)
        row.addSubview(label)

        let chevron = NSImageView(frame: NSRect(x: rowWidth - 26, y: (height - 12) / 2, width: 12, height: 12))
        chevron.image = NSImage(
            systemSymbolName: expanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: nil
        )
        chevron.contentTintColor = .secondaryLabelColor
        row.addSubview(chevron)

        addItem(row)
    }

    private func headerView() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: rowWidth, height: 34))

        let title = NSTextField(labelWithString: "Wi-Fi")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.textColor = .labelColor
        title.frame = NSRect(x: 14, y: 8, width: 120, height: 18)
        container.addSubview(title)

        if controller.isScanning {
            let spinner = NSProgressIndicator(frame: NSRect(x: 60, y: 9, width: 16, height: 16))
            spinner.style = .spinning
            spinner.controlSize = .small
            spinner.startAnimation(nil)
            container.addSubview(spinner)
        }

        // Default control size renders as a proper switch (mini reads as a button).
        let toggle = NSSwitch()
        toggle.state = controller.isPowerOn ? .on : .off
        let size = toggle.fittingSize
        toggle.frame = NSRect(x: rowWidth - size.width - 14, y: (34 - size.height) / 2, width: size.width, height: size.height)
        let target = SwitchTarget { [weak self] on in
            self?.controller.setPower(on)
        }
        toggle.target = target
        toggle.action = #selector(SwitchTarget.changed(_:))
        retainedTargets.append(target)
        container.addSubview(toggle)

        return container
    }

    private func addDisabledItem(_ title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
    }

    private func addActionItem(_ title: String, action: @escaping () -> Void) {
        let item = NSMenuItem(title: title, action: #selector(ClickTarget.fire), keyEquivalent: "")
        let target = ClickTarget(action)
        item.target = target
        retainedTargets.append(target)
        menu.addItem(item)
    }

    private func addItem(_ view: NSView) {
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
    }

    // MARK: - Password

    private static func promptForPassword(_ network: ScannedNetwork, controller: WiFiNetworksController) {
        let alert = NSAlert()
        alert.messageText = "Enter the password for \u{201C}\(network.ssid)\u{201D}"
        alert.addButton(withTitle: "Join")
        alert.addButton(withTitle: "Cancel")

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Password"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn, !field.stringValue.isEmpty {
            controller.connect(to: network, password: field.stringValue)
        }
    }
}

// MARK: - Interactive row

/// Custom menu row: light-gray hover fill (set externally by the handler's
/// cursor poll) and a click callback. Custom-view menu items don't dismiss the
/// menu on click, so interactive rows keep it open until the callback decides.
private final class HoverRowView: NSView {
    var onClick: (() -> Void)?
    private var hovered = false

    func setHovered(_ value: Bool) {
        guard value != hovered else { return }
        hovered = value
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard hovered else { return }
        NSColor.labelColor.withAlphaComponent(0.1).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 6, dy: 2), xRadius: 9, yRadius: 9).fill()
    }

    override func mouseUp(with event: NSEvent) {
        guard let onClick, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onClick()
    }
}

// MARK: - Control targets

private final class SwitchTarget: NSObject {
    private let handler: (Bool) -> Void
    init(_ handler: @escaping (Bool) -> Void) { self.handler = handler }
    @objc func changed(_ sender: NSSwitch) { handler(sender.state == .on) }
}

private final class ClickTarget: NSObject {
    private let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func fire() { handler() }
}

// MARK: - Presenter

/// Pops the Wi-Fi menu up centered below the widget, mirroring the volume
/// widget's NSMenu presentation.
@MainActor
final class WiFiMenuPresenter {
    static let shared = WiFiMenuPresenter()

    private var handler: WiFiMenuHandler?

    func toggle(below anchor: NSView) {
        // NSMenu.popUp runs its own tracking loop and dismisses on outside
        // clicks, so a plain open doubles as toggle.
        let controller = WiFiNetworksController.shared
        controller.menuOpened()

        let handler = WiFiMenuHandler(controller: controller)
        self.handler = handler

        let menu = handler.menu
        let point = NSPoint(x: anchor.bounds.midX - menu.size.width / 2, y: anchor.bounds.minY - 8)
        menu.popUp(positioning: nil, at: point, in: anchor)

        handler.invalidate()
        controller.menuClosed()
        self.handler = nil
    }
}
