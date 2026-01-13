import SwiftSyntax

extension FunctionDeclSyntax {
    func asType(mockName: String) -> FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: signature.parameterClause.parameters.asTupleTypeElementList(mockName: mockName),
            effectSpecifiers: signature.effectSpecifiers?.asTypeEffectSpecifiersSyntax,
            returnClause: signature.returnClause ?? ReturnClauseSyntax(
                type: TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
            )
        )
        .with(\.trailingTrivia, [])
        .replacingImplicitlyUnwrappedOptionals()
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
            throwsClause: throwsClause
        )
    }
}
