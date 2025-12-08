import SwiftParser
import SwiftSyntax

extension MockType {
    struct Method {
        let declaration: FunctionDeclSyntax

        static func collectMethods(from protocols: [ProtocolDeclSyntax]) -> [MockType.Method] {
            protocols.flatMap { protocolDecl in
                protocolDecl.memberBlock.members.compactMap { member in
                    member.decl.as(FunctionDeclSyntax.self)
                }
            }.map { MockType.Method(declaration: $0) }
        }

        var stubIdentifier: String {
            var parts: [String] = []
            var name = declaration.name.text.replacingOccurrences(of: "`", with: "")

            let parameters = declaration.signature.parameterClause.parameters
            let isAsync = declaration.signature.effectSpecifiers?.asyncSpecifier != nil

            if isAsync, !parameters.isEmpty {
                name += "_async"
            }
            parts.append(name)

            for param in parameters {
                let label = param.firstName.text
                let typeName = param.type.description.trimmingCharacters(in: .whitespaces)

                if label == "_" {
                    let paramName = param.secondName?.text ?? ""
                    if paramName == "anonymous" {
                        parts.append("_\(typeName)")
                    } else {
                        parts.append("_\(paramName)_\(typeName)")
                    }
                } else {
                    parts.append("\(label)_\(typeName)")
                }
            }

            let returnTypeString = declaration.signature.returnClause?.type.description.trimmingCharacters(in: .whitespaces) ?? "Void"

            if isAsync {
                parts.append("async")
            } else {
                if returnTypeString == "Void" {
                    parts.append("sync")
                }
            }

            if declaration.signature.effectSpecifiers?.throwsSpecifier != nil {
                parts.append("throws")
            }

            parts.append("ret_\(returnTypeString)")

            if let whereClause = declaration.genericWhereClause {
                parts.append("where")
                for requirement in whereClause.requirements {
                    switch requirement.requirement {
                    case let .conformanceRequirement(conformance):
                        let left = conformance.leftType.description.trimmingCharacters(in: .whitespaces)
                        let right = conformance.rightType.description.trimmingCharacters(in: .whitespaces)
                        parts.append("\(left)_con_\(right)")
                    case let .sameTypeRequirement(sameType):
                        let left = sameType.leftType.description.trimmingCharacters(in: .whitespaces)
                        let right = sameType.rightType.description.trimmingCharacters(in: .whitespaces)
                        parts.append("\(left)_eq_\(right)")
                    case let .layoutRequirement(layout):
                        let left = layout.type.description.trimmingCharacters(in: .whitespaces)
                        let right = layout.layoutSpecifier.description.trimmingCharacters(in: .whitespaces)
                        parts.append("\(left)_con_\(right)")
                    }
                }
            }

            return parts.joined(separator: "_")
        }

        var callDescription: String {
            var description = declaration.name.text

            if let genericParameterClause = declaration.genericParameterClause {
                description += genericParameterClause.description.trimmingCharacters(in: .whitespaces)
            }

            let parameters = declaration.signature.parameterClause.parameters
            description += "("
            for (index, param) in parameters.enumerated() {
                if index > 0 {
                    description += ", "
                }

                let label = param.firstName.text
                if label != "_" {
                    description += "\(label): "
                }

                description += "\\($0[\(index)] ?? \"nil\")"
            }
            description += ")"

            return description
        }

        var implementation: FunctionDeclSyntax {
            let parameters = Array(declaration.signature.parameterClause.parameters)
            let methodReference = MemberAccessExprSyntax(
                base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
                period: .periodToken(),
                name: .identifier(stubIdentifier)
            )

            var performArguments: [LabeledExprSyntax] = [
                LabeledExprSyntax(
                    expression: ExprSyntax(methodReference),
                    trailingComma: parameters.isEmpty ? nil : .commaToken(trailingTrivia: .newline + .spaces(12))
                )
            ]

            if !parameters.isEmpty {
                performArguments.append(
                    LabeledExprSyntax(
                        expression: ExprSyntax(parameterArrayExpression(for: parameters))
                    )
                )
            }

            let performCall = FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_perform")),
                leftParen: .leftParenToken(trailingTrivia: .newline + .spaces(12)),
                arguments: LabeledExprListSyntax(performArguments),
                rightParen: .rightParenToken(leadingTrivia: .newline + .spaces(8))
            )

