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

    func closureDefaultValue(numberOfParameters: Int = 0) -> InitializerClauseSyntax {
        InitializerClauseSyntax(
            equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
            value: ExprSyntax(
                ClosureExprSyntax(
                    leftBrace: .leftBraceToken(trailingTrivia: .space),
                    signature: numberOfParameters == 0 ? nil : ClosureSignatureSyntax(
                        parameterClause: .simpleInput(
                            ClosureShorthandParameterListSyntax((0 ..< numberOfParameters).map { _ in
                                ClosureShorthandParameterSyntax(name: .wildcardToken(trailingTrivia: .space))
                            })
                        ),
                        inKeyword: .keyword(.in, trailingTrivia: .space)
                    ),
                    statements: CodeBlockItemListSyntax([]),
                    rightBrace: .rightBraceToken(leadingTrivia: [])
                ).with(\.rightBrace, .rightBraceToken())
            )
        )
    }

    func buildExpectFunction(
        expectationType: String,
        signatureType: FunctionTypeSyntax,
        expectationPropertyName: String = "expectation",
        genericParameterClause: GenericParameterClauseSyntax? = nil,
        isPublic: Bool = true
    ) -> FunctionDeclSyntax {
        FunctionDeclSyntax(
            modifiers: isPublic ? DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]) : DeclModifierListSyntax([]),
            funcKeyword: .keyword(.func, trailingTrivia: .space),
            name: .identifier("expect"),
            genericParameterClause: genericParameterClause,
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: FunctionParameterListSyntax([
                        FunctionParameterSyntax(
                            leadingTrivia: .newline,
                            firstName: .wildcardToken(),
                            secondName: .identifier("expectation", leadingTrivia: .space),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(
                                name: .identifier(expectationType),
                                genericArgumentClause: genericArgumentClause(arguments: [
                                    signatureType
                                ])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("fileID"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("String")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: MacroExpansionExprSyntax(macroName: .identifier("fileID"), arguments: [])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("filePath"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("StaticString")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: MacroExpansionExprSyntax(macroName: .identifier("filePath"), arguments: [])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("line"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("UInt")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: MacroExpansionExprSyntax(macroName: .identifier("line"), arguments: [])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("column"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("Int")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: MacroExpansionExprSyntax(macroName: .identifier("column"), arguments: [])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("perform"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: AttributedTypeSyntax(
                                attributes: AttributeListSyntax([
                                    .attribute(AttributeSyntax(
                                        atSign: .atSignToken(),
                                        attributeName: IdentifierTypeSyntax(name: .identifier("escaping", trailingTrivia: .space))
                                    ))
                                ]),
                                baseType: TypeSyntax(signatureType)
                            ),
                            defaultValue: signatureType.returnClause.type.isVoid
                                ? closureDefaultValue(numberOfParameters: signatureType.parameters.count)
                                : nil
                        )
                    ]),
                    rightParen: .rightParenToken(leadingTrivia: .newline)
                )
            ),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline,
                        item: .expr(ExprSyntax(FunctionCallExprSyntax(
                            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_record")),
                            leftParen: .leftParenToken(),
                            arguments: LabeledExprListSyntax([
                                labeledExpr(
                                    leadingTrivia: .newline,
                                    expression: memberAccess(
                                        base: DeclReferenceExprSyntax(baseName: .identifier("expectation")),
                                        name: expectationPropertyName
                                    )
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("fileID"))
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("filePath"))
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("line"))
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("column"))
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("perform"))
                                )
                            ]
                                .commaSeparated(leadingTrivia: .newline)),
                            rightParen: .rightParenToken(leadingTrivia: .newline)
                        )))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    func buildSetterExpectFunction(
        expectationType: String,
        signatureType: some TypeSyntaxProtocol,
        valueType: some TypeSyntaxProtocol,
        isPublic: Bool = true
    ) -> FunctionDeclSyntax {
        FunctionDeclSyntax(
            modifiers: isPublic ? DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]) : DeclModifierListSyntax([]),
            funcKeyword: .keyword(.func, trailingTrivia: .space),
            name: .identifier("expect"),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: FunctionParameterListSyntax([
                        FunctionParameterSyntax(
                            leadingTrivia: .newline,
                            firstName: .identifier("set"),
                            secondName: .identifier("expectation", leadingTrivia: .space),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(
                                name: .identifier(expectationType),
                                genericArgumentClause: genericArgumentClause(arguments: [
                                    signatureType
                                ])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("to"),
                            secondName: .identifier("newValue", leadingTrivia: .space),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(
                                name: .identifier("Parameter"),
                                genericArgumentClause: genericArgumentClause(arguments: [
                                    valueType
                                ])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("fileID"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("String")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: MacroExpansionExprSyntax(macroName: .identifier("fileID"), arguments: [])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("filePath"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("StaticString")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: MacroExpansionExprSyntax(macroName: .identifier("filePath"), arguments: [])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("line"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("UInt")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: MacroExpansionExprSyntax(macroName: .identifier("line"), arguments: [])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("column"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("Int")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: MacroExpansionExprSyntax(macroName: .identifier("column"), arguments: [])
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("perform"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: AttributedTypeSyntax(
                                attributes: AttributeListSyntax([
                                    .attribute(AttributeSyntax(
                                        atSign: .atSignToken(),
                                        attributeName: IdentifierTypeSyntax(name: .identifier("escaping", trailingTrivia: .space))
                                    ))
                                ]),
                                baseType: TypeSyntax(signatureType)
                            ),
                            defaultValue: closureDefaultValue(numberOfParameters: 1)
                        )
                    ]),
                    rightParen: .rightParenToken(leadingTrivia: .newline)
                )
            ),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline,
                        item: .expr(ExprSyntax(FunctionCallExprSyntax(
                            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_record")),
                            leftParen: .leftParenToken(),
                            arguments: LabeledExprListSyntax([
                                labeledExpr(
                                    leadingTrivia: .newline,
                                    expression: FunctionCallExprSyntax(
                                        calledExpression: memberAccess(
                                            base: DeclReferenceExprSyntax(baseName: .identifier("expectation")),
                                            name: "setterExpectation"
                                        ),
                                        leftParen: .leftParenToken(),
                                        arguments: LabeledExprListSyntax([
                                            LabeledExprSyntax(
                                                expression: memberAccess(
                                                    base: DeclReferenceExprSyntax(baseName: .identifier("newValue")),
                                                    name: "anyParameter"
                                                )
                                            )
                                        ]),
                                        rightParen: .rightParenToken()
                                    )
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("fileID"))
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("filePath"))
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("line"))
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("column"))
                                ),
                                labeledExpr(
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("perform"))
                                )
                            ]
                                .commaSeparated(leadingTrivia: .newline)),
                            rightParen: .rightParenToken(leadingTrivia: .newline)
                        )))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }
}
