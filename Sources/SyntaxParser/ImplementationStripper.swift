import SwiftSyntax

extension SyntaxProtocol {
    func strippingImplementation() -> Self {
        let stripper = ImplementationStripper()
        return stripper.rewrite(self)
            .cast(Self.self)
    }
}

extension AccessorBlockSyntax {
    var isGetterOnly: Bool {
        switch accessors {
        case let .accessors(list):
            list.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) } == false
        case .getter:
            true
        }
    }
}

extension VariableDeclSyntax {
    var hasInitializer: Bool {
        bindings.contains { $0.initializer != nil }
    }
}

final class ImplementationStripper: SyntaxRewriter {
    override func visit(_ node: CodeBlockSyntax) -> CodeBlockSyntax {
        .init(statements: [])
    }

    override func visit(_ node: VariableDeclSyntax) -> DeclSyntax {
        if node.hasInitializer {
            return node.with(\.bindings, PatternBindingListSyntax(
                    node.bindings.map { binding in
                        binding
                            .with(\.typeAnnotation, binding.typeAnnotation?.with(\.trailingTrivia, []))
                            .with(\.initializer, nil)
                    }
                ))
                .cast(DeclSyntax.self)
        }

        if node.bindingSpecifier.tokenKind == .keyword(.let) || node.bindings.first?.accessorBlock?.isGetterOnly == true {
            return node.with(\.bindingSpecifier.tokenKind, .keyword(.var))
                .with(\.bindings, PatternBindingListSyntax(
                    node.bindings.map { binding in
                        binding.with(\.accessorBlock, AccessorBlockSyntax(
                            leftBrace: .leftBraceToken().with(\.trailingTrivia, [.spaces(1)]),
                            accessors: .accessors(AccessorDeclListSyntax([
                                AccessorDeclSyntax(accessorSpecifier: .keyword(.get))
                                    .with(\.leadingTrivia, [])
                                    .with(\.trailingTrivia, [.spaces(1)]),
                            ]))
                        ))
                        .with(\.initializer, nil)
                    }
                ))
                .cast(DeclSyntax.self)
        }

        return node.with(\.bindingSpecifier.tokenKind, .keyword(.var))
            .with(\.bindings, PatternBindingListSyntax(
                node.bindings.map { binding in
                    binding.with(\.accessorBlock, AccessorBlockSyntax(
                        leftBrace: .leftBraceToken().with(\.trailingTrivia, [.spaces(1)]),
                        accessors: .accessors(AccessorDeclListSyntax([
                            AccessorDeclSyntax(accessorSpecifier: .keyword(.get))
                                .with(\.leadingTrivia, [])
                                .with(\.trailingTrivia, [.spaces(1)]),
                            AccessorDeclSyntax(accessorSpecifier: .keyword(.set))
                                .with(\.leadingTrivia, [])
                                .with(\.trailingTrivia, [.spaces(1)]),
                        ]))
                    ))
                    .with(\.initializer, nil)
                }
            ))
            .cast(DeclSyntax.self)
    }
}
