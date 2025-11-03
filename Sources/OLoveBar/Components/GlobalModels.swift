@MainActor
class GlobalModels {
    static let shared = GlobalModels()
    
    lazy var appleLogoModel = AppleLogoModel()
    lazy var aerospaceModel = AerospaceModel()
    lazy var wifiModel = WiFiModel()
    lazy var batteryModel = BatteryModel()
    lazy var languageModel = LanguageModel()
    lazy var volumeModel = VolumeModel()
    lazy var activeAppModel = ActiveAppModel()
    lazy var dateTimeModel = DateTimeModel()
    lazy var playerModel = PlayerModel()
    
    private init() {}
}