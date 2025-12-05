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

    func assignmentCodeBlockItem(
        target: String,
        value: ExprSyntax,
        isLast: Bool = false
    ) -> CodeBlockItemSyntax {
        CodeBlockItemSyntax(
            leadingTrivia: .newline + .spaces(4),
            item: .expr(ExprSyntax(SequenceExprSyntax(
                elements: ExprListSyntax([
                    ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(target))),
                    ExprSyntax(AssignmentExprSyntax(equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space))),
                    value
                ])
            ))),
            trailingTrivia: isLast ? .newline : []
        )
    }

    func functionParameter(
        firstName: TokenSyntax = .wildcardToken(trailingTrivia: .space),
        secondName: TokenSyntax? = nil,
        type: TypeSyntax,
        defaultValue: ExprSyntax? = nil,
        trailingTrivia: Trivia = .newline + .spaces(4),
        isLast: Bool = false
    ) -> FunctionParameterSyntax {
        FunctionParameterSyntax(
            firstName: firstName,
            secondName: secondName,
            colon: .colonToken(trailingTrivia: .space),
            type: type,
            defaultValue: defaultValue.map {
                InitializerClauseSyntax(
                    equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                    value: $0
                )
            },
            trailingComma: isLast ? nil : .commaToken(trailingTrivia: trailingTrivia)
        )
    }

    func functionParameter(
        firstName: String? = nil,
        secondName: String? = nil,
        type: TypeSyntax,
        defaultValue: ExprSyntax? = nil,
        trailingTrivia: Trivia = .newline + .spaces(4),
        isLast: Bool = false
    ) -> FunctionParameterSyntax {
        functionParameter(
            firstName: firstName.map { .identifier($0) } ?? .wildcardToken(trailingTrivia: .space),
            secondName: secondName.map { .identifier($0) },
            type: type,
            defaultValue: defaultValue,
            trailingTrivia: trailingTrivia,
            isLast: isLast
        )
    }

    func functionParameter(
        firstName: String? = nil,
        secondName: String? = nil,
        type: String,
        defaultValue: String? = nil,
        trailingTrivia: Trivia = .newline + .spaces(4),
        isLast: Bool = false
    ) -> FunctionParameterSyntax {
        functionParameter(
            firstName: firstName.map { .identifier($0) } ?? .wildcardToken(trailingTrivia: .space),
            secondName: secondName.map { .identifier($0) },
            type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(type))),
            defaultValue: defaultValue.map { ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier($0))) },
            trailingTrivia: trailingTrivia,
            isLast: isLast
        )
    }

    func functionCall(
        calledExpression: some ExprSyntaxProtocol,
        arguments: [LabeledExprSyntax],
        leftParenTrivia: Trivia = .newline + .spaces(12),
        rightParenTrivia: Trivia = .newline + .spaces(8)
    ) -> FunctionCallExprSyntax {
        FunctionCallExprSyntax(
            calledExpression: ExprSyntax(calledExpression),
            leftParen: .leftParenToken(trailingTrivia: leftParenTrivia),
            arguments: LabeledExprListSyntax(arguments),
            rightParen: .rightParenToken(leadingTrivia: rightParenTrivia)
        )
    }

    func labeledExpr(
        leadingTrivia: Trivia = [],
        label: String? = nil,
        expression: some ExprSyntaxProtocol,
        trailingTrivia: Trivia = .newline + .spaces(12),
        isLast: Bool = false
    ) -> LabeledExprSyntax {
        LabeledExprSyntax(
            leadingTrivia: leadingTrivia,
            label: label.map { .identifier($0) },
            colon: label != nil ? .colonToken(trailingTrivia: .space) : nil,
            expression: ExprSyntax(expression),
            trailingComma: isLast ? nil : .commaToken(trailingTrivia: trailingTrivia)
        )
    }
}
