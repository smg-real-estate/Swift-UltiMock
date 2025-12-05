import SwiftSyntax

final class ProtocolMockBuilder: SyntaxBuilder {
    let mockedProtocol: MockedProtocol
    let allMethods: [MockType.Method]

    lazy var allAssociatedTypes = mockedProtocol.allProtocols
        .flatMap { protocolDecl in
            protocolDecl.memberBlock.members.compactMap { member in
                member.decl.as(AssociatedTypeDeclSyntax.self)
            }
        }
        .unique(by: \.name.text)

    init(_ mockedProtocol: MockedProtocol) {
        self.mockedProtocol = mockedProtocol
        self.allMethods = MockType.Method.collectMethods(from: mockedProtocol.allProtocols)
    }

    var mockClassName: String {
        mockedProtocol.declaration.name.text + "Mock"
    }

    var methodsEnum: EnumDeclSyntax {
        EnumDeclSyntax(
            leadingTrivia: .newline,
            enumKeyword: .keyword(.enum, trailingTrivia: .space),
            name: .identifier("Methods"),
            memberBlock: MemberBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                members: MemberBlockItemListSyntax(
                    allMethods.map(\.variableDeclaration).map { MemberBlockItemSyntax(decl: $0) }
                ),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    var genericParameterClause: GenericParameterClauseSyntax? {
        guard !allAssociatedTypes.isEmpty else {
            return nil
        }
        let parameters = allAssociatedTypes.enumerated().map { index, associatedType -> GenericParameterSyntax in
            let inheritedTypes = associatedType.inheritanceClause?.inheritedTypes.map(\.type) ?? []

            let inheritedType: TypeSyntax?
            if inheritedTypes.isEmpty {
                inheritedType = nil
            } else if inheritedTypes.count == 1 {
                inheritedType = inheritedTypes.first
            } else {
                let elements = inheritedTypes.enumerated().map { i, type -> CompositionTypeElementSyntax in
                    CompositionTypeElementSyntax(
                        type: type,
                        ampersand: i < inheritedTypes.count - 1 ? TokenSyntax.binaryOperator("&", leadingTrivia: .space, trailingTrivia: .space) : nil
                    )
                }
                inheritedType = TypeSyntax(CompositionTypeSyntax(elements: CompositionTypeElementListSyntax(elements)))
            }

            return GenericParameterSyntax(
                name: associatedType.name,
                colon: inheritedType != nil ? .colonToken(trailingTrivia: .space) : nil,
                inheritedType: inheritedType,
                trailingComma: index < allAssociatedTypes.count - 1 ? .commaToken(trailingTrivia: .space) : nil
            )
        }

        return GenericParameterClauseSyntax(
            parameters: GenericParameterListSyntax(parameters)
        )
    }

    var methodExpectations: StructDeclSyntax {
        MethodExpectationBuilder(allMethods: allMethods).declaration
    }

    @ArrayBuilder<MemberBlockItemSyntax>
    var properties: [MemberBlockItemSyntax] {
        property(.public, name: "recorder", initializer: InitializerClauseSyntax(
            equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
            value: FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Recorder")),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax([]),
                rightParen: .rightParenToken()
            )
        ))
        .with(\.leadingTrivia, .newline)

        property(name: "fileID", type: "String").with(\.leadingTrivia, .newlines(2))
        property(name: "filePath", type: "StaticString")
        property(name: "line", type: "UInt")
        property(name: "column", type: "Int")
    }

    var initializer: InitializerDeclSyntax {
        InitializerDeclSyntax(
            leadingTrivia: .newline,
            modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]),
            initKeyword: .keyword(.`init`),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(trailingTrivia: .newline + .spaces(4)),
                    parameters: FunctionParameterListSyntax([
                        functionParameter(firstName: "fileID", type: "String", defaultValue: "#fileID"),
                        functionParameter(firstName: "filePath", type: "StaticString", defaultValue: "#filePath"),
                        functionParameter(firstName: "line", type: "UInt", defaultValue: "#line"),
                        functionParameter(firstName: "column", type: "Int", defaultValue: "#column", isLast: true)
                    ]),
                    rightParen: .rightParenToken(leadingTrivia: .newline)
                )
            ),
            body: CodeBlockSyntax(
                leadingTrivia: .space,
                leftBrace: .leftBraceToken(),
                statements: CodeBlockItemListSyntax([
                    assignmentCodeBlockItem(target: "self.fileID", value: "fileID"),
                    assignmentCodeBlockItem(target: "self.filePath", value: "filePath"),
                    assignmentCodeBlockItem(target: "self.line", value: "line"),
                    assignmentCodeBlockItem(target: "self.column", value: "column")
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    @ArrayBuilder<MemberBlockItemSyntax>
    var members: [MemberBlockItemSyntax] {
        properties
        MemberBlockItemSyntax(decl: initializer)
        MemberBlockItemSyntax(decl: methodsEnum)
        MemberBlockItemSyntax(decl: methodExpectations)
        MemberBlockItemSyntax(decl: recordMethod)
        MemberBlockItemSyntax(decl: performMethod)
    }

    var recordMethod: FunctionDeclSyntax {
        FunctionDeclSyntax(
            modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.private, trailingTrivia: .space))]),
            funcKeyword: .keyword(.func, trailingTrivia: .space),
            name: .identifier("_record"),
            genericParameterClause: GenericParameterClauseSyntax(
                parameters: GenericParameterListSyntax([
                    GenericParameterSyntax(name: .identifier("P"))
                ])
            ),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(trailingTrivia: .newline + .spaces(4)),
                    parameters: FunctionParameterListSyntax([
                        functionParameter(
                            secondName: .identifier("expectation"),
                            type: TypeSyntax(MemberTypeSyntax(
                                baseType: IdentifierTypeSyntax(name: .identifier("Recorder")),
                                name: .identifier("Expectation")
                            ))
                        ),
                        functionParameter(secondName: "fileID", type: "String"),
                        functionParameter(secondName: "filePath", type: "StaticString"),
                        functionParameter(secondName: "line", type: "UInt"),
                        functionParameter(secondName: "column", type: "Int"),
                        functionParameter(secondName: "perform", type: "P", isLast: true)
                    ]),
                    rightParen: .rightParenToken(leadingTrivia: .newline)
                )
            ),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        item: .stmt(StmtSyntax(GuardStmtSyntax(
                            guardKeyword: .keyword(.guard, leadingTrivia: .newline + .spaces(4), trailingTrivia: .space),
                            conditions: ConditionElementListSyntax([
                                ConditionElementSyntax(condition: .expression(ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("isEnabled")))))
                            ]),
                            elseKeyword: .keyword(.else, leadingTrivia: .space, trailingTrivia: .space),
                            body: CodeBlockSyntax(
                                leftBrace: .leftBraceToken(trailingTrivia: .newline),
                                statements: CodeBlockItemListSyntax([
                                    CodeBlockItemSyntax(
                                        leadingTrivia: .spaces(8),
                                        item: .expr(ExprSyntax(functionCall(
                                            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("handleFatalFailure")),
                                            arguments: [
                                                labeledExpr(expression: StringLiteralExprSyntax(
                                                    openingQuote: .stringQuoteToken(),
                                                    segments: StringLiteralSegmentListSyntax([
                                                        .stringSegment(StringSegmentSyntax(content: .stringSegment("Setting expectation on disabled mock is not allowed")))
                                                    ]),
                                                    closingQuote: .stringQuoteToken()
                                                )),
                                                labeledExpr(label: "fileID", expression: DeclReferenceExprSyntax(baseName: .identifier("fileID"))),
                                                labeledExpr(label: "filePath", expression: DeclReferenceExprSyntax(baseName: .identifier("filePath"))),
                                                labeledExpr(label: "line", expression: DeclReferenceExprSyntax(baseName: .identifier("line"))),
                                                labeledExpr(label: "column", expression: DeclReferenceExprSyntax(baseName: .identifier("column")), isLast: true)
                                            ]
                                        )))
                                    )
                                ]),
                                rightBrace: .rightBraceToken(leadingTrivia: .newline + .spaces(4))
                            )
                        )))
                    ),
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline + .spaces(4),
                        item: .expr(ExprSyntax(functionCall(
                            calledExpression: MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .identifier("recorder")),
                                name: .identifier("record")
                            ),
                            arguments: [
                                labeledExpr(
                                    expression: functionCall(
                                        calledExpression: MemberAccessExprSyntax(name: .keyword(.`init`)),
                                        arguments: [
                                            labeledExpr(expression: DeclReferenceExprSyntax(baseName: .identifier("expectation"))),
                                            labeledExpr(expression: DeclReferenceExprSyntax(baseName: .identifier("perform"))),
                                            labeledExpr(expression: DeclReferenceExprSyntax(baseName: .identifier("fileID"))),
                                            labeledExpr(expression: DeclReferenceExprSyntax(baseName: .identifier("filePath"))),
                                            labeledExpr(expression: DeclReferenceExprSyntax(baseName: .identifier("line"))),
                                            labeledExpr(expression: DeclReferenceExprSyntax(baseName: .identifier("column")), isLast: true)
                                        ]
                                    ),
                                    isLast: true
                                )
                            ],
                            leftParenTrivia: .newline + .spaces(8),
                            rightParenTrivia: .newline + .spaces(4)
                        )))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    var performMethod: FunctionDeclSyntax {
        FunctionDeclSyntax(
            modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.private, trailingTrivia: .space))]),
            funcKeyword: .keyword(.func, trailingTrivia: .space),
            name: .identifier("_perform"),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(trailingTrivia: .newline + .spaces(4)),
                    parameters: FunctionParameterListSyntax([
                        functionParameter(
                            secondName: "method",
                            type: "MockMethod"
                        ),
                        functionParameter(
                            secondName: "parameters",
                            type: "[Any?]",
                            defaultValue: "[]",
                            isLast: true
                        )
                    ]),
                    rightParen: .rightParenToken(leadingTrivia: .newline)
                ),
                returnClause: ReturnClauseSyntax(
                    arrow: .arrowToken(leadingTrivia: .space, trailingTrivia: .space),
                    type: IdentifierTypeSyntax(name: .identifier("Any"))
                )
            ),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline + .spaces(4),
                        item: .decl(DeclSyntax(VariableDeclSyntax(
                            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
                            bindings: PatternBindingListSyntax([
                                PatternBindingSyntax(
                                    pattern: IdentifierPatternSyntax(identifier: .identifier("invocation")),
                                    initializer: InitializerClauseSyntax(
                                        equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                        value: FunctionCallExprSyntax(
                                            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Invocation")),
                                            leftParen: .leftParenToken(trailingTrivia: .newline + .spaces(8)),
                                            arguments: LabeledExprListSyntax([
                                                labeledExpr(
                                                    label: "method",
                                                    expression: DeclReferenceExprSyntax(baseName: .identifier("method")),
                                                    trailingTrivia: .newline + .spaces(8)
                                                ),
                                                labeledExpr(
                                                    label: "parameters",
                                                    expression: DeclReferenceExprSyntax(baseName: .identifier("parameters")),
                                                    isLast: true
                                                )
                                            ]),
                                            rightParen: .rightParenToken(leadingTrivia: .newline + .spaces(4))
                                        )
                                    )
                                )
                            ])
                        )))
                    ),
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline + .spaces(4),
                        item: .stmt(StmtSyntax(GuardStmtSyntax(
                            guardKeyword: .keyword(.guard, trailingTrivia: .space),
                            conditions: ConditionElementListSyntax([
                                ConditionElementSyntax(
                                    condition: .matchingPattern(MatchingPatternConditionSyntax(
                                        caseKeyword: .keyword(.let, trailingTrivia: .space),
                                        pattern: IdentifierPatternSyntax(identifier: .identifier("stub")),
                                        initializer: InitializerClauseSyntax(
                                            equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                            value: FunctionCallExprSyntax(
                                                calledExpression: MemberAccessExprSyntax(
                                                    base: DeclReferenceExprSyntax(baseName: .identifier("recorder")),
                                                    name: .identifier("next")
                                                ),
                                                leftParen: .leftParenToken(),
                                                arguments: LabeledExprListSyntax([]),
                                                rightParen: .rightParenToken()
                                            )
                                        )
                                    ))
                                )
                            ]),
                            elseKeyword: .keyword(.else, leadingTrivia: .space, trailingTrivia: .space),
                            body: CodeBlockSyntax(
                                leftBrace: .leftBraceToken(trailingTrivia: .newline),
                                statements: CodeBlockItemListSyntax([
                                    CodeBlockItemSyntax(
                                        leadingTrivia: .spaces(8),
                                        item: .expr(ExprSyntax(functionCall(
                                            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("handleFatalFailure")),
                                            arguments: [
                                                labeledExpr(expression: StringLiteralExprSyntax(
                                                    openingQuote: .stringQuoteToken(),
                                                    segments: StringLiteralSegmentListSyntax([
                                                        .stringSegment(StringSegmentSyntax(content: .stringSegment("Expected no calls but received `"))),
                                                        .expressionSegment(ExpressionSegmentSyntax(
                                                            backslash: .backslashToken(),
                                                            leftParen: .leftParenToken(),
                                                            expressions: LabeledExprListSyntax([
                                                                LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("invocation")))
                                                            ]),
                                                            rightParen: .rightParenToken()
                                                        )),
                                                        .stringSegment(StringSegmentSyntax(content: .stringSegment("`")))
                                                    ]),
                                                    closingQuote: .stringQuoteToken()
                                                )),
                                                labeledExpr(label: "fileID", expression: DeclReferenceExprSyntax(baseName: .identifier("fileID"))),
                                                labeledExpr(label: "filePath", expression: DeclReferenceExprSyntax(baseName: .identifier("filePath"))),
                                                labeledExpr(label: "line", expression: DeclReferenceExprSyntax(baseName: .identifier("line"))),
                                                labeledExpr(label: "column", expression: DeclReferenceExprSyntax(baseName: .identifier("column")), isLast: true)
                                            ]
                                        )))
                                    )
                                ]),
                                rightBrace: .rightBraceToken(leadingTrivia: .newline + .spaces(4))
                            )
                        )))
                    ),
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline + .spaces(4),
                        item: .stmt(StmtSyntax(GuardStmtSyntax(
                            guardKeyword: .keyword(.guard, trailingTrivia: .space),
                            conditions: ConditionElementListSyntax([
                                ConditionElementSyntax(
                                    condition: .expression(ExprSyntax(FunctionCallExprSyntax(
                                        calledExpression: MemberAccessExprSyntax(
                                            base: DeclReferenceExprSyntax(baseName: .identifier("stub")),
                                            name: .identifier("matches")
                                        ),
                                        leftParen: .leftParenToken(),
                                        arguments: LabeledExprListSyntax([
                                            LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("invocation")))
                                        ]),
                                        rightParen: .rightParenToken()
                                    )))
                                )
                            ]),
                            elseKeyword: .keyword(.else, leadingTrivia: .space, trailingTrivia: .space),
                            body: CodeBlockSyntax(
                                leftBrace: .leftBraceToken(trailingTrivia: .newline),
                                statements: CodeBlockItemListSyntax([
                                    CodeBlockItemSyntax(
                                        leadingTrivia: .spaces(8),
                                        item: .expr(ExprSyntax(functionCall(
                                            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("handleFatalFailure")),
                                            arguments: [
                                                labeledExpr(expression: StringLiteralExprSyntax(
                                                    openingQuote: .stringQuoteToken(),
                                                    segments: StringLiteralSegmentListSyntax([
                                                        .stringSegment(StringSegmentSyntax(content: .stringSegment("Unexpected call: expected `"))),
                                                        .expressionSegment(ExpressionSegmentSyntax(
                                                            backslash: .backslashToken(),
                                                            leftParen: .leftParenToken(),
                                                            expressions: LabeledExprListSyntax([
                                                                LabeledExprSyntax(expression: MemberAccessExprSyntax(
                                                                    base: DeclReferenceExprSyntax(baseName: .identifier("stub")),
                                                                    name: .identifier("expectation")
                                                                ))
                                                            ]),
                                                            rightParen: .rightParenToken()
                                                        )),
                                                        .stringSegment(StringSegmentSyntax(content: .stringSegment("`, but received `"))),
                                                        .expressionSegment(ExpressionSegmentSyntax(
                                                            backslash: .backslashToken(),
                                                            leftParen: .leftParenToken(),
                                                            expressions: LabeledExprListSyntax([
                                                                LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: .identifier("invocation")))
                                                            ]),
                                                            rightParen: .rightParenToken()
                                                        )),
                                                        .stringSegment(StringSegmentSyntax(content: .stringSegment("`")))
                                                    ]),
                                                    closingQuote: .stringQuoteToken()
                                                )),
                                                labeledExpr(label: "fileID", expression: MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier("stub")), name: .identifier("fileID"))),
                                                labeledExpr(label: "filePath", expression: MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier("stub")), name: .identifier("filePath"))),
                                                labeledExpr(label: "line", expression: MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier("stub")), name: .identifier("line"))),
                                                labeledExpr(label: "column", expression: MemberAccessExprSyntax(base: DeclReferenceExprSyntax(baseName: .identifier("stub")), name: .identifier("column")), isLast: true)
                                            ]
                                        )))
                                    )
                                ]),
                                rightBrace: .rightBraceToken(leadingTrivia: .newline + .spaces(4))
                            )
                        )))
                    ),
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline + .spaces(4),
                        item: .stmt(StmtSyntax(DeferStmtSyntax(
                            deferKeyword: .keyword(.defer, trailingTrivia: .space),
                            body: CodeBlockSyntax(
                                leftBrace: .leftBraceToken(),
                                statements: CodeBlockItemListSyntax([
                                    CodeBlockItemSyntax(
                                        leadingTrivia: .newline + .spaces(8),
                                        item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                            calledExpression: MemberAccessExprSyntax(
                                                base: DeclReferenceExprSyntax(baseName: .identifier("recorder")),
                                                name: .identifier("checkVerification")
                                            ),
                                            leftParen: .leftParenToken(),
                                            arguments: LabeledExprListSyntax([]),
                                            rightParen: .rightParenToken()
                                        )))
                                    )
                                ]),
                                rightBrace: .rightBraceToken(leadingTrivia: .newline + .spaces(4))
                            )
                        )))
                    ),
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline + .spaces(4),
                        item: .stmt(StmtSyntax(ReturnStmtSyntax(
                            returnKeyword: .keyword(.return, trailingTrivia: .space),
                            expression: MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .identifier("stub")),
                                name: .identifier("perform")
                            )
                        )))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    var inheritanceClause: InheritanceClauseSyntax {
        let mockType = IdentifierTypeSyntax(name: .identifier("Mock"))

        let sendableType = IdentifierTypeSyntax(name: .identifier("Sendable"))
        let uncheckedAttribute = AttributeSyntax(
            attributeName: IdentifierTypeSyntax(name: .identifier("unchecked")),
            trailingTrivia: .space
        )
        let uncheckedSendableType = AttributedTypeSyntax(
            attributes: AttributeListSyntax([.attribute(uncheckedAttribute)]),
            baseType: sendableType
        )

        return InheritanceClauseSyntax(
            colon: .colonToken(trailingTrivia: .space),
            inheritedTypes: InheritedTypeListSyntax([
                InheritedTypeSyntax(
                    type: mockType,
                    trailingComma: .commaToken(trailingTrivia: .space)
                ),
                InheritedTypeSyntax(type: uncheckedSendableType)
            ])
        )
    }

    var mockClass: ClassDeclSyntax {
        ClassDeclSyntax(
            classKeyword: .keyword(.class, trailingTrivia: .space),
            name: .identifier(mockClassName),
            genericParameterClause: genericParameterClause,
            inheritanceClause: inheritanceClause,
            memberBlock: MemberBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space, trailingTrivia: .newline),
                members: MemberBlockItemListSyntax(members),
                rightBrace: .rightBraceToken()
            )
        )
    }
}
