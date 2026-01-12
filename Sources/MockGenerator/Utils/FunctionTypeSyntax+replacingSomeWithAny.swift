import SwiftSyntax

extension FunctionTypeSyntax {
    func replacingSomeWithAny() -> Self {
        SomeWithAnyRewriter().rewrite(self)
            .cast(FunctionTypeSyntax.self)
    }
}

private final class SomeWithAnyRewriter: SyntaxRewriter {
    override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
        SomeOrAnyTypeSyntax(
            someOrAnySpecifier: .keyword(.any, trailingTrivia: .space),
            constraint: node.constraint
        )
        .cast(TypeSyntax.self)
    }
}
