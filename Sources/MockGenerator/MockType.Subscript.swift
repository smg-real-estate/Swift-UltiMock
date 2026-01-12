import SwiftParser
import SwiftSyntax

extension MockType {
    final class Subscript: SyntaxBuilder {
        let declaration: SubscriptDeclSyntax
        let mockName: String

        init(declaration: SubscriptDeclSyntax, mockName: String) {
            self.declaration = declaration
            self.mockName = mockName
        }

        static func collectSubscripts(from protocols: [ProtocolDeclSyntax], mockName: String) -> [MockType.Subscript] {
            protocols.flatMap { protocolDecl in
                protocolDecl.memberBlock.members.compactMap { member in
                    member.decl.as(SubscriptDeclSyntax.self)
                }
            }
            .map {
                MockType.Subscript(declaration: $0, mockName: mockName)
            }
        }

        var parameters: FunctionParameterListSyntax {
            declaration.parameterClause.parameters
        }

        lazy var getterFunctionType = declaration.getterFunctionType
        lazy var setterFunctionType = declaration.setterFunctionType

        var stubIdentifier: String {
            var parts: [String] = []

            for param in parameters {
                let label = param.firstName.text
                let secondName = param.secondName?.text
                let paramName = secondName ?? label
                let typeName = param.type.stubIdentifierSlug

                parts.append("\(label)_\(paramName)_\(typeName)")
            }

            parts.append(declaration.returnType.stubIdentifierSlug)

            return parts.joined(separator: "_")
        }

        var getterStubIdentifier: String {
            "subscript_get_\(stubIdentifier)"
        }

        var setterStubIdentifier: String {
            "subscript_set_\(stubIdentifier)"
        }

        var callDescription: String {
            var description = "["
            for (index, param) in parameters.enumerated() {
                if index > 0 {
                    description += ", "
                }

                let label = param.firstName.text
                if label != "_" {
                    description += "\(label): "
                }

                let typeDescription = param.type.description.trimmingCharacters(in: .whitespaces)
                let isStringType = typeDescription == "String"

                if isStringType {
                    description += "\\\"\\($0[\(index)] ?? \"nil\")\\\""
                } else {
                    description += "\\($0[\(index)] ?? \"nil\")"
                }
            }
            description += "]"

            return description
        }

        var setterCallDescription: String {
            let returnTypeDescription = declaration.returnType.description.trimmingCharacters(in: .whitespaces)
            let isStringReturnType = returnTypeDescription == "String"

            if isStringReturnType {
                return "\(callDescription) = \\\"\\($0.last! ?? \"nil\")\\\""
            } else {
                return "\(callDescription) = \\($0.last! ?? \"nil\")"
            }
        }

