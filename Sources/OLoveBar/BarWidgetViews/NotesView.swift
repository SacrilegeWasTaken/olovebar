import SwiftUI
import AppKit
import MacroAPI
import Combine

@LogFunctions(.Widgets([.notesModel]))
struct NotesWidgetView: View {
    @ObservedObject var config: Config
    @ObservedObject var model = GlobalModels.shared.notesModel
    @State private var widgetFrame: CGRect = .zero
    var body: some View {
        Button(action: { showNotesMenu() }) {
            Image(systemName: "list.bullet")
                .foregroundColor(.white)
                .frame(width: config.notesWidth, height: config.widgetHeight)
                .background(
                    LiquidGlassBackground(
                        variant: GlassVariant(rawValue: config.widgetGlassVariant)!,
                        cornerRadius: config.widgetCornerRadius
                    ) {}
                )
                .cornerRadius(config.widgetCornerRadius)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        widgetFrame = geo.frame(in: .named("BarRoot"))
                    }
                    .onChange(of: geo.frame(in: .named("BarRoot"))) {
                        widgetFrame = geo.frame(in: .named("BarRoot"))
                    }
            }
        )
    }
    
    private func showNotesMenu() {
        guard let window = NSApp.windows.first(where: { $0 is OLoveBarWindow }),
              let contentView = window.contentView else { return }
        
        let menu = NotesMenuView.createMenu(model: model, config: config)
        let menuWidth = menu.size.width
        let widgetCenterX = widgetFrame.midX
        let menuX = widgetCenterX - (menuWidth / 2)
        let menuY: CGFloat = -12
        
        let point = CGPoint(x: menuX, y: menuY)
        menu.popUp(positioning: nil, at: point, in: contentView)
    }
}

@MainActor
final class NotesMenuView {
    
    static func createMenu(model: NotesModel, config: Config) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        
        let titleItem = NSMenuItem()
        titleItem.view = createTitleView(text: "Notes")
        menu.addItem(titleItem)
        
        let monthItem = NSMenuItem()
        monthItem.view = createMonthLabel(model: model)
        menu.addItem(monthItem)
        
        let datePickerItem = NSMenuItem()
        datePickerItem.view = createDatePicker(model: model)
        menu.addItem(datePickerItem)
        
        menu.addItem(.separator())
        
        let notesItem = NSMenuItem()
        notesItem.view = createNotesList(model: model)
        menu.addItem(notesItem)
        
        menu.addItem(.separator())
        
        let inputItem = NSMenuItem()
        inputItem.view = createInputField(model: model)
        menu.addItem(inputItem)
        
        return menu
    }
    
    private static func createTitleView(text: String) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        label.textColor = .labelColor
        label.frame = NSRect(x: 12, y: 4, width: 296, height: 16)
        
        container.addSubview(label)
        return container
    }
    
    private static func createMonthLabel(model: NotesModel) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 18))
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        let label = NSTextField(labelWithString: formatter.string(from: model.selectedDate))
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.frame = NSRect(x: 12, y: 0, width: 296, height: 14)
        label.identifier = NSUserInterfaceItemIdentifier("monthLabel")
        
        container.addSubview(label)
        
        let subscription = MonthLabelSubscription(label: label, model: model)
        objc_setAssociatedObject(container, "subscription", subscription, .OBJC_ASSOCIATION_RETAIN)
        
        return container
    }
    
    private static func createDatePicker(model: NotesModel) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 40))
        
        let scrollView = NSScrollView(frame: NSRect(x: 8, y: 4, width: 304, height: 32))
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.drawsBackground = false
        
        let dates = model.availableDates()
        let buttonWidth: CGFloat = 36
        let buttonSpacing: CGFloat = 4
        let totalWidth = CGFloat(dates.count) * (buttonWidth + buttonSpacing)
        
        let documentView = NSView(frame: NSRect(x: 0, y: 0, width: totalWidth, height: 32))
        
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "d"
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        for (index, date) in dates.enumerated() {
            let button = DatePickerButton(
                frame: NSRect(x: CGFloat(index) * (buttonWidth + buttonSpacing), y: 0, width: buttonWidth, height: 32),
                date: date,
                dayText: dayFormatter.string(from: date),
                isToday: calendar.isDate(date, inSameDayAs: today),
                model: model
            )
            documentView.addSubview(button)
        }
        
        scrollView.documentView = documentView
        
        let todayIndex = model.todayIndex()
        let scrollX = max(0, CGFloat(todayIndex) * (buttonWidth + buttonSpacing) - scrollView.frame.width / 2 + buttonWidth / 2)
        scrollView.contentView.scroll(to: NSPoint(x: scrollX, y: 0))
        
        container.addSubview(scrollView)
        return container
    }
    
    private static func createNotesList(model: NotesModel) -> NSView {
        let container = NotesListContainer(model: model)
        return container
    }
    
    private static func createInputField(model: NotesModel) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 36))
        
        let textField = NSTextField(frame: NSRect(x: 12, y: 6, width: 296, height: 24))
        textField.placeholderString = "Add a note title..."
        textField.font = .systemFont(ofSize: 13)
        textField.bezelStyle = .roundedBezel
        textField.focusRingType = .none
        
        let inputTarget = NoteInputTarget(model: model, textField: textField)
        textField.delegate = inputTarget
        textField.target = inputTarget
        textField.action = #selector(NoteInputTarget.submit(_:))
        objc_setAssociatedObject(textField, "target", inputTarget, .OBJC_ASSOCIATION_RETAIN)
        
        container.addSubview(textField)
        return container
    }
}

