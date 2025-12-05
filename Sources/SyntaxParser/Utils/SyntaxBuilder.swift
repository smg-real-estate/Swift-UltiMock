import SwiftSyntax

protocol SyntaxBuilder {}

extension SyntaxBuilder {
    func property(
        _ accessLevel: Keyword = .private,
        name: String,
        type: String? = nil,
        initializer: InitializerClauseSyntax? = nil
    ) -> MemberBlockItemSyntax {
        MemberBlockItemSyntax(
            leadingTrivia: .newline,
            decl: VariableDeclSyntax(
                modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(accessLevel, trailingTrivia: .space))]),
                bindingSpecifier: .keyword(.let, trailingTrivia: .space),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
                        typeAnnotation: type.map {
                            TypeAnnotationSyntax(
                                colon: .colonToken(trailingTrivia: .space),
                                type: IdentifierTypeSyntax(name: .identifier($0))
                            )
                        },
                        initializer: initializer
                    )
                ])
            )
        )
    }

    func assignmentCodeBlockItem(
        target: String,
        value: String,
        isLast: Bool = false
    ) -> CodeBlockItemSyntax {
        CodeBlockItemSyntax(
            leadingTrivia: .newline + .spaces(4),
            item: .expr(ExprSyntax(SequenceExprSyntax(
                elements: ExprListSyntax([
                    ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(target))),
                    ExprSyntax(AssignmentExprSyntax(equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space))),
                    ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(value)))
                ])
            ))),
            trailingTrivia: isLast ? .newline : []
        )
    }
}