            let typeEffectSpecifiers = closureEffectSpecifiers()
            let closureType = TypeSyntax(FunctionTypeSyntax(
                parameters: closureParameterElements(for: parameters),
                effectSpecifiers: typeEffectSpecifiers,
                returnClause: ReturnClauseSyntax(
                    leadingTrivia: typeEffectSpecifiers == nil ? .space : [],
                    arrow: .arrowToken(trailingTrivia: .space),
                    type: closureReturnType
                )
            ))

            let castExpression = ExprSyntax(SequenceExprSyntax(
                elements: ExprListSyntax([
                    ExprSyntax(performCall),
                    ExprSyntax(BinaryOperatorExprSyntax(
                        leadingTrivia: [],
                        operator: .binaryOperator("as!", leadingTrivia: .space, trailingTrivia: .space),
                        trailingTrivia: []
                    )),
                    ExprSyntax(TypeExprSyntax(type: closureType))
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
                parameters.enumerated().map { index, parameter in
                    LabeledExprSyntax(
                        expression: parameter.invocationExpression,
                        trailingComma: index < parameters.count - 1 ? .commaToken(trailingTrivia: .space) : nil
                    )
                }
            )

            let performInvocation = FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("perform")),
                leftParen: .leftParenToken(),
                arguments: invocationArguments,
                rightParen: .rightParenToken()
            )

            var returnExpression = ExprSyntax(performInvocation)

            if declaration.signature.effectSpecifiers?.asyncSpecifier != nil {
                returnExpression = ExprSyntax(AwaitExprSyntax(
                    awaitKeyword: .keyword(.await, trailingTrivia: .space),
                    expression: returnExpression
                ))
            }

            if declaration.signature.effectSpecifiers?.throwsSpecifier != nil {
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

            return declaration.with(
                \.body,
                CodeBlockSyntax(
                    leftBrace: .leftBraceToken(leadingTrivia: .space, trailingTrivia: .newline),
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(
                            leadingTrivia: .spaces(4),
                            item: .decl(DeclSyntax(letPerform)),
                            trailingTrivia: .newline
                        ),
                        CodeBlockItemSyntax(
                            leadingTrivia: .spaces(4),
                            item: .stmt(StmtSyntax(returnStatement)),
                            trailingTrivia: []
                        )
                    ]),
                    rightBrace: .rightBraceToken(leadingTrivia: .newline)
                )
            )
        }

