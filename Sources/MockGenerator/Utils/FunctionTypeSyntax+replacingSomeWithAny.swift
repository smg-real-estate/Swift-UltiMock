import SwiftSyntax

extension FunctionTypeSyntax {
    func replacingSomeWithAny() -> Self {
        SomeWithAnyRewriter().rewrite(self)
            .as(FunctionTypeSyntax.self)!
    }
}

private final class SomeWithAnyRewriter: SyntaxRewriter {
    override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
        TypeSyntax(
            SomeOrAnyTypeSyntax(
                someOrAnySpecifier: .keyword(.any, trailingTrivia: .space),
                constraint: node.constraint
            )
        )
    }
}
