import SwiftSyntax

final class AssociatedTypeRewriter: SyntaxRewriter {
    let replacements: [String: TypeSyntax]

    init(replacements: [String: TypeSyntax]) {
        self.replacements = replacements
    }

    override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
        if let replacement = replacements[node.name.text] {
            return replacement.trimmed
        }
        return TypeSyntax(node)
    }
}

extension TypeSyntax {
    func replacingAssociatedTypes(with resolver: AssociatedTypeResolver) -> TypeSyntax {
        let rewriter = AssociatedTypeRewriter(replacements: resolver.sameTypeConstraints)
        return rewriter.rewrite(self).as(TypeSyntax.self) ?? self
    }
}

extension FunctionTypeSyntax {
    func replacingAssociatedTypes(with resolver: AssociatedTypeResolver) -> FunctionTypeSyntax {
        let rewriter = AssociatedTypeRewriter(replacements: resolver.sameTypeConstraints)
        return rewriter.rewrite(self).as(FunctionTypeSyntax.self) ?? self
    }
}
