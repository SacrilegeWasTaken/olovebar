import Foundation
import SwiftUI
import TOMLKit
import MacroAPI

struct Note: Identifiable, Equatable {
    let id: UUID
    var title: String
    var body: String
    var completed: Bool
    
    init(id: UUID = UUID(), title: String, body: String = "", completed: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.completed = completed
    }
}

@MainActor
@LogFunctions(.Widgets([.notesModel]))
final class NotesModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var notes: [String: [Note]] = [:]
    
    private let path: String
    private let dateFormatter: DateFormatter
    
    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.path = home.appendingPathComponent(".config/olovebar/notes.toml").path
        
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd"
        
        loadAsync()
    }
    
    private func loadAsync() {
        let path = self.path
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var loadedNotes: [String: [Note]] = [:]
            if FileManager.default.fileExists(atPath: path) {
                do {
                    let attrs = try FileManager.default.attributesOfItem(atPath: path)
                    if let fileSize = attrs[.size] as? NSNumber, fileSize.intValue > 1_000_000 {
                        DispatchQueue.main.async { [weak self] in
                            self?.warn("Notes file too large at \(path), ignoring")
                        }
                        throw NSError(domain: "NotesModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "Notes file too large"])
                    }
                    let content = try String(contentsOfFile: path, encoding: .utf8)
                    let table = try TOMLTable(string: content)
                    if let notesTable = table["notes"]?.table {
                        for (dateKey, value) in notesTable {
                            guard let notesArray = value.array else { continue }
                            var dateNotes: [Note] = []
                            for noteValue in notesArray {
                                guard let noteTable = noteValue.table,
                                      let idString = noteTable["id"]?.string,
                                      let id = UUID(uuidString: idString),
                                      let completed = noteTable["completed"]?.bool else { continue }
                                let title = noteTable["title"]?.string ?? noteTable["text"]?.string ?? ""
                                let body = noteTable["body"]?.string ?? ""
                                dateNotes.append(Note(id: id, title: title, body: body, completed: completed))
                            }
                            if !dateNotes.isEmpty {
                                loadedNotes[dateKey] = dateNotes
                            }
                        }
                    }
                } catch {
                    // Will keep empty notes; warn on main
                    DispatchQueue.main.async { [weak self] in
                        self?.warn("Failed to load notes: \(error)")
                    }
                    return
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.notes = loadedNotes
                self?.info("Loaded \(loadedNotes.count) date entries from \(path)")
            }
        }
    }
    
    var dateString: String {
        dateFormatter.string(from: selectedDate)
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
    }
    
    func availableDates() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var dates: [Date] = []
        
        for i in (1...30).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                dates.append(date)
            }
        }
        
        dates.append(today)
        
        for i in 1...10 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    func todayIndex() -> Int {
        30
    }
    
    func notesForSelectedDate() -> [Note] {
        notes[dateString] ?? []
    }
    
    func notesStatus(for date: Date) -> (hasNotes: Bool, allCompleted: Bool) {
        let key = dateFormatter.string(from: date)
        guard let dayNotes = notes[key], !dayNotes.isEmpty else {
            return (false, false)
        }
        let allCompleted = dayNotes.allSatisfy { $0.completed }
        return (true, allCompleted)
    }
    
    func addNote(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let note = Note(title: trimmed)
        var dateNotes = notes[dateString] ?? []
        dateNotes.append(note)
        notes[dateString] = dateNotes
        flushSave()
    }
    
    func toggleNote(id: UUID) {
        guard var dateNotes = notes[dateString],
              let index = dateNotes.firstIndex(where: { $0.id == id }) else { return }
        
        dateNotes[index].completed.toggle()
        notes[dateString] = dateNotes
        flushSave()
    }
    
    private var saveTimer: Timer?
    
    func updateNoteBody(id: UUID, body: String, debounceSave: Bool = false) {
        guard var dateNotes = notes[dateString],
              let index = dateNotes.firstIndex(where: { $0.id == id }) else { return }
        
        if dateNotes[index].body == body {
            return
        }
        
        dateNotes[index].body = body
        notes[dateString] = dateNotes
        
        if debounceSave {
            scheduleSave()
        } else {
            flushSave()
        }
    }
    
    private func scheduleSave() {
        saveTimer?.invalidate()
        let t = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.flushSave() }
        }
        RunLoop.main.add(t, forMode: .common)
        saveTimer = t
    }
    
    func flushSave() {
        saveTimer?.invalidate()
        save()
    }
    
    func deleteNote(id: UUID) {
        guard var dateNotes = notes[dateString],
              let index = dateNotes.firstIndex(where: { $0.id == id }) else { return }
        
        dateNotes.remove(at: index)
        if dateNotes.isEmpty {
            notes.removeValue(forKey: dateString)
        } else {
            notes[dateString] = dateNotes
        }
        flushSave()
    }
    
    func save() {
        // Capture a thread-safe snapshot (avoid passing DateFormatter across threads)
        let dateFormat = dateFormatter.dateFormat ?? "yyyy-MM-dd"
        let snapshot = (
            path: path,
            notes: notes,
            dateFormat: dateFormat
        )
        
        DispatchQueue.global(qos: .utility).async {
            let root = TOMLTable()
            let notesTable = TOMLTable()
            
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date())
                ?? Date().addingTimeInterval(-30 * 24 * 3600)
            
            let cutoffFormatter = DateFormatter()
            cutoffFormatter.dateFormat = snapshot.dateFormat
            
            for (dateKey, dateNotes) in snapshot.notes {
                // Skip notes older than 30 days
                if let noteDate = cutoffFormatter.date(from: dateKey),
                   noteDate < cutoffDate {
                    continue
                }
                
                let noteTables: [TOMLTable] = dateNotes.map { note in
                    [
                        "id": note.id.uuidString,
                        "title": note.title,
                        "body": note.body,
                        "completed": note.completed
                    ]
                }
                
                let notesArray = TOMLArray(noteTables)
                notesTable[dateKey] = notesArray
            }
            
            root["notes"] = notesTable
            
            let tomlString = root.convert()
            
            do {
                let dir = (snapshot.path as NSString).deletingLastPathComponent
                if !FileManager.default.fileExists(atPath: dir) {
                    try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                }
                
                try tomlString.write(toFile: snapshot.path, atomically: true, encoding: .utf8)
                
                Utilities.info("Notes saved to \(snapshot.path)", module: .Widgets([.notesModel]), file: #file, function: #function, line: #line)
            } catch {
                Utilities.warn("Failed to save notes: \(error)", module: .Widgets([.notesModel]), file: #file, function: #function, line: #line)
            }
        }
    }
}