        var expectationMethodDeclaration: FunctionDeclSyntax {
            let parameters = declaration.signature.parameterClause.parameters
            let methodName = declaration.name.text

            // Build function parameters with Parameter<T> type
            let functionParameters = FunctionParameterListSyntax(
                parameters.enumerated().map { index, param -> FunctionParameterSyntax in
                    let label = param.firstName.text
                    let paramName = label == "_" ? (param.secondName?.text ?? "") : label

                    let parameterType = IdentifierTypeSyntax(
                        name: .identifier("Parameter"),
                        genericArgumentClause: GenericArgumentClauseSyntax(
                            leftAngle: .leftAngleToken(),
                            arguments: GenericArgumentListSyntax([
                                GenericArgumentSyntax(argument: param.type)
                            ]),
                            rightAngle: .rightAngleToken()
                        )
                    )

                    return FunctionParameterSyntax(
                        firstName: .identifier(paramName),
                        colon: .colonToken(trailingTrivia: .space),
                        type: parameterType,
                        trailingComma: index < parameters.count - 1 ? .commaToken(trailingTrivia: .space) : nil
                    )
                }
            )

            // Build tuple elements for where clause signature
            let whereSignatureElements = TupleTypeElementListSyntax(
                parameters.enumerated().map { index, param -> TupleTypeElementSyntax in
                    let label = param.firstName.text
                    let paramName = label == "_" ? (param.secondName?.text ?? "") : label

                    return TupleTypeElementSyntax(
                        firstName: .identifier("_"),
                        secondName: .identifier(paramName, leadingTrivia: .space),
                        colon: .colonToken(trailingTrivia: .space),
                        type: param.type,
                        trailingComma: index < parameters.count - 1 ? .commaToken(trailingTrivia: .space) : nil
                    )
                }
            )

            let fullSignature = FunctionTypeSyntax(
                parameters: whereSignatureElements,
                returnClause: ReturnClauseSyntax(
                    leadingTrivia: .space,
                    arrow: .arrowToken(trailingTrivia: .space),
                    type: IdentifierTypeSyntax(name: .identifier("Void"))
                )
            )

            // Build argument list for .init call
            let argumentList = LabeledExprListSyntax(
                [
                    LabeledExprSyntax(
                        leadingTrivia: .newline + .spaces(12),
                        label: .identifier("method"),
                        colon: .colonToken(trailingTrivia: .space),
                        expression: MemberAccessExprSyntax(
                            base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
                            period: .periodToken(),
                            name: .identifier(stubIdentifier)
                        ),
                        trailingComma: .commaToken()
                    ),
                    LabeledExprSyntax(
                        leadingTrivia: .newline + .spaces(12),
                        label: .identifier("parameters"),
                        colon: .colonToken(trailingTrivia: .space),
                        expression: ArrayExprSyntax(
                            leftSquare: .leftSquareToken(),
                            elements: ArrayElementListSyntax(
                                parameters.enumerated().map { index, param -> ArrayElementSyntax in
                                    let label = param.firstName.text
                                    let paramName = label == "_" ? (param.secondName?.text ?? "") : label

                                    return ArrayElementSyntax(
                                        expression: MemberAccessExprSyntax(
                                            base: DeclReferenceExprSyntax(baseName: .identifier(paramName)),
                                            period: .periodToken(),
                                            name: .identifier("anyParameter")
                                        ),
                                        trailingComma: index < parameters.count - 1 ? .commaToken(trailingTrivia: .space) : nil
                                    )
                                }
                            ),
                            rightSquare: .rightSquareToken()
                        )
                    )
                ]
            )

            return FunctionDeclSyntax(
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                ]),
                funcKeyword: .keyword(.func, trailingTrivia: .space),
                name: .identifier(methodName),
                genericParameterClause: declaration.genericParameterClause,
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax(
                        leftParen: .leftParenToken(),
                        parameters: functionParameters,
                        rightParen: .rightParenToken()
                    ),
                    returnClause: ReturnClauseSyntax(
                        leadingTrivia: .space,
                        arrow: .arrowToken(trailingTrivia: .space),
                        type: IdentifierTypeSyntax(name: .keyword(.Self))
                    )
                ),
                genericWhereClause: GenericWhereClauseSyntax(
                    leadingTrivia: .newline + .spaces(4),
                    whereKeyword: .keyword(.where, trailingTrivia: .space),
                    requirements: GenericRequirementListSyntax([
                        GenericRequirementSyntax(
                            requirement: .sameTypeRequirement(SameTypeRequirementSyntax(
                                leftType: IdentifierTypeSyntax(name: .identifier("Signature")),
                                equal: .binaryOperator("==", leadingTrivia: .space, trailingTrivia: .space),
                                rightType: fullSignature
                            ))
                        )
                    ])
                ),
                body: CodeBlockSyntax(
                    leadingTrivia: .space,
                    leftBrace: .leftBraceToken(),
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(
                            leadingTrivia: .newline + .spaces(8),
                            item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                calledExpression: MemberAccessExprSyntax(
                                    period: .periodToken(),
                                    name: .identifier("init")
                                ),
                                leftParen: .leftParenToken(),
                                arguments: argumentList,
                                rightParen: .rightParenToken(leadingTrivia: .newline + .spaces(8))
                            ))),
                            trailingTrivia: .newline + .spaces(4)
                        )
                    ]),
                    rightBrace: .rightBraceToken()
                )
            )
        }

        var variableDeclaration: VariableDeclSyntax {
            let identifier = stubIdentifier
            let callDescription = callDescription

            let sourceFile = Parser.parse(source: "\"\(callDescription)\"")
            guard let item = sourceFile.statements.first?.item,
                  case let .expr(expr) = item else {
                fatalError("Failed to parse string literal")
            }

            return VariableDeclSyntax(
                leadingTrivia: .newline + .spaces(4),
                modifiers: DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                ]),
                bindingSpecifier: .keyword(.var, trailingTrivia: .space),
                bindings: PatternBindingListSyntax([
                    PatternBindingSyntax(
                        pattern: IdentifierPatternSyntax(identifier: .identifier(identifier)),
                        typeAnnotation: TypeAnnotationSyntax(
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("MockMethod"))
                        ),
                        accessorBlock: AccessorBlockSyntax(
                            leftBrace: .leftBraceToken(leadingTrivia: .space),
                            accessors: .getter(CodeBlockItemListSyntax([
                                CodeBlockItemSyntax(
                                    item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                        leadingTrivia: .newline + .spaces(8),
                                        calledExpression: MemberAccessExprSyntax(
                                            period: .periodToken(),
                                            name: .identifier("init")
                                        ),
                                        arguments: [],
                                        trailingClosure: ClosureExprSyntax(
                                            leftBrace: .leftBraceToken(leadingTrivia: .space),
                                            statements: CodeBlockItemListSyntax([
                                                CodeBlockItemSyntax(
                                                    leadingTrivia: .newline + .spaces(12),
                                                    item: .expr(expr)
                                                )
                                            ]),
                                            rightBrace: .rightBraceToken(leadingTrivia: .newline + .spaces(8))
                                        )
                                    )))
                                )
                            ])),
                            rightBrace: .rightBraceToken(leadingTrivia: .newline + .spaces(4))
                        )
                    )
                ])
            )
        }
    }
}