        var getterVariableDeclaration: VariableDeclSyntax {
            let sourceFile = Parser.parse(source: "\"\(callDescription)\"")
            guard let item = sourceFile.statements.first?.item,
                  case let .expr(expr) = item else {
                fatalError("Failed to parse string literal")
            }

            return VariableDeclSyntax(
                leadingTrivia: .newline,
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                ]),
                bindingSpecifier: .keyword(.var, trailingTrivia: .space),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier(getterStubIdentifier)),
                        typeAnnotation: TypeAnnotationSyntax(
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("MockMethod"))
                        ),
                        accessorBlock: AccessorBlockSyntax(
                            leftBrace: .leftBraceToken(leadingTrivia: .space),
                            accessors: .getter(CodeBlockItemListSyntax([
                                CodeBlockItemSyntax(
                                    item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                        leadingTrivia: .newline,
                                        calledExpression: MemberAccessExprSyntax(
                                            period: .periodToken(),
                                            name: .identifier("init")
                                        ),
                                        arguments: [],
                                        trailingClosure: ClosureExprSyntax(
                                            leftBrace: .leftBraceToken(leadingTrivia: .space),
                                            statements: CodeBlockItemListSyntax([
                                                CodeBlockItemSyntax(
                                                    leadingTrivia: .newline,
                                                    item: .expr(expr)
                                                )
                                            ]),
                                            rightBrace: .rightBraceToken(leadingTrivia: .newline)
                                        )
                                    )))
                                )
                            ])),
                            rightBrace: .rightBraceToken(leadingTrivia: .newline)
                        )
                    )
                ])
            )
        }

        var setterVariableDeclaration: VariableDeclSyntax? {
            guard declaration.isReadwrite else {
                return nil
            }

            let sourceFile = Parser.parse(source: "\"\(setterCallDescription)\"")
            guard let item = sourceFile.statements.first?.item,
                  case let .expr(expr) = item else {
                fatalError("Failed to parse string literal")
            }

            return VariableDeclSyntax(
                leadingTrivia: .newline,
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                ]),
                bindingSpecifier: .keyword(.var, trailingTrivia: .space),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier(setterStubIdentifier)),
                        typeAnnotation: TypeAnnotationSyntax(
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("MockMethod"))
                        ),
                        accessorBlock: AccessorBlockSyntax(
                            leftBrace: .leftBraceToken(leadingTrivia: .space),
                            accessors: .getter(CodeBlockItemListSyntax([
                                CodeBlockItemSyntax(
                                    item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                        leadingTrivia: .newline,
                                        calledExpression: MemberAccessExprSyntax(
                                            period: .periodToken(),
                                            name: .identifier("init")
                                        ),
                                        arguments: [],
                                        trailingClosure: ClosureExprSyntax(
                                            leftBrace: .leftBraceToken(leadingTrivia: .space),
                                            statements: CodeBlockItemListSyntax([
                                                CodeBlockItemSyntax(
                                                    leadingTrivia: .newline,
                                                    item: .expr(expr)
                                                )
                                            ]),
                                            rightBrace: .rightBraceToken(leadingTrivia: .newline)
                                        )
                                    )))
                                )
                            ])),
                            rightBrace: .rightBraceToken(leadingTrivia: .newline)
                        )
                    )
                ])
            )
        }

        func implementation(isPublic: Bool = false) -> SubscriptDeclSyntax {
            guard let accessorBlock = declaration.accessorBlock else {
                return declaration
            }

            var newAccessors: [AccessorDeclSyntax] = []

            switch accessorBlock.accessors {
            case let .accessors(accessorList):
                for accessor in accessorList {
                    let accessorKind = accessor.accessorSpecifier.tokenKind

                    if accessorKind == .keyword(.get) {
                        newAccessors.append(buildGetAccessor(effectSpecifiers: accessor.effectSpecifiers))
                    } else if accessorKind == .keyword(.set) {
                        newAccessors.append(buildSetAccessor())
                    }
                }
            case .getter:
                newAccessors.append(buildGetAccessor(effectSpecifiers: nil))
            }

            let newAccessorBlock = AccessorBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                accessors: .accessors(AccessorDeclListSyntax(newAccessors)),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )

            let modifiers: DeclModifierListSyntax = isPublic ? DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))
            ]) : DeclModifierListSyntax([])

            return declaration
                .with(\.modifiers, modifiers)
                .with(\.subscriptKeyword, declaration.subscriptKeyword.with(\.leadingTrivia, []))
                .with(\.accessorBlock, newAccessorBlock)
        }

        var getterExpect: FunctionDeclSyntax {
            buildExpectFunction(
                expectationType: "SubscriptExpectation",
                signatureType: getterFunctionType,
                expectationPropertyName: "getterExpectation",
                isPublic: true
            )
        }

        var setterExpect: FunctionDeclSyntax {
            buildSetterExpectFunction(
                expectationType: "SubscriptExpectation",
                signatureType: setterFunctionType,
                valueType: declaration.returnType.replacingImplicitlyUnwrappedOptionals(),
                isPublic: true,
                numberOfClosureParameters: parameters.count + 1
            )
        }

        func subscriptExpectationsSubscript(isGetter: Bool, isPublic: Bool) -> SubscriptDeclSyntax {
            let expectationParameters = parameters.map { param -> FunctionParameterSyntax in
                let firstName = param.firstName
                let paramType = IdentifierTypeSyntax(
                    name: .identifier("Parameter"),
                    genericArgumentClause: GenericArgumentClauseSyntax(
                        arguments: GenericArgumentListSyntax([
                            GenericArgumentSyntax(argument: param.type.replacingImplicitlyUnwrappedOptionals())
                        ])
                    )
                )

                return FunctionParameterSyntax(
                    firstName: firstName,
                    colon: .colonToken(trailingTrivia: .space),
                    type: paramType
                )
            }

            let signatureType: FunctionTypeSyntax = isGetter ? getterFunctionType : setterFunctionType
            let stubIdentifier = isGetter ? getterStubIdentifier : setterStubIdentifier

            let argumentsArray = parameters.map { param -> MemberAccessExprSyntax in
                let paramName = param.secondName?.text ?? param.firstName.text
                return memberAccess(
                    base: DeclReferenceExprSyntax(baseName: .identifier(paramName)),
                    name: "anyParameter"
                )
            }

            return SubscriptDeclSyntax(
                modifiers: isPublic ? DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]) : DeclModifierListSyntax([]),
                subscriptKeyword: .keyword(.subscript),
                parameterClause: FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax(expectationParameters.commaSeparated())
                ),
                returnClause: ReturnClauseSyntax(
                    arrow: .arrowToken(leadingTrivia: .space, trailingTrivia: .space),
                    type: MemberTypeSyntax(
                        baseType: IdentifierTypeSyntax(name: .identifier(mockName)),
                        name: .identifier("SubscriptExpectation"),
                        genericArgumentClause: genericArgumentClause(arguments: [signatureType])
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
                                arguments: LabeledExprListSyntax([
                                    labeledExpr(
                                        label: "method",
                                        expression: memberAccess(
                                            base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
                                            name: stubIdentifier
                                        )
                                    ),
                                    labeledExpr(
                                        label: "parameters",
                                        expression: arrayExpression(elements: argumentsArray)
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
        }
    }
}

private extension MockType.Subscript {
    func buildGetAccessor(effectSpecifiers: AccessorEffectSpecifiersSyntax?) -> AccessorDeclSyntax {
        let methodReference = memberAccess(
            base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
            name: getterStubIdentifier
        )

        let parameterReferences = Array(parameters).map(\.reference)

        var performArguments = [
            labeledExpr(expression: methodReference)
        ]

        if !parameterReferences.isEmpty {
            performArguments.append(
                labeledExpr(expression: arrayExpression(elements: parameterReferences))
            )
        }

        let performCall = functionCall(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_perform")),
            arguments: performArguments.commaSeparated(leadingTrivia: .newline),
            rightParenTrivia: .newline
        )

        let castExpression = ExprSyntax(SequenceExprSyntax(
            elements: ExprListSyntax([
                ExprSyntax(performCall),
                ExprSyntax(BinaryOperatorExprSyntax(
                    operator: .binaryOperator("as!", leadingTrivia: .space, trailingTrivia: .space)
                )),
                ExprSyntax(TypeExprSyntax(
                    type: getterFunctionType
                        .with(\.effectSpecifiers, effectSpecifiers?.asTypeEffectSpecifiersSyntax))
                )
            ])
        ))

        let letPerform = VariableDeclSyntax(
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("perform")),
                    initializer: InitializerClauseSyntax(
                        equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                        value: castExpression
                    )
                )
            ])
        )

        let invocationArguments = LabeledExprListSyntax(
            parameters.map { parameter in
                LabeledExprSyntax(expression: parameter.invocationExpression)
            }
            .commaSeparated()
        )

        let performInvocation = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("perform")),
            leftParen: .leftParenToken(),
            arguments: invocationArguments,
            rightParen: .rightParenToken()
        )

        var returnExpression = ExprSyntax(performInvocation)

        if effectSpecifiers?.asyncSpecifier != nil {
            returnExpression = ExprSyntax(AwaitExprSyntax(
                awaitKeyword: .keyword(.await, trailingTrivia: .space),
                expression: returnExpression
            ))
        }

        if effectSpecifiers?.throwsSpecifier != nil {
            returnExpression = ExprSyntax(TryExprSyntax(
                tryKeyword: .keyword(.try, trailingTrivia: .space),
                questionOrExclamationMark: nil,
                expression: returnExpression
            ))
        }

        let returnStatement = ReturnStmtSyntax(
            returnKeyword: .keyword(.return, trailingTrivia: .space),
            expression: returnExpression
        )

        let accessorEffects = AccessorEffectSpecifiersSyntax(
            asyncSpecifier: effectSpecifiers?.asyncSpecifier?.with(\.leadingTrivia, .space).with(\.trailingTrivia, []),
            throwsSpecifier: effectSpecifiers?.throwsSpecifier?.with(
                \.leadingTrivia,
                effectSpecifiers?.asyncSpecifier == nil ? .space : .space
            ).with(\.trailingTrivia, [])
        )

        return AccessorDeclSyntax(
            leadingTrivia: .newline,
            accessorSpecifier: .keyword(.get),
            effectSpecifiers: accessorEffects.asyncSpecifier == nil && accessorEffects.throwsSpecifier == nil ? nil : accessorEffects,
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline,
                        item: .decl(DeclSyntax(letPerform))
                    ),
                    CodeBlockItemSyntax(
                        item: .stmt(StmtSyntax(returnStatement))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    func buildSetAccessor() -> AccessorDeclSyntax {
        let methodReference = memberAccess(
            base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
            name: setterStubIdentifier
        )

        var parameterReferences: [DeclReferenceExprSyntax] = Array(parameters).map(\.reference)
        parameterReferences.append(DeclReferenceExprSyntax(baseName: .identifier("newValue")))

        let performCall = functionCall(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_perform")),
            arguments: [
                labeledExpr(expression: methodReference),
                labeledExpr(expression: arrayExpression(elements: parameterReferences))
            ].commaSeparated(leadingTrivia: .newline),
            rightParenTrivia: .newline
        )

        let castExpression = ExprSyntax(SequenceExprSyntax(
            elements: ExprListSyntax([
                ExprSyntax(performCall),
                ExprSyntax(BinaryOperatorExprSyntax(
                    operator: .binaryOperator("as!", leadingTrivia: .space, trailingTrivia: .space)
                )),
                ExprSyntax(TypeExprSyntax(type: setterFunctionType))
            ])
        ))

        let letPerform = VariableDeclSyntax(
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier("perform")),
                    initializer: InitializerClauseSyntax(
                        equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                        value: castExpression
                    )
                )
            ])
        )

        var invocationArguments: [LabeledExprSyntax] = parameters.map { parameter in
            LabeledExprSyntax(expression: parameter.invocationExpression)
        }
        invocationArguments.append(LabeledExprSyntax(
            expression: DeclReferenceExprSyntax(baseName: .identifier("newValue"))
        ))

        let performInvocation = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("perform")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax(invocationArguments.commaSeparated()),
            rightParen: .rightParenToken()
        )

        let returnStatement = ReturnStmtSyntax(
            returnKeyword: .keyword(.return, trailingTrivia: .space),
            expression: ExprSyntax(performInvocation)
        )

        return AccessorDeclSyntax(
            leadingTrivia: .newline,
            accessorSpecifier: .keyword(.set),
            body: CodeBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                statements: CodeBlockItemListSyntax([
                    CodeBlockItemSyntax(
                        leadingTrivia: .newline,
                        item: .decl(DeclSyntax(letPerform))
                    ),
                    CodeBlockItemSyntax(
                        item: .stmt(StmtSyntax(returnStatement))
                    )
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }
}
