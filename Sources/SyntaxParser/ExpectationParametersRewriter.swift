import SwiftSyntax

final class ExpectationParametersRewriter: SyntaxRewriter, SyntaxBuilder {
    let mockName: String

    init(mockName: String) {
        self.mockName = mockName
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: FunctionParameterSyntax) -> FunctionParameterSyntax {
        let rewrittenType = super.visit(node.type)
        let wrapped = node.with(\.type, IdentifierTypeSyntax(
            name: .identifier("Parameter"),
            genericArgumentClause: genericArgumentClause(arguments: [rewrittenType])
        ).cast(TypeSyntax.self))

        let firstNameText = wrapped.firstName.text
        if keywordsToEscape.contains(firstNameText), !firstNameText.hasPrefix("`") {
            return wrapped.with(\.firstName, .identifier("`\(firstNameText)`"))
        }

        let secondNameText = wrapped.secondName?.text
        if let secondNameText, keywordsToEscape.contains(secondNameText), !secondNameText.hasPrefix("`") {
            return wrapped.with(\.secondName, .identifier("`\(secondNameText)`"))
        }

        return wrapped
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

    override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
        let constraint = node.constraint
        return SomeOrAnyTypeSyntax(
            someOrAnySpecifier: .keyword(.any, trailingTrivia: .space),
            constraint: constraint
        ).cast(TypeSyntax.self)
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
