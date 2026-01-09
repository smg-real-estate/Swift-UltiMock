import SwiftSyntax

extension VariableDeclSyntax {
    var getterFunctionType: FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: [],
            effectSpecifiers: getterEffectSpecifiers,
            returnClause: ReturnClauseSyntax(
                type: type.replacingImplicitlyUnwrappedOptionals()
            )
        )
    }

    var setterFunctionType: FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: [
                TupleTypeElementSyntax(type: type.replacingImplicitlyUnwrappedOptionals())
            ],
            returnClause: ReturnClauseSyntax(
                type: .void
            )
        )
    }

    var type: TypeSyntax {
        bindings.first?.typeAnnotation?.type.trimmed ?? .void
    }

    var getterEffectSpecifiers: TypeEffectSpecifiersSyntax? {
        accessors?.compactMap {
            $0.effectSpecifiers?.asTypeEffectSpecifiersSyntax
        }
        .first
    }

    var accessors: AccessorDeclListSyntax? {
        switch bindings.first?.accessorBlock?.accessors {
        case let .accessors(accessorList):
            accessorList
        default:
            nil
        }
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
