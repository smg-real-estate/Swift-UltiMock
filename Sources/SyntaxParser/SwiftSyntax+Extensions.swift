import SwiftSyntax

extension FunctionParameterSyntax {
    var isInOut: Bool {
        type.as(AttributedTypeSyntax.self)?
            .specifier?.tokenKind == .keyword(.inout)
    }

    var parameterIdentifier: TokenSyntax {
        let baseName = secondName ?? firstName
        return baseName.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
    }

    var reference: DeclReferenceExprSyntax {
        DeclReferenceExprSyntax(baseName: parameterIdentifier)
    }

    var invocationExpression: ExprSyntax {
        if isInOut {
            ExprSyntax(InOutExprSyntax(
                ampersand: .prefixAmpersandToken(),
                expression: reference
            ))
        } else {
            ExprSyntax(reference)
        }
    }
}
