import SwiftSyntax

struct SubscriptExpectationBuilder: SyntaxBuilder {
    let allSubscripts: [MockType.Subscript]
    let mockName: String
    let isPublic: Bool

    var declaration: StructDeclSyntax {
        StructDeclSyntax(
            modifiers: isPublic ? DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]) : DeclModifierListSyntax([]),
            structKeyword: .keyword(.struct, trailingTrivia: .space),
            name: .identifier("SubscriptExpectation"),
            genericParameterClause: GenericParameterClauseSyntax(
                leftAngle: .leftAngleToken(),
                parameters: GenericParameterListSyntax([
                    GenericParameterSyntax(name: .identifier("Signature"))
                ]),
                rightAngle: .rightAngleToken(trailingTrivia: .space)
            ),
            memberBlock: MemberBlockSyntax(
                leftBrace: .leftBraceToken(),
                members: MemberBlockItemListSyntax(members),
                rightBrace: .rightBraceToken()
            )
        )
    }

    @ArrayBuilder<MemberBlockItemSyntax>
    var members: [MemberBlockItemSyntax] {
        MemberBlockItemSyntax(
            leadingTrivia: .newline,
            decl: methodProperty
        )

        MemberBlockItemSyntax(
            leadingTrivia: .newline,
            decl: parametersProperty
        )

        MemberBlockItemSyntax(
            leadingTrivia: .newline + .newline,
            decl: initializer
        )

        MemberBlockItemSyntax(
            leadingTrivia: .newline + .newline,
            decl: getterExpectationProperty
        )

        MemberBlockItemSyntax(
            leadingTrivia: .newline + .newline,
            decl: setterExpectationMethod
        )

        MemberBlockItemSyntax(
            leadingTrivia: .newline + .newline,
            decl: subscriptStaticProperty
        )
    }

    var methodProperty: VariableDeclSyntax {
        VariableDeclSyntax(
            modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.private, trailingTrivia: .space))]),
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("method")),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: IdentifierTypeSyntax(name: .identifier("MockMethod"))
                    )
                )
            ])
        )
    }

    var parametersProperty: VariableDeclSyntax {
        VariableDeclSyntax(
            modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.private, trailingTrivia: .space))]),
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("parameters")),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: ArrayTypeSyntax(
                            leftSquare: .leftSquareToken(),
                            element: IdentifierTypeSyntax(name: .identifier("AnyParameter")),
                            rightSquare: .rightSquareToken()
                        )
                    )
                )
            ])
        )
    }

    var initializer: InitializerDeclSyntax {
        InitializerDeclSyntax(
            initKeyword: .keyword(.`init`),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: FunctionParameterListSyntax([
                        functionParameter(
                            firstName: "method",
                            type: "MockMethod"
                        ),
                        functionParameter(
                            firstName: "parameters",
                            type: TypeSyntax(ArrayTypeSyntax(
                                leftSquare: .leftSquareToken(),
                                element: IdentifierTypeSyntax(name: .identifier("AnyParameter")),
                                rightSquare: .rightSquareToken()
                            ))
                        )
                    ]
                        .commaSeparated(trailingTrivia: .space)),
                    rightParen: .rightParenToken(trailingTrivia: .space)
                )
            ),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline,
                        item: .expr(ExprSyntax(SequenceExprSyntax(
                            elements: ExprListSyntax([
                                ExprSyntax(MemberAccessExprSyntax(
                                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                                    period: .periodToken(),
                                    name: .identifier("method")
                                )),
                                ExprSyntax(AssignmentExprSyntax(equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space))),
                                ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("method")))
                            ])
                        )))
                    ),
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline,
                        item: .expr(ExprSyntax(SequenceExprSyntax(
                            elements: ExprListSyntax([
                                ExprSyntax(MemberAccessExprSyntax(
                                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                                    period: .periodToken(),
                                    name: .identifier("parameters")
                                )),
                                ExprSyntax(AssignmentExprSyntax(equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space))),
                                ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("parameters")))
                            ])
                        )))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    var getterExpectationProperty: VariableDeclSyntax {
        VariableDeclSyntax(
            modifiers: isPublic ? DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]) : DeclModifierListSyntax([]),
            bindingSpecifier: .keyword(.var, trailingTrivia: .space),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("getterExpectation")),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: MemberTypeSyntax(
                            baseType: IdentifierTypeSyntax(name: .identifier("Recorder")),
                            period: .periodToken(),
                            name: .identifier("Expectation")
                        )
                    ),
                    accessorBlock: AccessorBlockSyntax(
                        leftBrace: .leftBraceToken(),
                        accessors: .getter(CodeBlockItemListSyntax([
                            CodeBlockItemSyntax(
                                leadingTrivia: .newline,
                                item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                    calledExpression: MemberAccessExprSyntax(
                                        period: .periodToken(),
                                        name: .identifier("init")
                                    ),
                                    leftParen: .leftParenToken(),
                                    arguments: LabeledExprListSyntax([
                                        labeledExpr(
                                            label: "method",
                                            expression: DeclReferenceExprSyntax(baseName: .identifier("method"))
                                        ),
                                        labeledExpr(
                                            label: "parameters",
                                            expression: DeclReferenceExprSyntax(baseName: .identifier("parameters"))
                                        )
                                    ]
                                        .commaSeparated(leadingTrivia: .newline)),
                                    rightParen: .rightParenToken(leadingTrivia: .newline)
                                )))
                            )
                        ])),
                        rightBrace: .rightBraceToken(leadingTrivia: .newline)
                    )
                )
            ])
        )
    }

    var setterExpectationMethod: FunctionDeclSyntax {
        FunctionDeclSyntax(
            modifiers: isPublic ? DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]) : DeclModifierListSyntax([]),
            funcKeyword: .keyword(.func, trailingTrivia: .space),
            name: .identifier("setterExpectation"),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(),
                    parameters: FunctionParameterListSyntax([
                        FunctionParameterSyntax(
                            firstName: .wildcardToken(trailingTrivia: .space),
                            secondName: .identifier("newValue"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("AnyParameter"))
                        )
                    ]),
                    rightParen: .rightParenToken(trailingTrivia: .space)
                ),
                returnClause: ReturnClauseSyntax(
                    arrow: .arrowToken(trailingTrivia: .space),
                    type: MemberTypeSyntax(
                        baseType: IdentifierTypeSyntax(name: .identifier("Recorder")),
                        period: .periodToken(),
                        name: .identifier("Expectation")
                    )
                )
            ),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline,
                        item: .expr(ExprSyntax(FunctionCallExprSyntax(
                            calledExpression: MemberAccessExprSyntax(
                                period: .periodToken(),
                                name: .identifier("init")
                            ),
                            leftParen: .leftParenToken(),
                            arguments: LabeledExprListSyntax([
                                labeledExpr(
                                    label: "method",
                                    expression: DeclReferenceExprSyntax(baseName: .identifier("method"))
                                ),
                                labeledExpr(
                                    label: "parameters",
                                    expression: InfixOperatorExprSyntax(
                                        leftOperand: DeclReferenceExprSyntax(baseName: .identifier("parameters")),
                                        operator: BinaryOperatorExprSyntax(
                                            operator: .binaryOperator("+", leadingTrivia: .space, trailingTrivia: .space)
                                        ),
                                        rightOperand: ArrayExprSyntax(
                                            elements: ArrayElementListSyntax([
                                                ArrayElementSyntax(
                                                    expression: DeclReferenceExprSyntax(baseName: .identifier("newValue"))
                                                )
                                            ])
                                        )
                                    )
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

    var subscriptStaticProperty: VariableDeclSyntax {
        VariableDeclSyntax(
            modifiers: DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space)),
                DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
            ]),
            bindingSpecifier: .keyword(.var, trailingTrivia: .space),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("`subscript`")),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: MemberTypeSyntax(
                            baseType: IdentifierTypeSyntax(name: .identifier(mockName)),
                            period: .periodToken(),
                            name: .identifier("SubscriptExpectations")
                        )
                    ),
                    accessorBlock: AccessorBlockSyntax(
                        leftBrace: .leftBraceToken(leadingTrivia: .space),
                        accessors: .getter(CodeBlockItemListSyntax([
                            CodeBlockItemSyntax(
                                leadingTrivia: .newline,
                                item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                    calledExpression: MemberAccessExprSyntax(
                                        period: .periodToken(),
                                        name: .identifier("init")
                                    ),
                                    leftParen: .leftParenToken(),
                                    arguments: LabeledExprListSyntax([]),
                                    rightParen: .rightParenToken()
                                )))
                            )
                        ])),
                        rightBrace: .rightBraceToken(leadingTrivia: .newline)
                    )
                )
            ])
        )
    }

    var subscriptExpectationsStruct: StructDeclSyntax {
        var subscriptMembers: [MemberBlockItemSyntax] = []

        for sub in allSubscripts {
            subscriptMembers.append(MemberBlockItemSyntax(
                leadingTrivia: .newline,
                decl: sub.subscriptExpectationsSubscript(isGetter: true, isPublic: isPublic)
            ))

            if sub.declaration.isReadwrite {
                subscriptMembers.append(MemberBlockItemSyntax(
                    leadingTrivia: .newline + .newline,
                    decl: sub.subscriptExpectationsSubscript(isGetter: false, isPublic: isPublic)
                ))
            }
        }

        return StructDeclSyntax(
            modifiers: isPublic ? DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]) : DeclModifierListSyntax([]),
            structKeyword: .keyword(.struct, trailingTrivia: .space),
            name: .identifier("SubscriptExpectations"),
            memberBlock: MemberBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                members: MemberBlockItemListSyntax(subscriptMembers),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }
}
