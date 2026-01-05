import SwiftSyntax

struct MethodExpectationBuilder: SyntaxBuilder {
    let mockName: String
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
            leadingTrivia: .newline,
            decl: expectationProperty
        )

        MemberBlockItemSyntax(
            leadingTrivia: .newlines(2),
            decl: initializer,
        )

        for method in allMethods {
            MemberBlockItemSyntax(
                leadingTrivia: .newlines(2),
                decl: method.expectationMethodDeclaration(mockName: mockName),
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
                                    name: .identifier("expectation")
                                )),
                                ExprSyntax(AssignmentExprSyntax(equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space))),
                                ExprSyntax(functionCall(
                                    calledExpression: MemberAccessExprSyntax(
                                        period: .periodToken(),
                                        name: .identifier("init")
                                    ),
                                    arguments: [
                                        labeledExpr(
                                            leadingTrivia: .newline,
                                            label: "method",
                                            expression: DeclReferenceExprSyntax(baseName: .identifier("method"))
                                        ),
                                        labeledExpr(
                                            leadingTrivia: .newline,
                                            label: "parameters",
                                            expression: DeclReferenceExprSyntax(baseName: .identifier("parameters"))
                                        )
                                    ]
                                        .commaSeparated(leadingTrivia: .newline),
                                    leftParenTrivia: [],
                                    rightParenTrivia: .newline
                                ))
                            ])
                        )))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }
}
