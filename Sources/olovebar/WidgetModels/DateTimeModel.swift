import SwiftUI
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.languageModel]))
public class DateTimeModel: ObservableObject {
    @Published var percentage: Int = 100
    @Published var isCharging: Bool = false

}