import SwiftUI
import MacroAPI

@MainActor
@LogFunctions(.Widgets([.appleLogoModel]))
public class AppleLogoModel: ObservableObject {
    @Published var percentage: Int = 100
    @Published var isCharging: Bool = false

}