import SwiftSyntax

extension SubscriptDeclSyntax {
    var getterFunctionType: FunctionTypeSyntax {
        FunctionTypeSyntax(
            parameters: tupleParameters,
            effectSpecifiers: getterEffectSpecifiers,
            returnClause: ReturnClauseSyntax(
                type: returnType.replacingImplicitlyUnwrappedOptionals()
            )
        )
    }

    var setterFunctionType: FunctionTypeSyntax {
        var parameters = tupleParameters
        parameters.append(TupleTypeElementSyntax(
            type: returnType.trimmed.replacingImplicitlyUnwrappedOptionals()
        ))
        return FunctionTypeSyntax(
            parameters: parameters.commaSeparated(),
            returnClause: ReturnClauseSyntax(
                type: .void
            )
        )
    }

    var tupleParameters: TupleTypeElementListSyntax {
        parameterClause.parameters.replacingImplicitlyUnwrappedOptionals()
            .asTupleTypeElementList(mockName: "")
    }

    var returnType: TypeSyntax {
        returnClause.type
    }

    var getterEffectSpecifiers: TypeEffectSpecifiersSyntax? {
        accessors?.compactMap {
            $0.effectSpecifiers?.asTypeEffectSpecifiersSyntax
        }
        .first
    }

    var accessors: AccessorDeclListSyntax? {
        switch accessorBlock?.accessors {
        case let .accessors(accessorList):
            accessorList
        default:
            nil
        }
    }

    var isReadwrite: Bool {
        accessors?.contains {
            $0.accessorSpecifier.tokenKind == .keyword(.set)
        } ?? false
    }
}
