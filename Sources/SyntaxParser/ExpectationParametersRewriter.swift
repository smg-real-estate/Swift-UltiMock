import SwiftSyntax

final class ExpectationParametersRewriter: SyntaxRewriter, SyntaxBuilder {
    let mockName: String

    init(mockName: String) {
        self.mockName = mockName
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: FunctionParameterSyntax) -> FunctionParameterSyntax {
        super.visit(
            node.with(\.type, IdentifierTypeSyntax(
                name: .identifier("Parameter"),
                genericArgumentClause: genericArgumentClause(arguments: [node.type])
            ).cast(TypeSyntax.self))
        )
    }

    override func visit(_ node: AttributedTypeSyntax) -> TypeSyntax {
        node.with(\.specifier, nil)
            .with(\.attributes, [])
            .cast(TypeSyntax.self)
    }

    override func visit(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) -> TypeSyntax {
        OptionalTypeSyntax(wrappedType: node.wrappedType).cast(TypeSyntax.self)
    }

    override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
        if node.name.tokenKind == .keyword(.Self) {
            super.visit(node.with(\.name, .identifier(mockName)))
        } else {
            super.visit(node)
        }
    }
}

extension FunctionDeclSyntax {
    func withExpectationParameters(mockName: String) -> FunctionDeclSyntax {
        let rewriter = ExpectationParametersRewriter(mockName: mockName)
        let parameters = signature.parameterClause.parameters

        return with(\.signature.parameterClause.parameters, FunctionParameterListSyntax(
            parameters.map {
                rewriter.rewrite($0).cast(FunctionParameterSyntax.self)
            }
        ))
    }
}
