import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MacroPluginMain: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LogFunctionsMacro.self
    ]
}
