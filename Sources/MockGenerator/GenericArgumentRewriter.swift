import SwiftSyntax

final class GenericArgumentRewriter: SyntaxRewriter {
    let substitutions: [String: TypeSyntax]

    init(substitutions: [String: TypeSyntax]) {
        self.substitutions = substitutions
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: IdentifierTypeSyntax) -> TypeSyntax {
        if let replacement = substitutions[node.name.text] {
            return replacement.with(\.leadingTrivia, node.leadingTrivia).with(\.trailingTrivia, node.trailingTrivia)
        }
        return super.visit(node)
    }
}
