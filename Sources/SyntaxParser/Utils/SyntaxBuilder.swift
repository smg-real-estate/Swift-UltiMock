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
        defaultValue: ExprSyntax? = nil
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
            }
        )
    }

    func functionParameter(
        firstName: String? = nil,
        secondName: String? = nil,
        type: TypeSyntax,
        defaultValue: ExprSyntax? = nil
    ) -> FunctionParameterSyntax {
        functionParameter(
            firstName: firstName.map { .identifier($0) } ?? .wildcardToken(trailingTrivia: .space),
            secondName: secondName.map { .identifier($0) },
            type: type,
            defaultValue: defaultValue
        )
    }

    func functionParameter(
        firstName: String? = nil,
        secondName: String? = nil,
        type: String,
        defaultValue: String? = nil
    ) -> FunctionParameterSyntax {
        functionParameter(
            firstName: firstName.map { .identifier($0) } ?? .wildcardToken(trailingTrivia: .space),
            secondName: secondName.map { .identifier($0) },
            type: TypeSyntax(IdentifierTypeSyntax(name: .identifier(type))),
            defaultValue: defaultValue.map { ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier($0))) }
        )
    }

    func functionCall(
        calledExpression: some ExprSyntaxProtocol,
        arguments: [LabeledExprSyntax],
        leftParenTrivia: Trivia = [],
        rightParenTrivia: Trivia = []
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
        expression: some ExprSyntaxProtocol
    ) -> LabeledExprSyntax {
        LabeledExprSyntax(
            leadingTrivia: leadingTrivia,
            label: label.map { .identifier($0) },
            colon: label != nil ? .colonToken(trailingTrivia: .space) : nil,
            expression: ExprSyntax(expression)
        )
    }

    func tupleTypeElement(
        firstName: TokenSyntax = .wildcardToken(),
        secondName: String,
        type: TypeSyntax
    ) -> TupleTypeElementSyntax {
        TupleTypeElementSyntax(
            firstName: firstName.with(\.trailingTrivia, .space),
            secondName: .identifier(secondName),
            colon: .colonToken(trailingTrivia: .space),
            type: type
        )
    }

    func arrayExpression(
        elements: [some ExprSyntaxProtocol],
        wrapped: Bool = false
    ) -> ArrayExprSyntax {
        if elements.isEmpty {
            ArrayExprSyntax(elements: [])
        } else {
            ArrayExprSyntax(
                leftSquare: .leftSquareToken(),
                elements: ArrayElementListSyntax(
                    elements.map { element in
                        ArrayElementSyntax(expression: ExprSyntax(element))
                    }
                    .commaSeparated(leadingTrivia: wrapped ? .newline : [])
                )
                .with(\.leadingTrivia, wrapped ? .newline : []),
                rightSquare: .rightSquareToken(leadingTrivia: wrapped ? .newline : [])
            )
        }
    }

    func memberAccess(
        base: (some ExprSyntaxProtocol)? = nil,
        name: String
    ) -> MemberAccessExprSyntax {
        MemberAccessExprSyntax(
            base: base.map { ExprSyntax($0) },
            period: .periodToken(),
            name: .identifier(name)
        )
    }

    func typeEffectSpecifiers(
        asyncSpecifier: TokenSyntax?,
        throwsSpecifier: TokenSyntax?
    ) -> TypeEffectSpecifiersSyntax? {
        guard asyncSpecifier != nil || throwsSpecifier != nil else {
            return nil
        }

        let asyncToken = asyncSpecifier?
            .with(\.leadingTrivia, .space)
            .with(\.trailingTrivia, .space)

        let throwsLeading: Trivia = asyncSpecifier == nil ? .space : []
        let throwsToken = throwsSpecifier?
            .with(\.leadingTrivia, throwsLeading)
            .with(\.trailingTrivia, .space)

        return TypeEffectSpecifiersSyntax(
            asyncSpecifier: asyncToken,
            throwsSpecifier: throwsToken
        )
    }

    func genericArgumentClause(
        arguments: [some TypeSyntaxProtocol]
    ) -> GenericArgumentClauseSyntax {
        GenericArgumentClauseSyntax(
            leftAngle: .leftAngleToken(),
            arguments: GenericArgumentListSyntax(
                arguments.map { GenericArgumentSyntax(argument: TypeSyntax($0)) }
            ),
            rightAngle: .rightAngleToken()
        )
    }

    func handleFatalFailure(message: StringLiteralExprSyntax, contextName: String? = nil) -> FunctionCallExprSyntax {
        let expression: (String) -> ExprSyntaxProtocol = if let contextName {
            { parameter in
                MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier(contextName)), name: .identifier(parameter))
            }
        } else {
            { parameter in
                DeclReferenceExprSyntax(baseName: .identifier(parameter))
            }
        }
        return functionCall(
            calledExpression: DeclReferenceExprSyntax(
                baseName: .identifier("handleFatalFailure")
            ),
            arguments: [
                labeledExpr(
                    leadingTrivia: .newline,
                    expression: message
                ),
                labeledExpr(label: "fileID", expression: expression("fileID")),
                labeledExpr(label: "filePath", expression: expression("filePath")),
                labeledExpr(label: "line", expression: expression("line")),
                labeledExpr(label: "column", expression: expression("column"))
            ]
                .commaSeparated(leadingTrivia: .newline),
            rightParenTrivia: .newline
        )
    }
}
