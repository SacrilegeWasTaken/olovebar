@MainActor
class GlobalModels {
    static let shared = GlobalModels()
    
    lazy var appleLogoModel = AppleLogoModel()
    lazy var aerospaceModel = AerospaceModel()
    lazy var wifiModel = WiFiModel()
    lazy var batteryModel = BatteryModel.shared
    lazy var languageModel = LanguageModel()
    lazy var volumeModel = VolumeModel.shared
    lazy var activeAppModel = ActiveAppModel()
    lazy var notesModel = NotesModel()
    lazy var displayBrightnessModel = DisplayBrightnessModel.shared
    lazy var keyboardBrightnessModel = KeyboardBrightnessModel()
    lazy var playerModel = PlayerModel.shared
    
    private init() {}
}