import SwiftSyntax

struct MethodExpectationBuilder {
    let allMethods: [MockType.Method]

    var declaration: StructDeclSyntax {
        StructDeclSyntax(
            leadingTrivia: .newline,
            structKeyword: .keyword(.struct, trailingTrivia: .space),
            name: .identifier("MethodExpectation"),
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
            leadingTrivia: .newline + .spaces(4),
            decl: expectationProperty,
            trailingTrivia: .newline
        )

        MemberBlockItemSyntax(
            leadingTrivia: .newline + .spaces(4),
            decl: initializer,
            trailingTrivia: .newline
        )

        for method in allMethods {
            MemberBlockItemSyntax(
                leadingTrivia: .newline + .spaces(4),
                decl: method.expectationMethodDeclaration,
                trailingTrivia: .newline
            )
        }
    }

    var expectationProperty: VariableDeclSyntax {
        VariableDeclSyntax(
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("expectation")),
                    typeAnnotation: TypeAnnotationSyntax(
                        colon: .colonToken(trailingTrivia: .space),
                        type: MemberTypeSyntax(
                            baseType: IdentifierTypeSyntax(name: .identifier("Recorder")),
                            period: .periodToken(),
                            name: .identifier("Expectation")
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
                        FunctionParameterSyntax(
                            firstName: .identifier("method"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("MockMethod")),
                            trailingComma: .commaToken(trailingTrivia: .space)
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("parameters"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: ArrayTypeSyntax(
                                leftSquare: .leftSquareToken(),
                                element: IdentifierTypeSyntax(name: .identifier("AnyParameter")),
                                rightSquare: .rightSquareToken()
                            )
                        )
                    ]),
                    rightParen: .rightParenToken(trailingTrivia: .space)
                )
            ),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline + .spaces(8),
                        item: .expr(ExprSyntax(SequenceExprSyntax(
                            elements: ExprListSyntax([
                                ExprSyntax(MemberAccessExprSyntax(
                                    base: DeclReferenceExprSyntax(baseName: .keyword(.self)),
                                    period: .periodToken(),
                                    name: .identifier("expectation")
                                )),
                                ExprSyntax(AssignmentExprSyntax(equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space))),
                                ExprSyntax(FunctionCallExprSyntax(
                                    calledExpression: MemberAccessExprSyntax(
                                        period: .periodToken(),
                                        name: .identifier("init")
                                    ),
                                    leftParen: .leftParenToken(),
                                    arguments: LabeledExprListSyntax([
                                        LabeledExprSyntax(
                                            leadingTrivia: .newline + .spaces(12),
                                            label: .identifier("method"),
                                            colon: .colonToken(trailingTrivia: .space),
                                            expression: DeclReferenceExprSyntax(baseName: .identifier("method")),
                                            trailingComma: .commaToken()
                                        ),
                                        LabeledExprSyntax(
                                            leadingTrivia: .newline + .spaces(12),
                                            label: .identifier("parameters"),
                                            colon: .colonToken(trailingTrivia: .space),
                                            expression: DeclReferenceExprSyntax(baseName: .identifier("parameters"))
                                        )
                                    ]),
                                    rightParen: .rightParenToken(leadingTrivia: .newline + .spaces(8))
                                ))
                            ])
                        )))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline + .spaces(4))
            )
        )
    }
}
