import Foundation
@usableFromInline
let modules: [LogModules] = [
    // .OLoveBar, 
    .Utilities, 
    .Widgets([
        .activeAppModel, 
        // .aerospaceModel, 
        .appleLogoModel, 
        .batteryModel, 
        .dateTimeModel, 
        .languageModel, 
        .volumeModel, 
        .widgetModel, 
        // .wifiModel
    ])
]


@usableFromInline
let level: LogLevel = .trace


@usableFromInline
let isLogEnabled: Bool = true



public enum LogLevel: Int, Sendable, Equatable {
    case trace = 0, debug, info, warn, error

    @usableFromInline
    var colorCode: String {
        switch self {
        case .trace: return "\u{001B}[37m" // белый
        case .debug: return "\u{001B}[34m" // синий
        case .info:  return "\u{001B}[32m" // зелёный
        case .warn:  return "\u{001B}[33m" // жёлтый
        case .error: return "\u{001B}[31m" // красный
        }
    }
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
    case batteryModel
    case dateTimeModel
    case languageModel
    case volumeModel
    case widgetModel
    case wifiModel
}


@inlinable
public func trace(_ message: String, module: LogModules, file: String, function: String, line: Int) {
    log(level: .trace, message: message, module: module, file: file, function: function, line: line)
}

@inlinable
public func debug(_ message: String, module: LogModules, file: String, function: String, line: Int) {
    log(level: .debug, message: message, module: module, file: file, function: function, line: line)
}

@inlinable
public func info(_ message: String, module: LogModules, file: String, function: String, line: Int) {
    log(level: .info, message: message, module: module, file: file, function: function, line: line)
}

@inlinable
public func warn(_ message: String, module: LogModules, file: String, function: String, line: Int) {
    log(level: .warn, message: message, module: module, file: file, function: function, line: line)
}

@inlinable
public func error(_ message: String, module: LogModules, file: String, function: String, line: Int) {
    log(level: .error, message: message, module: module, file: file, function: function, line: line)
}

@inlinable
func log(level logLevel: LogLevel, message: String, module: LogModules, file: String, function: String, line: Int) {
    if isLogEnabled {
        guard logLevel.rawValue >= level.rawValue else { return }

        if moduleIsEnabled(module) {
            // ANSI код для цвета + сброс в конце (\u{001B}[0m)
            let fileName = URL(fileURLWithPath: file).lastPathComponent
            let coloredMessage = "\(logLevel.colorCode)[\(logLevel)]:[\(fileName):\(line)] - \(message)\u{001B}[0m"
            print(coloredMessage)
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