private class MonthLabelSubscription: NSObject {
    private var cancellable: AnyCancellable?
    
    @MainActor
    init(label: NSTextField, model: NotesModel) {
        super.init()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        self.cancellable = model.$selectedDate.sink { [weak label] newDate in
            Task { @MainActor in
                label?.stringValue = formatter.string(from: newDate)
            }
        }
    }
}

private class DatePickerButton: NSButton {
    let date: Date
    let model: NotesModel
    let isToday: Bool
    private var cancellable: AnyCancellable?
    
    @MainActor
    init(frame: NSRect, date: Date, dayText: String, isToday: Bool, model: NotesModel) {
        self.date = date
        self.model = model
        self.isToday = isToday
        super.init(frame: frame)
        
        self.title = dayText
        self.isBordered = false
        self.wantsLayer = true
        self.layer?.cornerRadius = 8
        self.font = .systemFont(ofSize: 13)
        
        self.target = self
        self.action = #selector(dateSelected)
        
        updateAppearance()
        
        self.cancellable = model.$selectedDate.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateAppearance()
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor
    private func updateAppearance() {
        let calendar = Calendar.current
        let isSelected = calendar.isDate(date, inSameDayAs: model.selectedDate)
        
        if isSelected {
            self.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
            self.contentTintColor = .white
            self.font = .systemFont(ofSize: 13, weight: .semibold)
        } else if isToday {
            self.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3).cgColor
            self.contentTintColor = .labelColor
            self.font = .systemFont(ofSize: 13)
        } else {
            self.layer?.backgroundColor = NSColor.clear.cgColor
            self.contentTintColor = .labelColor
            self.font = .systemFont(ofSize: 13)
        }
    }
    
    @MainActor
    @objc func dateSelected() {
        model.selectDate(date)
    }
}

private class NotesListContainer: NSView {
    let model: NotesModel
    private var cancellables = Set<AnyCancellable>()
    private let stackView: NSStackView
    private var expandedNotes = Set<UUID>()
    
