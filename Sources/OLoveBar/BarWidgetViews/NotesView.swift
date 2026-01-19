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
                Color.clear.onAppear {
                    widgetFrame = geo.frame(in: .global)
                }.onChange(of: geo.frame(in: .global)) {
                    widgetFrame = geo.frame(in: .global)
                }
            }
        )
    }
    
    private func showNotesMenu() {
        guard let window = NSApp.windows.first(where: { $0 is OLoveBarWindow }),
              let contentView = window.contentView else { return }
        
        let menu = NotesMenuView.createMenu(model: model, config: config)
        
        let menuWidth: CGFloat = 320
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
        textField.placeholderString = "Add a note..."
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
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let notes = model.notesForSelectedDate()
        
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
        
        let label = NSTextField(labelWithString: note.text)
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .left
        
        if note.completed {
            label.textColor = .tertiaryLabelColor
            let attributed = NSMutableAttributedString(string: note.text)
            attributed.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: NSRange(location: 0, length: note.text.count))
            attributed.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: NSRange(location: 0, length: note.text.count))
            label.attributedStringValue = attributed
        } else {
            label.textColor = .labelColor
        }
        
        container.addSubview(checkbox)
        container.addSubview(label)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 304),
            container.heightAnchor.constraint(equalToConstant: 28),
            
            checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            checkbox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            checkbox.widthAnchor.constraint(equalToConstant: 18),
            
            label.leadingAnchor.constraint(equalTo: checkbox.trailingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        
        return container
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
            submit(control as! NSTextField)
            return true
        }
        return false
    }
}
