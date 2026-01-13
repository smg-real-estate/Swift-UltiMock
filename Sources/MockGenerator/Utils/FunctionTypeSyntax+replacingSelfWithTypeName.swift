import SwiftSyntax

extension FunctionTypeSyntax {
    func replacingSelfWithTypeName(_ name: String) -> Self {
        SelfWithTypeNameRewriter(
            replacement: .identifier(name)
        )
        .rewrite(self)
        .as(FunctionTypeSyntax.self)!
    }
}

private final class SelfWithTypeNameRewriter: SyntaxRewriter {
    let replacement: TokenSyntax

    init(replacement: TokenSyntax) {
        self.replacement = replacement
        super.init()
    }

    override func visit(_ token: TokenSyntax) -> TokenSyntax {
        if token.tokenKind == .keyword(.Self) {
            replacement
        } else {
            super.visit(token)
        }
    }
}
