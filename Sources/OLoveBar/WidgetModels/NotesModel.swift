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
        
        load()
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
    
    func addNote(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let note = Note(title: trimmed)
        var dateNotes = notes[dateString] ?? []
        dateNotes.append(note)
        notes[dateString] = dateNotes
        save()
    }
    
    func toggleNote(id: UUID) {
        guard var dateNotes = notes[dateString],
              let index = dateNotes.firstIndex(where: { $0.id == id }) else { return }
        
        dateNotes[index].completed.toggle()
        notes[dateString] = dateNotes
        save()
    }
    
    func updateNoteBody(id: UUID, body: String) {
        guard var dateNotes = notes[dateString],
              let index = dateNotes.firstIndex(where: { $0.id == id }) else { return }
        
        if dateNotes[index].body == body {
            return
        }
        
        dateNotes[index].body = body
        notes[dateString] = dateNotes
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
        save()
    }
    
    func load() {
        guard FileManager.default.fileExists(atPath: path) else {
            debug("Notes file not found at \(path)")
            return
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let table = try TOMLTable(string: content)
            
            guard let notesTable = table["notes"]?.table else {
                debug("No notes section in TOML")
                return
            }
            
            var loadedNotes: [String: [Note]] = [:]
            
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
            
            notes = loadedNotes
            info("Loaded \(notes.count) date entries from \(path)")
            
        } catch {
            warn("Failed to load notes: \(error)")
        }
    }
    
    func save() {
        let snapshot = (
            path: path,
            notes: notes,
            dateFormatter: dateFormatter
        )
        
        DispatchQueue.global(qos: .utility).async {
            let root = TOMLTable()
            let notesTable = TOMLTable()
            
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date())!
            
            for (dateKey, dateNotes) in snapshot.notes {
                // Skip notes older than 30 days
                if let noteDate = snapshot.dateFormatter.date(from: dateKey),
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
