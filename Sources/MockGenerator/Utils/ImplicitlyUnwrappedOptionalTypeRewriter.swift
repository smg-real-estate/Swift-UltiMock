import SwiftSyntax

final class ImplicitlyUnwrappedOptionalTypeRewriter: SyntaxRewriter, SyntaxBuilder {
    override func visit(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) -> TypeSyntax {
        OptionalTypeSyntax(wrappedType: node.wrappedType).cast(TypeSyntax.self)
    }
}

extension SyntaxProtocol {
    func replacingImplicitlyUnwrappedOptionals() -> Self {
        let rewriter = ImplicitlyUnwrappedOptionalTypeRewriter()
        return rewriter.rewrite(self).cast(Self.self)
    }
}
