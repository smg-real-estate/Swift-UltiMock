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

extension TypeSyntax {
    var stubIdentifierSlug: String {
        if let type = `as`(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            type.wrappedType.stubIdentifierSlug + "_impopt"
        } else if let type = `as`(OptionalTypeSyntax.self) {
            type.wrappedType.stubIdentifierSlug + "_opt"
        } else if let type = `as`(MemberTypeSyntax.self) {
            type.baseType.stubIdentifierSlug + "_dot_" + type.name.trimmedDescription
        } else if let type = `as`(ArrayTypeSyntax.self) {
            "lsb_" + type.element.stubIdentifierSlug + "_rsb"
        } else if let type = `as`(DictionaryTypeSyntax.self) {
            "lsb_" + type.key.stubIdentifierSlug + "_col_" + type.value.stubIdentifierSlug + "_rsb"
        } else if let type = `as`(AttributedTypeSyntax.self) {
            type.baseType.stubIdentifierSlug
        } else if let type = `as`(TupleTypeSyntax.self), type.elements.count == 1, let element = type.elements.first {
            element.type.stubIdentifierSlug
        } else if let type = `as`(FunctionTypeSyntax.self) {
            type.stubIdentifierSlug
        } else if let type = `as`(IdentifierTypeSyntax.self) {
            type.stubIdentifierSlug
        } else if let type = `as`(SomeOrAnyTypeSyntax.self) {
            type.someOrAnySpecifier.text + "_" + type.constraint.stubIdentifierSlug
        } else {
            with(\.trailingTrivia, []).description
        }
    }
}

extension FunctionTypeSyntax {
    var stubIdentifierSlug: String {
        var parts: [String] = []

        parts.append("lpar")
        parts.append(contentsOf: parameters.map { $0.type.stubIdentifierSlug })
        parts.append("rpar")

        if effectSpecifiers?.asyncSpecifier != nil {
            parts.append("async")
        }
        if effectSpecifiers?.throwsSpecifier != nil {
            parts.append("throws")
        }

        parts.append("arr")
        parts.append(returnClause.type.stubIdentifierSlug)

        return parts.joined(separator: "_")
    }
}

extension IdentifierTypeSyntax {
    var stubIdentifierSlug: String {
        var slug = name.text
        if let genericArgumentClause = genericArgumentClause {
            slug += "_lab_"
            slug += genericArgumentClause.arguments.map { $0.argument.stubIdentifierSlug }.joined(separator: "_")
            slug += "_rab"
        }
        return slug
    }
}

extension TriviaPiece {
    var isComment: Bool {
        switch self {
        case .lineComment, .blockComment, .docLineComment, .docBlockComment:
            return true
        default:
            return false
        }
    }
}
