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

        let levels = ["trace", "debug", "info", "warn", "error"]

        return levels.map { level in
            DeclSyntax(stringLiteral: """
            @inlinable
            func \(level)(_ message: String) {
                log(level: .\(level), message: message, module: \(moduleExpr))
            }
            """)
        }
    }
}
