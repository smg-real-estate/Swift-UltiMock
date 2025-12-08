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

protocol CommaJoinableSyntax: SyntaxProtocol {
    var trailingComma: TokenSyntax? { get set }
}

extension ArrayElementSyntax: CommaJoinableSyntax {}
extension FunctionParameterSyntax: CommaJoinableSyntax {}
extension TupleTypeElementSyntax: CommaJoinableSyntax {}
extension LabeledExprSyntax: CommaJoinableSyntax {}
extension GenericParameterSyntax: CommaJoinableSyntax {}

extension Collection where Element: CommaJoinableSyntax {
    func commaSeparated(trailingTrivia: Trivia = .space) -> [Element] {
        enumerated().map { index, element in
            element.with(\.trailingComma, index < count - 1 ? .commaToken(trailingTrivia: trailingTrivia) : nil)
        }
    }
}