private extension MockType.Method {
    func closureParameterElements(for parameters: [FunctionParameterSyntax]) -> TupleTypeElementListSyntax {
        TupleTypeElementListSyntax(
            parameters.enumerated().map { index, parameter in
                TupleTypeElementSyntax(
                    firstName: .identifier("_"),
                    secondName: parameter.parameterIdentifier.with(\.leadingTrivia, .space),
                    colon: .colonToken(trailingTrivia: .space),
                    type: parameter.type,
                    trailingComma: index < parameters.count - 1 ? .commaToken(trailingTrivia: .space) : nil
                )
            }
        )
    }

    func parameterArrayExpression(for parameters: [FunctionParameterSyntax]) -> ArrayExprSyntax {
        ArrayExprSyntax(
            leftSquare: .leftSquareToken(),
            elements: ArrayElementListSyntax(
                parameters.enumerated().map { index, parameter in
                    ArrayElementSyntax(
                        expression: ExprSyntax(parameter.reference),
                        trailingComma: index < parameters.count - 1 ? .commaToken(trailingTrivia: .space) : nil
                    )
                }
            ),
            rightSquare: .rightSquareToken()
        )
    }

    var closureReturnType: TypeSyntax {
        if let type = declaration.signature.returnClause?.type {
            return type.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
        }
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
    }

    func closureEffectSpecifiers() -> TypeEffectSpecifiersSyntax? {
        guard let specifiers = declaration.signature.effectSpecifiers else {
            return nil
        }

        let asyncToken = specifiers.asyncSpecifier?
            .with(\.leadingTrivia, .space)
            .with(\.trailingTrivia, .space)

        let throwsLeading: Trivia = specifiers.asyncSpecifier == nil ? .space : []
        let throwsToken = specifiers.throwsSpecifier?
            .with(\.leadingTrivia, throwsLeading)
            .with(\.trailingTrivia, .space)

        return TypeEffectSpecifiersSyntax(
            asyncSpecifier: asyncToken,
            throwsSpecifier: throwsToken
        )
    }
}