    @MainActor
    init(model: NotesModel) {
        self.model = model
        self.stackView = NSStackView()
        
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 150))
        
        let scrollView = NSScrollView(frame: bounds)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let clipView = scrollView.contentView
        clipView.documentView = stackView
        
        NSLayoutConstraint.activate([
            stackView.widthAnchor.constraint(equalToConstant: 304)
        ])
        
        addSubview(scrollView)
        
        rebuildNotes()
        
        model.$notes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildNotes()
            }
            .store(in: &cancellables)
        
        model.$selectedDate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildNotes()
            }
            .store(in: &cancellables)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @MainActor
    private func rebuildNotes() {
        let notes = model.notesForSelectedDate()
        
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        if notes.isEmpty {
            let emptyLabel = NSTextField(labelWithString: "No notes for this day")
            emptyLabel.font = .systemFont(ofSize: 12)
            emptyLabel.textColor = .tertiaryLabelColor
            emptyLabel.alignment = .center
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            
            let container = NSView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(emptyLabel)
            
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: 304),
                container.heightAnchor.constraint(equalToConstant: 50),
                emptyLabel.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            
            stackView.addArrangedSubview(container)
        } else {
            for note in notes {
                let row = createNoteRow(note: note)
                stackView.addArrangedSubview(row)
            }
        }
    }
    
    @MainActor
    private func createNoteRow(note: Note) -> NSView {
        let isExpanded = expandedNotes.contains(note.id)
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let checkbox = NSButton(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
        checkbox.setButtonType(.switch)
        checkbox.title = ""
        checkbox.state = note.completed ? .on : .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        
        let checkboxTarget = NoteCheckboxTarget(noteId: note.id, model: model)
        checkbox.target = checkboxTarget
        checkbox.action = #selector(NoteCheckboxTarget.toggled(_:))
        objc_setAssociatedObject(checkbox, "target", checkboxTarget, .OBJC_ASSOCIATION_RETAIN)
        
        let expandButton = NSButton(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
        expandButton.image = NSImage(systemSymbolName: isExpanded ? "chevron.down" : "chevron.right", accessibilityDescription: nil)
        expandButton.imagePosition = .imageOnly
        expandButton.isBordered = false
        expandButton.contentTintColor = .secondaryLabelColor
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        
        let expandTarget = NoteExpandTarget(noteId: note.id, container: self)
        expandButton.target = expandTarget
        expandButton.action = #selector(NoteExpandTarget.toggle(_:))
        objc_setAssociatedObject(expandButton, "target", expandTarget, .OBJC_ASSOCIATION_RETAIN)
        
        let titleLabel = NSTextField(labelWithString: note.title)
        titleLabel.font = .systemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.alignment = .left
        
        if note.completed {
            titleLabel.textColor = .tertiaryLabelColor
            let attributed = NSMutableAttributedString(string: note.title)
            attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: note.title.count))
            attributed.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: NSRange(location: 0, length: note.title.count))
            titleLabel.attributedStringValue = attributed
        } else {
            titleLabel.textColor = .labelColor
        }
        
        let deleteButton = NSButton(frame: NSRect(x: 0, y: 0, width: 20, height: 20))
        deleteButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)
        deleteButton.imagePosition = .imageOnly
        deleteButton.isBordered = false
        deleteButton.bezelStyle = .texturedRounded
        deleteButton.contentTintColor = .secondaryLabelColor
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        
        let deleteTarget = NoteDeleteTarget(noteId: note.id, model: model)
        deleteButton.target = deleteTarget
        deleteButton.action = #selector(NoteDeleteTarget.delete(_:))
        objc_setAssociatedObject(deleteButton, "target", deleteTarget, .OBJC_ASSOCIATION_RETAIN)
        
        container.addSubview(checkbox)
        container.addSubview(expandButton)
        container.addSubview(titleLabel)
        container.addSubview(deleteButton)
        
        if isExpanded {
            let scrollView = NSScrollView()
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.borderType = .bezelBorder
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            
            let bodyTextView = NSTextView()
            bodyTextView.string = note.body
            bodyTextView.font = .systemFont(ofSize: 12)
            bodyTextView.isEditable = true
            bodyTextView.isSelectable = true
            bodyTextView.isVerticallyResizable = true
            bodyTextView.isHorizontallyResizable = false
            bodyTextView.textContainer?.containerSize = NSSize(width: 280, height: CGFloat.greatestFiniteMagnitude)
            bodyTextView.textContainer?.widthTracksTextView = true
            
            scrollView.documentView = bodyTextView
            
            let bodyTarget = NoteBodyTarget(noteId: note.id, model: model, textView: bodyTextView)
            NotificationCenter.default.addObserver(
                bodyTarget,
                selector: #selector(NoteBodyTarget.textDidEndEditing(_:)),
                name: NSText.didEndEditingNotification,
                object: bodyTextView
            )
            objc_setAssociatedObject(bodyTextView, "target", bodyTarget, .OBJC_ASSOCIATION_RETAIN)
            
            container.addSubview(scrollView)
            
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: 304),
                
                checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                checkbox.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
                checkbox.widthAnchor.constraint(equalToConstant: 18),
                checkbox.heightAnchor.constraint(equalToConstant: 18),
                
                expandButton.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
                expandButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),
                expandButton.widthAnchor.constraint(equalToConstant: 16),
                expandButton.heightAnchor.constraint(equalToConstant: 16),
                
                titleLabel.leadingAnchor.constraint(equalTo: expandButton.trailingAnchor, constant: 4),
                titleLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
                titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                titleLabel.heightAnchor.constraint(equalToConstant: 16),
                
                scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
                scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
                scrollView.heightAnchor.constraint(equalToConstant: 80),
                
                deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                deleteButton.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
                deleteButton.widthAnchor.constraint(equalToConstant: 20),
                deleteButton.heightAnchor.constraint(equalToConstant: 20)
            ])
        } else {
            NSLayoutConstraint.activate([
                container.widthAnchor.constraint(equalToConstant: 304),
                container.heightAnchor.constraint(equalToConstant: 28),
                
                checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
                checkbox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                checkbox.widthAnchor.constraint(equalToConstant: 18),
                
                expandButton.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 4),
                expandButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                expandButton.widthAnchor.constraint(equalToConstant: 16),
                expandButton.heightAnchor.constraint(equalToConstant: 16),
                
                titleLabel.leadingAnchor.constraint(equalTo: expandButton.trailingAnchor, constant: 4),
                titleLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8),
                titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                
                deleteButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
                deleteButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                deleteButton.widthAnchor.constraint(equalToConstant: 20),
                deleteButton.heightAnchor.constraint(equalToConstant: 20)
            ])
        }
        
        return container
    }
    
    @MainActor
    func toggleNoteExpansion(_ noteId: UUID) {
        if expandedNotes.contains(noteId) {
            expandedNotes.remove(noteId)
        } else {
            expandedNotes.insert(noteId)
        }
        rebuildNotes()
    }
}

