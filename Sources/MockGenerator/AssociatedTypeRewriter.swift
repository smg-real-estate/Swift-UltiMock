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
