@usableFromInline
let modules: [LogModules] = [
    .OLoveBar, 
    .Utilities, 
    .Widgets([
        .activeAppModel, 
        .aerospaceModel, 
        .appleLogoModel, 
        .BatteryModel, 
        .DateTimeModel, 
        .LanguageModel, 
        .VolumeModel, 
        .WidgetModel, 
        .WiFiModel
    ])
]


@usableFromInline
let level: LogLevel = .trace


@usableFromInline
let isLogEnabled: Bool = true


public enum LogLevel: Int, Sendable, Equatable {
    case trace = 1
    case debug = 2
    case info  = 3
    case warn  = 4
    case error = 5
}


public enum LogModules: Sendable, Equatable {
    case OLoveBar
    case Utilities
    case Widgets([WidgetSubmodules])
}


public enum WidgetSubmodules: Sendable, Equatable {
    case activeAppModel
    case aerospaceModel
    case appleLogoModel
    case BatteryModel
    case DateTimeModel
    case LanguageModel
    case VolumeModel
    case WidgetModel
    case WiFiModel
}


@inlinable
public func trace(_ message: String, module: LogModules) {
    log(level: .trace, message: message, module: module)
}

@inlinable
public func debug(_ message: String, module: LogModules) {
    log(level: .debug, message: message, module: module)
}

@inlinable
public func info(_ message: String, module: LogModules) {
    log(level: .info, message: message, module: module)
}

@inlinable
public func warn(_ message: String, module: LogModules) {
    log(level: .warn, message: message, module: module)
}

@inlinable
public func error(_ message: String, module: LogModules) {
    log(level: .error, message: message, module: module)
}

@inlinable
func log(level logLevel: LogLevel, message: String, module: LogModules) {
    if isLogEnabled {
        guard logLevel.rawValue >= level.rawValue else { return }

        if moduleIsEnabled(module) {
            print("[\(logLevel)] \(message)")
        }
    }
}

@inlinable
func moduleIsEnabled(_ module: LogModules) -> Bool {
    for enabled in modules {
        switch (enabled, module) {
            case (.OLoveBar, .OLoveBar), (.Utilities, .Utilities):
                return true
            case let (.Widgets(enabledSubs), .Widgets(requestedSubs)):
                return !requestedSubs.filter { enabledSubs.contains($0) }.isEmpty
            default:
                continue
        }
    }
    return false
}
