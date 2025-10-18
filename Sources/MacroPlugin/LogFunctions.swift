import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import SwiftCompilerPlugin
import Utilities

public struct LogFunctionsMacro: MemberMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) 
    throws -> [SwiftSyntax.DeclSyntax] 
    {
        // Extract argument
        guard let args = attribute.arguments?.as(LabeledExprListSyntax.self),
              let moduleExpr = args.first?.expression else {
            return []
        }

        let moduleString = moduleExpr.description

        func trim(_ str: String) -> String {
            var chars = Array(str)
            while let first = chars.first, first.isWhitespace {
                chars.removeFirst()
            }
            while let last = chars.last, last.isWhitespace {
                chars.removeLast()
            }
            return String(chars)
        }

        func fullyQualifiedModuleCode(from trimmed: String) -> String {
            if trimmed.hasPrefix(".Widgets([") {
                let start = trimmed.index(trimmed.startIndex, offsetBy: 10)
                let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
                let innerRaw = String(trimmed[start..<end])
                let items = innerRaw.split(separator: ",").map { item -> String in
                    var s = String(item)
                    while s.first?.isWhitespace ?? false { s.removeFirst() }
                    while s.last?.isWhitespace ?? false { s.removeLast() }
                    if s.hasPrefix(".") { s.removeFirst() }
                    return "WidgetSubmodules." + s
                }.joined(separator: ", ")
                return "LogModules.Widgets([" + items + "])"
            } else if trimmed.hasPrefix(".") {
                return "LogModules." + String(trimmed.dropFirst())
            }
            return trimmed
        }

        let moduleCode = fullyQualifiedModuleCode(from: trim(moduleString))
        let levels = ["trace", "debug", "info", "warn", "error"]

        // Generate member functions as plain DeclSyntax
        return levels.map { level in
            DeclSyntax("""
            @inlinable
            nonisolated func \(raw: level)(_ message: String, file: String = #fileID, function: String = #function, line: Int = #line) {
                Utilities.\(raw: level)(message, module: \(raw: moduleCode), file: file, function: function, line: line)
            }
            """)
        }
    }
}
