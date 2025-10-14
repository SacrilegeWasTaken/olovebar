import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics

// 1. Реализация макроса
public struct LogFunctionsMacro: PeerMacro {
    public static func expansion(
        of attribute: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let args = attribute.arguments?.as(LabeledExprListSyntax.self),
              let moduleExpr = args.first?.expression else { return [] }

        let levels = ["trace", "debug", "info", "warn", "error"]

        return levels.compactMap { level in
            guard let funcDecl = try? FunctionDeclSyntax(
                """
                func \(raw: level)(_ message: String) {
                    print("[\(raw: level)] [Module: \(moduleExpr)] \\(message)")
                }
                """
            ) else { return nil }
            return DeclSyntax(funcDecl)
        }
    }
}

