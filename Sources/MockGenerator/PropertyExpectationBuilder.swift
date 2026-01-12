import SwiftSyntax

struct PropertyExpectationBuilder: SyntaxBuilder {
    let allMethods: [MockType.Method]
    let isPublic: Bool

    var declaration: StructDeclSyntax {
        StructDeclSyntax(
            modifiers: isPublic ? DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]) : DeclModifierListSyntax([]),
            structKeyword: .keyword(.struct, trailingTrivia: .space),
            name: .identifier("PropertyExpectation"),
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
                        )
                    ]),
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
                                            expression: ArrayExprSyntax(
                                                leftSquare: .leftSquareToken(),
                                                elements: ArrayElementListSyntax([]),
                                                rightSquare: .rightSquareToken()
                                            )
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
                                    expression: ArrayExprSyntax(
                                        leftSquare: .leftSquareToken(),
                                        elements: ArrayElementListSyntax([
                                            ArrayElementSyntax(
                                                expression: DeclReferenceExprSyntax(baseName: .identifier("newValue"))
                                            )
                                        ]),
                                        rightSquare: .rightSquareToken()
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
}
