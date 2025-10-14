import Utilities

@_exported import Utilities
@attached(member)
public macro LogFunctions(_ module: LogModules)
    = #externalMacro(module: "MacroPlugin", type: "LogFunctionsMacro")
