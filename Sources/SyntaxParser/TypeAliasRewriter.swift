import SwiftSyntax

final class TypeAliasRewriter: SyntaxRewriter {
    let resolver: MockedTypesResolver
    let scope: String

    init(resolver: MockedTypesResolver, scope: String) {
        self.resolver = resolver
        self.scope = scope
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
        let typeName = node.name.text
        let resolvedTypeName = resolver.resolveTypeAlias(typeName, in: scope)

        if resolvedTypeName != typeName {
            var newIdentifier = TokenSyntax.identifier(resolvedTypeName)
            newIdentifier.leadingTrivia = node.name.leadingTrivia
            newIdentifier.trailingTrivia = node.name.trailingTrivia

            var newType = IdentifierTypeSyntax(
                name: newIdentifier,
                genericArgumentClause: node.genericArgumentClause
            )
            newType.leadingTrivia = node.leadingTrivia
            newType.trailingTrivia = node.trailingTrivia

            return TypeSyntax(newType)
        }

        return super.visit(node)
    }

    override func visit(_ node: AccessorBlockSyntax) -> AccessorBlockSyntax {
        var result = super.visit(node)

        // Ensure accessor blocks have a leading space
        if result.leadingTrivia.isEmpty {
            result.leadingTrivia = .space
        }

        return result
    }

    override func visit(_ node: InheritedTypeSyntax) -> InheritedTypeSyntax {
        if let identifierType = node.type.as(IdentifierTypeSyntax.self) {
            let typeName = identifierType.name.text
            let resolvedTypeName = resolver.resolveTypeAlias(typeName, in: scope)

            if resolvedTypeName != typeName {
                var newIdentifier = TokenSyntax.identifier(resolvedTypeName)
                newIdentifier.leadingTrivia = identifierType.name.leadingTrivia
                newIdentifier.trailingTrivia = identifierType.name.trailingTrivia

                var newType = IdentifierTypeSyntax(
                    name: newIdentifier,
                    genericArgumentClause: identifierType.genericArgumentClause
                )
                newType.leadingTrivia = identifierType.leadingTrivia
                newType.trailingTrivia = identifierType.trailingTrivia

                return node.with(\.type, TypeSyntax(newType))
            }
        }

        return super.visit(node)
    }

    override func visit(_ node: MemberBlockItemListSyntax) -> MemberBlockItemListSyntax {
        super.visit(node).filter { item in
            !item.decl.is(TypeAliasDeclSyntax.self)
        }
    }
}
