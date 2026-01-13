import SwiftSyntax

final class ImplicitlyUnwrappedOptionalTypeRewriter: SyntaxRewriter, SyntaxBuilder {
    override func visit(_ node: ImplicitlyUnwrappedOptionalTypeSyntax) -> TypeSyntax {
        TypeSyntax(OptionalTypeSyntax(wrappedType: node.wrappedType))
    }
}

extension SyntaxProtocol {
    func replacingImplicitlyUnwrappedOptionals() -> Self {
        let rewriter = ImplicitlyUnwrappedOptionalTypeRewriter()
        return rewriter.rewrite(self).as(Self.self)!
    }
}