private class NoteCheckboxTarget: NSObject {
    let noteId: UUID
    let model: NotesModel
    
    init(noteId: UUID, model: NotesModel) {
        self.noteId = noteId
        self.model = model
    }
    
    @MainActor
    @objc func toggled(_ sender: NSButton) {
        model.toggleNote(id: noteId)
    }
}

private class NoteDeleteTarget: NSObject {
    let noteId: UUID
    let model: NotesModel
    
    init(noteId: UUID, model: NotesModel) {
        self.noteId = noteId
        self.model = model
    }
    
    @MainActor
    @objc func delete(_ sender: NSButton) {
        model.deleteNote(id: noteId)
    }
}

private class NoteExpandTarget: NSObject {
    let noteId: UUID
    weak var container: NotesListContainer?
    
    init(noteId: UUID, container: NotesListContainer) {
        self.noteId = noteId
        self.container = container
    }
    
    @MainActor
    @objc func toggle(_ sender: NSButton) {
        container?.toggleNoteExpansion(noteId)
    }
}

private class NoteBodyTarget: NSObject {
    let noteId: UUID
    let model: NotesModel
    weak var textView: NSTextView?
    private var saveTimer: Timer?
    
    init(noteId: UUID, model: NotesModel, textView: NSTextView) {
        self.noteId = noteId
        self.model = model
        self.textView = textView
    }
    
    @MainActor
    @objc func textDidChange(_ notification: Notification) {
    }
    
    @MainActor
    @objc func textDidEndEditing(_ notification: Notification) {
        saveTimer?.invalidate()
        if let textView = notification.object as? NSTextView {
            model.updateNoteBody(id: noteId, body: textView.string)
        }
    }
}

private class NoteInputTarget: NSObject, NSTextFieldDelegate {
    let model: NotesModel
    weak var textField: NSTextField?
    
    init(model: NotesModel, textField: NSTextField) {
        self.model = model
        self.textField = textField
    }
    
    @MainActor
    @objc func submit(_ sender: NSTextField) {
        let text = sender.stringValue
        if !text.isEmpty {
            model.addNote(text)
            sender.stringValue = ""
        }
    }
    
    @MainActor
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let textField = control as? NSTextField {
                submit(textField)
            }
            return true
        }
        return false
    }
}
