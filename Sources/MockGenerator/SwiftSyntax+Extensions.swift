import SwiftBasicFormat
import SwiftSyntax

let keywordsToEscape: Set<String> = ["internal", "inout", "public", "private", "open", "fileprivate"]

extension FunctionParameterSyntax {
    var isInOut: Bool {
        type.as(AttributedTypeSyntax.self)?
            .specifiers.trimmedDescription.contains("inout") ?? false
    }

    var parameterIdentifier: TokenSyntax {
        let baseName = secondName ?? firstName
        let text = baseName.text

        if keywordsToEscape.contains(text), !text.hasPrefix("`") {
            return .identifier("`\(text)`")
        }

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
extension ClosureShorthandParameterSyntax: CommaJoinableSyntax {}
extension GenericRequirementSyntax: CommaJoinableSyntax {}

extension Collection where Element: CommaJoinableSyntax {
    func commaSeparated(leadingTrivia: Trivia = [], trailingTrivia: Trivia = []) -> [Element] {
        enumerated().map { index, element in
            element
                .with(\.leadingTrivia, leadingTrivia)
                .with(\.trailingComma, index < count - 1 ? .commaToken(trailingTrivia: trailingTrivia) : nil)
        }
    }
}

extension SyntaxCollection where Element: CommaJoinableSyntax {
    func commaSeparated(leadingTrivia: Trivia = [], trailingTrivia: Trivia = []) -> Self {
        .init(commaSeparated(leadingTrivia: leadingTrivia, trailingTrivia: trailingTrivia) as [Element])
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
        parts.append(contentsOf: parameters.map(\.type.stubIdentifierSlug))
        parts.append("rpar")

        if effectSpecifiers?.asyncSpecifier != nil {
            parts.append("async")
        }
        if effectSpecifiers?.throwsClause?.throwsSpecifier != nil {
            parts.append("throws")
        }

        parts.append("ret")
        parts.append(returnClause.type.stubIdentifierSlug)

        return parts.joined(separator: "_")
    }

    var hasTypedThrows: Bool {
        effectSpecifiers?.throwsClause?.type != nil
    }
}

extension IdentifierTypeSyntax {
    var stubIdentifierSlug: String {
        var slug = name.text
        if let genericArgumentClause {
            slug += "_lab_"
            slug += genericArgumentClause.arguments.map { $0.argument.as(TypeSyntax.self)!.stubIdentifierSlug }.joined(separator: "_")
            slug += "_rab"
        }
        return slug
    }
}

extension TriviaPiece {
    var isComment: Bool {
        switch self {
        case .lineComment, .blockComment, .docLineComment, .docBlockComment:
            true
        default:
            false
        }
    }
}

extension SyntaxProtocol {
    func format() -> Self {
        formatted().as(Self.self)!
    }

    func withoutTrivia(_ predicate: (TriviaPiece) -> Bool) -> Self {
        with(\.leadingTrivia, Trivia(pieces: leadingTrivia.filter { !predicate($0) }))
            .with(\.trailingTrivia, Trivia(pieces: trailingTrivia.filter { !predicate($0) }))
    }
}
