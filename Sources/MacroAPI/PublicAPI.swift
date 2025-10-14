import Utilities

@_exported import Utilities
@attached(member, names: arbitrary)
public macro LogFunctions(_ module: LogModules)
    = #externalMacro(module: "MacroPlugin", type: "LogFunctionsMacro")
