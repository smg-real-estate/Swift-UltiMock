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
            return type.wrappedType.stubIdentifierSlug + "_impopt"
        } else if let type = `as`(OptionalTypeSyntax.self) {
            return type.wrappedType.stubIdentifierSlug + "_opt"
        } else if let type = `as`(MemberTypeSyntax.self) {
            return type.baseType.stubIdentifierSlug + "_dot_" + type.name.trimmedDescription
        } else if let type = `as`(ArrayTypeSyntax.self) {
            return "lsb_" + type.element.stubIdentifierSlug + "_rsb"
        } else if let type = `as`(DictionaryTypeSyntax.self) {
            return "lsb_" + type.key.stubIdentifierSlug + "_col_" + type.value.stubIdentifierSlug + "_rsb"
        } else if let type = `as`(AttributedTypeSyntax.self) {
            return type.baseType.stubIdentifierSlug
        } else if let type = `as`(TupleTypeSyntax.self), type.elements.count == 1, let element = type.elements.first {
            return element.type.stubIdentifierSlug
        } else if let type = `as`(FunctionTypeSyntax.self) {
            var parts: [String] = []
            
            parts.append("lpar")
            parts.append(contentsOf: type.parameters.map { $0.type.stubIdentifierSlug })
            parts.append("rpar")
            
            if type.effectSpecifiers?.asyncSpecifier != nil {
                parts.append("async")
            }
            if type.effectSpecifiers?.throwsSpecifier != nil {
                parts.append("throws")
            }
            
            parts.append("arr")
            parts.append(type.returnClause.type.stubIdentifierSlug)
            
            return parts.joined(separator: "_")
        } else {
            return description.trimmingCharacters(in: .whitespaces)
        }
    }
}
