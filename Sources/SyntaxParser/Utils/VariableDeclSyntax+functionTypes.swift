import SwiftSyntax

extension VariableDeclSyntax {
    var getterFunctionType: FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: [],
            returnClause: ReturnClauseSyntax(
                type: type
            )
        )
    }

    var setterFunctionType: FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: [
                TupleTypeElementSyntax(type: type)
            ],
            returnClause: ReturnClauseSyntax(
                type: .void
            )
        )
    }

    var type: TypeSyntax {
        bindings.first?.typeAnnotation?.type.trimmed ?? .void
    }
}

extension TypeSyntax {
    static var void: Self {
        TypeSyntax(.void)
    }
}

extension TypeSyntaxProtocol where Self == IdentifierTypeSyntax {
    static var void: Self {
        IdentifierTypeSyntax(name: .identifier("Void"))
    }
}

extension AccessorEffectSpecifiersSyntax {
    var asTypeEffectSpecifiersSyntax: TypeEffectSpecifiersSyntax {
        .init(
            asyncSpecifier: asyncSpecifier,
            throwsSpecifier: throwsSpecifier
        )
    }
}
