import SwiftSyntax

extension SyntaxProtocol {
    func strippingImplementation() -> Self {
        let stripper = ImplementationStripper()
        return stripper.rewrite(self)
            .cast(Self.self)
    }
}

final class ImplementationStripper: SyntaxRewriter {
    let accessorStripper = AccessorBlockStripper()

    override func visit(_ node: CodeBlockSyntax) -> CodeBlockSyntax {
        .init(statements: [])
    }

    override func visit(_ node: AccessorBlockSyntax) -> AccessorBlockSyntax {
        accessorStripper.rewrite(node).cast(AccessorBlockSyntax.self)
    }
}

final class AccessorBlockStripper: SyntaxRewriter {
    override func visit(_ node: AccessorDeclListSyntax) -> AccessorDeclListSyntax {
        super.visit(node).with(\.trailingTrivia, [.spaces(1)])
    }

    override func visit(_ token: TokenSyntax) -> TokenSyntax {
        token.trimmed
    }

    override func visitAny(_ node: SwiftSyntax.Syntax) -> SwiftSyntax.Syntax? {
        if node.kind == .codeBlockItemList {
            return SwiftSyntax.Syntax(AccessorDeclListSyntax([
                AccessorDeclSyntax(accessorSpecifier: .keyword(.get))
                    .with(\.leadingTrivia, [.spaces(1)])
                    .with(\.trailingTrivia, [.spaces(1)])
            ]))
        }
        return nil
    }

    override func visit(_ node: AccessorDeclSyntax) -> DeclSyntax {
        AccessorDeclSyntax(
            attributes: node.attributes,
            accessorSpecifier: node.accessorSpecifier
        )
        .with(\.leadingTrivia, [.spaces(1)])
        .with(\.trailingTrivia, [])
        .cast(DeclSyntax.self)
    }
}
