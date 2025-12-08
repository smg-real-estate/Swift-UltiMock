import SwiftParser
import SwiftSyntax

extension MockType {
    struct Method: SyntaxBuilder {
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

                parts.append("\(label)_\(typeName)")
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
            let methodReference = memberAccess(
                base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
                name: stubIdentifier
            )

            var performArguments = [
                labeledExpr(expression: methodReference)
            ]

            if !parameters.isEmpty {
                performArguments.append(
                    labeledExpr(expression: parameterArrayExpression(for: parameters))
                )
            }

            let performCall = functionCall(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_perform")),
                arguments: performArguments.commaSeparated(trailingTrivia: .newline + .spaces(12))
            )

            let effectSpecifiers = typeEffectSpecifiers(
                asyncSpecifier: declaration.signature.effectSpecifiers?.asyncSpecifier,
                throwsSpecifier: declaration.signature.effectSpecifiers?.throwsSpecifier
            )
            let closureType = TypeSyntax(FunctionTypeSyntax(
                parameters: closureParameterElements(for: parameters),
                effectSpecifiers: effectSpecifiers,
                returnClause: ReturnClauseSyntax(
                    leadingTrivia: effectSpecifiers == nil ? .space : [],
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
                parameters.map { parameter in
                    LabeledExprSyntax(
                        expression: parameter.invocationExpression
                    )
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
                parameters.map { param -> FunctionParameterSyntax in
                    let label = param.firstName.text
                    let paramName = label == "_" ? (param.secondName?.text ?? "") : label

                    let parameterType = IdentifierTypeSyntax(
                        name: .identifier("Parameter"),
                        genericArgumentClause: genericArgumentClause(arguments: [param.type])
                    )

                    return FunctionParameterSyntax(
                        firstName: .identifier(paramName),
                        colon: .colonToken(trailingTrivia: .space),
                        type: parameterType
                    )
                }
                .commaSeparated()
            )

            // Build tuple elements for where clause signature
            let whereSignatureElements = TupleTypeElementListSyntax(
                parameters.map { param in
                    let label = param.firstName.text
                    let paramName = label == "_" ? (param.secondName?.text ?? "") : label
                    return tupleTypeElement(
                        secondName: paramName,
                        type: param.type
                    )
                }
                .commaSeparated()
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
                    labeledExpr(
                        leadingTrivia: .newline + .spaces(12),
                        label: "method",
                        expression: memberAccess(
                            base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
                            name: stubIdentifier
                        )
                    ),
                    labeledExpr(
                        leadingTrivia: .newline + .spaces(12),
                        label: "parameters",
                        expression: arrayExpression(
                            elements: parameters.map { param in
                                let label = param.firstName.text
                                let paramName = label == "_" ? (param.secondName?.text ?? "") : label
                                return memberAccess(
                                    base: DeclReferenceExprSyntax(baseName: .identifier(paramName)),
                                    name: "anyParameter"
                                )
                            }
                        )
                    )
                ]
                    .commaSeparated(trailingTrivia: [])
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

        var expect: FunctionDeclSyntax {
            let parameters = declaration.signature.parameterClause.parameters.map(\.self)
            let effectSpecifiers = typeEffectSpecifiers(
                asyncSpecifier: declaration.signature.effectSpecifiers?.asyncSpecifier,
                throwsSpecifier: declaration.signature.effectSpecifiers?.throwsSpecifier
            )

            let signatureType = FunctionTypeSyntax(
                leftParen: .leftParenToken(),
                parameters: closureParameterElements(for: parameters),
                rightParen: .rightParenToken(),
                effectSpecifiers: effectSpecifiers,
                returnClause: ReturnClauseSyntax(
                    leadingTrivia: effectSpecifiers == nil ? .space : [],
                    arrow: .arrowToken(trailingTrivia: .space),
                    type: closureReturnType
                )
            )

            var performParametersElements: [TupleTypeElementSyntax] = []
            for param in closureParameterElements(for: parameters) {
                performParametersElements.append(param)
            }

            let performType = FunctionTypeSyntax(
                leftParen: .leftParenToken(),
                parameters: TupleTypeElementListSyntax(performParametersElements),
                rightParen: .rightParenToken(),
                effectSpecifiers: effectSpecifiers,
                returnClause: ReturnClauseSyntax(
                    leadingTrivia: effectSpecifiers == nil ? .space : [],
                    arrow: .arrowToken(trailingTrivia: .space),
                    type: closureReturnType
                )
            )

            return FunctionDeclSyntax(
                modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]),
                funcKeyword: .keyword(.func, trailingTrivia: .space),
                name: .identifier("expect"),
                signature: FunctionSignatureSyntax(
                    parameterClause: FunctionParameterClauseSyntax(
                        leftParen: .leftParenToken(),
                        parameters: FunctionParameterListSyntax([
                            FunctionParameterSyntax(
                                leadingTrivia: .newline + .spaces(4),
                                firstName: .identifier("_"),
                                secondName: .identifier("expectation", leadingTrivia: .space),
                                colon: .colonToken(trailingTrivia: .space),
                                type: IdentifierTypeSyntax(
                                    name: .identifier("MethodExpectation"),
                                    genericArgumentClause: genericArgumentClause(arguments: [signatureType])
                                ),
                                trailingComma: .commaToken(trailingTrivia: .newline + .spaces(4))
                            ),
                            FunctionParameterSyntax(
                                firstName: .identifier("fileID"),
                                colon: .colonToken(trailingTrivia: .space),
                                type: IdentifierTypeSyntax(name: .identifier("String")),
                                defaultValue: InitializerClauseSyntax(
                                    equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                    value: MacroExpansionExprSyntax(macroName: .identifier("fileID"), arguments: [])
                                ),
                                trailingComma: .commaToken(trailingTrivia: .newline + .spaces(4))
                            ),
                            FunctionParameterSyntax(
                                firstName: .identifier("filePath"),
                                colon: .colonToken(trailingTrivia: .space),
                                type: IdentifierTypeSyntax(name: .identifier("StaticString")),
                                defaultValue: InitializerClauseSyntax(
                                    equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                    value: MacroExpansionExprSyntax(macroName: .identifier("filePath"), arguments: [])
                                ),
                                trailingComma: .commaToken(trailingTrivia: .newline + .spaces(4))
                            ),
                            FunctionParameterSyntax(
                                firstName: .identifier("line"),
                                colon: .colonToken(trailingTrivia: .space),
                                type: IdentifierTypeSyntax(name: .identifier("UInt")),
                                defaultValue: InitializerClauseSyntax(
                                    equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                    value: MacroExpansionExprSyntax(macroName: .identifier("line"), arguments: [])
                                ),
                                trailingComma: .commaToken(trailingTrivia: .newline + .spaces(4))
                            ),
                            FunctionParameterSyntax(
                                firstName: .identifier("column"),
                                colon: .colonToken(trailingTrivia: .space),
                                type: IdentifierTypeSyntax(name: .identifier("Int")),
                                defaultValue: InitializerClauseSyntax(
                                    equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                    value: MacroExpansionExprSyntax(macroName: .identifier("column"), arguments: [])
                                ),
                                trailingComma: .commaToken(trailingTrivia: .newline + .spaces(4))
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
                                    baseType: TypeSyntax(performType)
                                )
                            )
                        ]),
                        rightParen: .rightParenToken(leadingTrivia: .newline)
                    )
                ),
                body: CodeBlockSyntax(
                    leftBrace: .leftBraceToken(leadingTrivia: .space),
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(
                            leadingTrivia: .newline + .spaces(4),
                            item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_record")),
                                leftParen: .leftParenToken(),
                                arguments: LabeledExprListSyntax([
                                    labeledExpr(
                                        leadingTrivia: .newline + .spaces(8),
                                        expression: memberAccess(
                                            base: DeclReferenceExprSyntax(baseName: .identifier("expectation")),
                                            name: "expectation"
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
                                    .commaSeparated(trailingTrivia: .newline + .spaces(8))),
                                rightParen: .rightParenToken(leadingTrivia: .newline + .spaces(4))
                            )))
                        )
                    ]),
                    rightBrace: .rightBraceToken(leadingTrivia: .newline)
                )
            )
        }
    }
}

private extension MockType.Method {
    func closureParameterElements(for parameters: [FunctionParameterSyntax]) -> TupleTypeElementListSyntax {
        TupleTypeElementListSyntax(
            parameters.map { parameter in
                tupleTypeElement(
                    secondName: parameter.parameterIdentifier.text,
                    type: parameter.type.trimmed
                )
            }
            .commaSeparated()
        )
    }

    func parameterArrayExpression(for parameters: [FunctionParameterSyntax]) -> ArrayExprSyntax {
        arrayExpression(elements: parameters.map(\.reference))
    }

    var closureReturnType: TypeSyntax {
        if let type = declaration.signature.returnClause?.type {
            return type.trimmed
        }
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
    }
}
