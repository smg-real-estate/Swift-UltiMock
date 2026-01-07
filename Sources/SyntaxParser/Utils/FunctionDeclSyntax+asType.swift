import SwiftSyntax

private final class ImplicitlyUnwrappedOptionalTypeRewriter: SyntaxRewriter, SyntaxBuilder {
    let mockName: String

    init(mockName: String) {
        self.mockName = mockName
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) -> TypeSyntax {
        OptionalTypeSyntax(wrappedType: node.wrappedType).cast(TypeSyntax.self)
    }
}

extension FunctionDeclSyntax {
    func asType(mockName: String) -> FunctionTypeSyntax {
        let rewriter = ImplicitlyUnwrappedOptionalTypeRewriter(mockName: mockName)
        let parameters = signature.parameterClause.parameters

        return rewriter.rewrite(
            FunctionTypeSyntax(
                parameters: parameters.asTupleTypeElementList(mockName: mockName),
                effectSpecifiers: signature.effectSpecifiers?.asTypeEffectSpecifiersSyntax,
                returnClause: signature.returnClause ?? ReturnClauseSyntax(
                    type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
                )
            )
            .with(\.trailingTrivia, [])
        ).cast(FunctionTypeSyntax.self)
    }
}

extension TypeSyntax {
    var isSelf: Bool {
        `as`(IdentifierTypeSyntax.self)?.name.tokenKind == .keyword(.Self)
    }
}

extension FunctionParameterListSyntax {
    func asTupleTypeElementList(mockName: String) -> TupleTypeElementListSyntax {
        TupleTypeElementListSyntax(
            map { parameter in
                TupleTypeElementSyntax(
                    type: parameter.type.isSelf ? TypeSyntax(IdentifierTypeSyntax(name: .identifier(mockName))) : parameter.type
                )
            }
            .commaSeparated()
        )
    }
}

extension FunctionEffectSpecifiersSyntax {
    var asTypeEffectSpecifiersSyntax: TypeEffectSpecifiersSyntax {
        .init(
            asyncSpecifier: asyncSpecifier,
            throwsSpecifier: throwsSpecifier
        )
    }
}
