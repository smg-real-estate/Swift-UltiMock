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
        guard let resolvedType = resolver.resolveTypeAlias(node, in: scope) else {
            return super.visit(node)
        }

        return TypeSyntax(resolvedType)
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
        guard let resolvedType = resolver.resolveTypeAlias(node.type, in: scope) else {
            return super.visit(node)
        }

        return node.with(
            \.type,
            TypeSyntax(resolvedType)
                .with(\.trailingTrivia, node.type.trailingTrivia)
        )
    }

    override func visit(_ node: MemberBlockItemListSyntax) -> MemberBlockItemListSyntax {
        super.visit(node).filter { item in
            !item.decl.is(TypeAliasDeclSyntax.self)
        }
    }
}
