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
    ) throws -> [DeclSyntax] {

        guard let args = attribute.arguments?.as(LabeledExprListSyntax.self),
              let moduleExpr = args.first?.expression else {
            return []
        }

        // Получаем текстовое представление выражения
        let moduleString = moduleExpr.description

        // Функция для "тримминга" строки (очищаем пробелы вручную)
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

        // Преобразуем текст модуля в полностью квалифицированный код
        func fullyQualifiedModuleCode(from trimmed: String) -> String {
            if trimmed.hasPrefix(".Widgets([") {
                let start = trimmed.index(trimmed.startIndex, offsetBy: 10)
                let end = trimmed.index(trimmed.endIndex, offsetBy: -2)
                let innerRaw = String(trimmed[start..<end])
                let items = innerRaw.split(separator: ",").map { item in
                    let s = String(item)
                    let trimmedItem = s.hasPrefix(".") ? String(s.dropFirst()) : s
                    return "WidgetSubmodules.\(trim(trimmedItem))"
                }.joined(separator: ", ")
                return "LogModules.Widgets([" + items + "])"
            } else if trimmed.hasPrefix(".") {
                return "LogModules." + String(trimmed.dropFirst())
            }
            return trimmed
        }

        let moduleCode = fullyQualifiedModuleCode(from: trim(moduleString))

        let levels = ["trace", "debug", "info", "warn", "error"]

        return levels.map { level in
            DeclSyntax(stringLiteral: """
            @inlinable
            func \(level)(_ message: String) {
                Utilities.\(level)(message, module: \(moduleCode))
            }
            """)
        }
    }
}
