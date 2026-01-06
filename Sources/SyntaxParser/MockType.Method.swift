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
                let typeName = param.type.stubIdentifierSlug

                parts.append("\(label)_\(typeName)")
            }

            let returnTypeString = declaration.signature.returnClause?.type.stubIdentifierSlug ?? "Void"

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
                        let left = conformance.leftType.stubIdentifierSlug
                        let right = conformance.rightType.stubIdentifierSlug
                        parts.append("\(left)_con_\(right)")
                    case let .sameTypeRequirement(sameType):
                        let left = sameType.leftType.stubIdentifierSlug
                        let right = sameType.rightType.stubIdentifierSlug
                        parts.append("\(left)_eq_\(right)")
                    case let .layoutRequirement(layout):
                        let left = layout.type.stubIdentifierSlug
                        let right = layout.layoutSpecifier.description.trimmingCharacters(in: .whitespaces)
                        parts.append("\(left)_con_\(right)")
                    }
                }
            }

            return parts.joined(separator: "_")
        }

        // TODO: Rewrite with SwiftSyntax
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

        func implementation(in mockType: String? = nil, isPublic: Bool = false) -> FunctionDeclSyntax {
            var implementationDeclaration = declaration

            let rewrittenParameters = declaration.signature.parameterClause.parameters.map { param -> FunctionParameterSyntax in
                var updatedParam = param

                if let mockType, param.type.as(IdentifierTypeSyntax.self)?.name.text == "Self" {
                    updatedParam = updatedParam.with(\.type, TypeSyntax(IdentifierTypeSyntax(name: .identifier(mockType))))
                }

                let secondNameText = updatedParam.secondName?.text
                if let secondNameText, keywordsToEscape.contains(secondNameText), !secondNameText.hasPrefix("`") {
                    updatedParam = updatedParam.with(\.secondName, .identifier("`\(secondNameText)`"))
                }

                return updatedParam
            }
            implementationDeclaration = implementationDeclaration.with(\.signature.parameterClause.parameters, FunctionParameterListSyntax(rewrittenParameters))

            let parameters = Array(implementationDeclaration.signature.parameterClause.parameters)
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
                arguments: performArguments.commaSeparated(leadingTrivia: .newline),
                rightParenTrivia: .newline
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

            let modifiers: DeclModifierListSyntax = isPublic ? DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))
            ]) : DeclModifierListSyntax([])

            // Adjust funcKeyword leading trivia based on whether we have modifiers or attributes
            let funcKeywordLeadingTrivia: Trivia
            if !modifiers.isEmpty {
                // If we have modifiers, no leading trivia on func
                funcKeywordLeadingTrivia = []
            } else if !implementationDeclaration.attributes.isEmpty {
                // If we have attributes but no modifiers, preserve newline
                funcKeywordLeadingTrivia = .newline
            } else {
                // Otherwise, clear leading trivia
                funcKeywordLeadingTrivia = []
            }

            return implementationDeclaration
                .with(\.modifiers, modifiers)
                .with(\.funcKeyword, implementationDeclaration.funcKeyword.with(\.leadingTrivia, funcKeywordLeadingTrivia))
                .with(\.signature, implementationDeclaration.signature.with(\.trailingTrivia, .space))
                .with(\.genericWhereClause, implementationDeclaration.genericWhereClause?.with(\.trailingTrivia, .space))
                .with(\.body, CodeBlockSyntax(
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(
                            leadingTrivia: .newline,
                            item: .decl(DeclSyntax(letPerform))
                        ),
                        CodeBlockItemSyntax(
                            item: .stmt(StmtSyntax(returnStatement)),
                            trailingTrivia: []
                        )
                    ]),
                    rightBrace: .rightBraceToken(leadingTrivia: .newline)
                ))
        }

        func expectationMethodDeclaration(mockName: String) -> FunctionDeclSyntax {
            let parameters = declaration.signature.parameterClause.parameters
            let argumentList = LabeledExprListSyntax(
                [
                    labeledExpr(
                        label: "method",
                        expression: memberAccess(
                            base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
                            name: stubIdentifier
                        )
                    ),
                    labeledExpr(
                        label: "parameters",
                        expression: arrayExpression(
                            elements: parameters.compactMap { param -> MemberAccessExprSyntax? in
                                let firstName = param.firstName.text
                                let secondName = param.secondName?.text
                                let paramName = secondName ?? firstName

                                // Skip parameters named "self" in the parameters array
                                if paramName == "self" || paramName == "`self`" {
                                    return nil
                                }

                                let paramIdentifier: String = if paramName == "internal" {
                                    "`internal`"
                                } else {
                                    paramName.hasPrefix("`")
                                        ? paramName
                                        : paramName.replacingOccurrences(of: "`", with: "")
                                }

                                return memberAccess(
                                    base: DeclReferenceExprSyntax(baseName: .identifier(paramIdentifier)),
                                    name: "anyParameter"
                                )
                            },
                            wrapped: true
                        )
                    )
                ]
                    .commaSeparated(trailingTrivia: .newline)
            )
                .with(\.leadingTrivia, .newline)

            // Build tuple elements for where clause signature
            let whereSignatureSyntaxElements: [TupleTypeElementSyntax] = parameters.compactMap { param in
                let firstName = param.firstName.text
                let secondName = param.secondName?.text
                let paramName = secondName ?? firstName

                // Skip parameters named "self" in the where clause
                if paramName == "self" || paramName == "`self`" {
                    return nil
                }

                let signatureParamName = (paramName == "internal") ? "`internal`" : paramName

                // For where clause, we preserve inout but still normalize Self and implicit optionals
                let normalizedType = normalizeTypeForSignature(param.type, replaceSelfWith: mockName)
                let existentialNormalizedType = ExistentialAnyRewriter().rewrite(normalizedType).cast(TypeSyntax.self)

                return tupleTypeElement(
                    secondName: signatureParamName,
                    type: existentialNormalizedType
                )
                .with(\.leadingTrivia, .newline)
            }

            let whereSignatureElements = TupleTypeElementListSyntax(
                whereSignatureSyntaxElements.commaSeparated(leadingTrivia: .newline)
            )
                .with(\.leadingTrivia, .newline)

            let returnType: TypeSyntax = if let returnClause = declaration.signature.returnClause {
                ExistentialAnyRewriter()
                    .rewrite(normalizeTypeForSignature(returnClause.type, replaceSelfWith: mockName))
                    .cast(TypeSyntax.self)
            } else {
                TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
            }

            let fullSignature = FunctionTypeSyntax(
                parameters: whereSignatureElements,
                rightParen: .rightParenToken(leadingTrivia: whereSignatureElements.isEmpty ? [] : .newline),
                returnClause: ReturnClauseSyntax(
                    leadingTrivia: .space,
                    arrow: .arrowToken(trailingTrivia: .space),
                    type: returnType
                )
            )

            return declaration.with(\.leadingTrivia, [])
                .withExpectationParameters(mockName: mockName)
                .with(\.modifiers, DeclModifierListSyntax([
                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                ]))
                .with(\.signature.returnClause, ReturnClauseSyntax(
                    arrow: .arrowToken(trailingTrivia: .space),
                    type: IdentifierTypeSyntax(name: .keyword(.Self)),
                ))
                .with(\.genericWhereClause, GenericWhereClauseSyntax(
                    leadingTrivia: .space,
                    whereKeyword: .keyword(.where, trailingTrivia: .space),
                    requirements: GenericRequirementListSyntax([
                        GenericRequirementSyntax(
                            requirement: .sameTypeRequirement(SameTypeRequirementSyntax(
                                leftType: IdentifierTypeSyntax(name: .identifier("Signature"), trailingTrivia: .space),
                                equal: .binaryOperator("==", trailingTrivia: .space),
                                rightType: fullSignature
                            ))
                        )
                    ])
                ))
                .with(\.body, CodeBlockSyntax(
                    leftBrace: .leftBraceToken(),
                    statements: CodeBlockItemListSyntax([
                        CodeBlockItemSyntax(
                            item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                leadingTrivia: .newline,
                                calledExpression: MemberAccessExprSyntax(
                                    period: .periodToken(),
                                    name: .identifier("init")
                                ),
                                leftParen: .leftParenToken(),
                                arguments: argumentList,
                                rightParen: .rightParenToken(leadingTrivia: .newline)
                            )))
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

            let hasParameters = !declaration.signature.parameterClause.parameters.isEmpty
            let closureSignature: ClosureSignatureSyntax? = hasParameters ? nil : ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax([
                        ClosureShorthandParameterSyntax(name: .wildcardToken(leadingTrivia: .space, trailingTrivia: .space))
                    ])
                ),
                inKeyword: .keyword(.in)
            )

            return VariableDeclSyntax(
                leadingTrivia: .newline,
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
                                        leadingTrivia: .newline,
                                        calledExpression: MemberAccessExprSyntax(
                                            period: .periodToken(),
                                            name: .identifier("init")
                                        ),
                                        arguments: [],
                                        trailingClosure: ClosureExprSyntax(
                                            leftBrace: .leftBraceToken(leadingTrivia: .space),
                                            signature: closureSignature,
                                            statements: CodeBlockItemListSyntax([
                                                CodeBlockItemSyntax(
                                                    leadingTrivia: hasParameters ? .newline : [],
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
                                leadingTrivia: .newline,
                                firstName: .wildcardToken(),
                                secondName: .identifier("expectation", leadingTrivia: .space),
                                colon: .colonToken(trailingTrivia: .space),
                                type: IdentifierTypeSyntax(
                                    name: .identifier("MethodExpectation"),
                                    genericArgumentClause: genericArgumentClause(arguments: [signatureType])
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
                            leadingTrivia: .newline,
                            item: .expr(ExprSyntax(FunctionCallExprSyntax(
                                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_record")),
                                leftParen: .leftParenToken(),
                                arguments: LabeledExprListSyntax([
                                    labeledExpr(
                                        leadingTrivia: .newline,
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
}

private final class ExistentialAnyRewriter: SyntaxRewriter {
    override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
        SomeOrAnyTypeSyntax(
            someOrAnySpecifier: .keyword(.any, trailingTrivia: .space),
            constraint: node.constraint
        ).cast(TypeSyntax.self)
    }
}

private extension MockType.Method {
    func closureParameterElements(for parameters: [FunctionParameterSyntax]) -> TupleTypeElementListSyntax {
        TupleTypeElementListSyntax(
            parameters.map { parameter in
                let type: TypeSyntax
                if let implicitOptional = parameter.type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                    type = TypeSyntax(OptionalTypeSyntax(
                        wrappedType: implicitOptional.wrappedType.trimmed,
                        questionMark: .postfixQuestionMarkToken()
                    ))
                } else {
                    type = parameter.type.trimmed
                }

                return tupleTypeElement(
                    secondName: parameter.parameterIdentifier.text,
                    type: replaceSomeWithAny(in: type)
                )
            }
            .commaSeparated()
        )
    }

    func replaceSomeWithAny(in type: TypeSyntax) -> TypeSyntax {
        if let someType = type.as(SomeOrAnyTypeSyntax.self), someType.someOrAnySpecifier.tokenKind == .keyword(.some) {
            return TypeSyntax(someType.with(\.someOrAnySpecifier, .keyword(.any, trailingTrivia: .space)))
        }

        if let optionalType = type.as(OptionalTypeSyntax.self) {
            return TypeSyntax(optionalType.with(\.wrappedType, replaceSomeWithAny(in: optionalType.wrappedType)))
        }

        if let attributedType = type.as(AttributedTypeSyntax.self) {
            return TypeSyntax(attributedType.with(\.baseType, replaceSomeWithAny(in: attributedType.baseType)))
        }

        return type
    }

    func parameterArrayExpression(for parameters: [FunctionParameterSyntax]) -> ArrayExprSyntax {
        arrayExpression(elements: parameters.map(\.reference))
    }

    var closureReturnType: TypeSyntax {
        if let type = declaration.signature.returnClause?.type {
            if let implicitOptional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
                return TypeSyntax(OptionalTypeSyntax(
                    wrappedType: implicitOptional.wrappedType.trimmed,
                    questionMark: .postfixQuestionMarkToken()
                ))
            }
            return type.trimmed
        }
        return TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void")))
    }
    
    // Normalize type for Parameter<T> - removes inout, attributes, converts implicit optional
    func normalizeTypeForParameter(_ type: TypeSyntax, replaceSelfWith mockName: String) -> TypeSyntax {
        normalizeTypeInternal(type, replaceSelfWith: mockName, preserveInout: false)
    }
    
    // Normalize type for where clause signature - keeps inout, but removes attributes and converts implicit optional
    func normalizeTypeForSignature(_ type: TypeSyntax, replaceSelfWith mockName: String) -> TypeSyntax {
        normalizeTypeInternal(type, replaceSelfWith: mockName, preserveInout: true)
            .withoutTrivia(\.isComment)
    }
    
    func normalizeTypeInternal(_ type: TypeSyntax, replaceSelfWith mockName: String, preserveInout: Bool) -> TypeSyntax {
        // Handle inout specifier
        if let attributedType = type.as(AttributedTypeSyntax.self),
           attributedType.specifier?.tokenKind == .keyword(.inout) {
            if preserveInout {
                // Keep inout but normalize the base type
                let normalizedBase = normalizeTypeInternal(attributedType.baseType, replaceSelfWith: mockName, preserveInout: preserveInout)
                return TypeSyntax(AttributedTypeSyntax(
                    specifier: attributedType.specifier,
                    baseType: normalizedBase
                ))
            } else {
                // Remove inout and normalize the base type
                return normalizeTypeInternal(attributedType.baseType, replaceSelfWith: mockName, preserveInout: preserveInout)
            }
        }
        
        // Remove attributes like @escaping, @Sendable, @MainActor etc.
        if let attributedType = type.as(AttributedTypeSyntax.self),
           !attributedType.attributes.isEmpty {
            return normalizeTypeInternal(attributedType.baseType, replaceSelfWith: mockName, preserveInout: preserveInout)
        }
        
        // Convert implicit optional (!) to optional (?)
        if let implicitOptional = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            let wrappedType = normalizeTypeInternal(implicitOptional.wrappedType, replaceSelfWith: mockName, preserveInout: preserveInout)
            return TypeSyntax(OptionalTypeSyntax(
                wrappedType: wrappedType,
                questionMark: .postfixQuestionMarkToken()
            ))
        }
        
        // Replace Self with mock name
        if let identifierType = type.as(IdentifierTypeSyntax.self),
           identifierType.name.text == "Self" {
            return TypeSyntax(IdentifierTypeSyntax(
                name: .identifier(mockName),
                genericArgumentClause: identifierType.genericArgumentClause
            ))
        }
        
        // Recursively normalize optional types
        if let optionalType = type.as(OptionalTypeSyntax.self) {
            let wrappedType = normalizeTypeInternal(optionalType.wrappedType, replaceSelfWith: mockName, preserveInout: preserveInout)
            return TypeSyntax(OptionalTypeSyntax(
                wrappedType: wrappedType,
                questionMark: optionalType.questionMark
            ))
        }
        
        // Recursively normalize array types
        if let arrayType = type.as(ArrayTypeSyntax.self) {
            let elementType = normalizeTypeInternal(arrayType.element, replaceSelfWith: mockName, preserveInout: preserveInout)
            return TypeSyntax(ArrayTypeSyntax(
                leftSquare: arrayType.leftSquare,
                element: elementType,
                rightSquare: arrayType.rightSquare
            ))
        }
        
        // Recursively normalize dictionary types
        if let dictType = type.as(DictionaryTypeSyntax.self) {
            let keyType = normalizeTypeInternal(dictType.key, replaceSelfWith: mockName, preserveInout: preserveInout)
            let valueType = normalizeTypeInternal(dictType.value, replaceSelfWith: mockName, preserveInout: preserveInout)
            return TypeSyntax(DictionaryTypeSyntax(
                leftSquare: dictType.leftSquare,
                key: keyType,
                colon: dictType.colon,
                value: valueType,
                rightSquare: dictType.rightSquare
            ))
        }
        
        // Recursively normalize tuple types
        if let tupleType = type.as(TupleTypeSyntax.self) {
            let normalizedElements = tupleType.elements.map { element in
                TupleTypeElementSyntax(
                    firstName: element.firstName,
                    secondName: element.secondName,
                    colon: element.colon,
                    type: normalizeTypeInternal(element.type, replaceSelfWith: mockName, preserveInout: preserveInout),
                    ellipsis: element.ellipsis,
                    trailingComma: element.trailingComma
                )
            }
            return TypeSyntax(TupleTypeSyntax(
                leftParen: tupleType.leftParen,
                elements: TupleTypeElementListSyntax(normalizedElements),
                rightParen: tupleType.rightParen
            ))
        }
        
        // Recursively normalize function types (closures)
        if let functionType = type.as(FunctionTypeSyntax.self) {
            let normalizedParameters = functionType.parameters.map { param in
                TupleTypeElementSyntax(
                    firstName: param.firstName,
                    secondName: param.secondName,
                    colon: param.colon,
                    type: normalizeTypeInternal(param.type, replaceSelfWith: mockName, preserveInout: preserveInout),
                    ellipsis: param.ellipsis,
                    trailingComma: param.trailingComma
                )
            }
            let normalizedReturnType = normalizeTypeInternal(functionType.returnClause.type, replaceSelfWith: mockName, preserveInout: preserveInout)
            return TypeSyntax(FunctionTypeSyntax(
                leftParen: functionType.leftParen,
                parameters: TupleTypeElementListSyntax(normalizedParameters),
                rightParen: functionType.rightParen,
                effectSpecifiers: functionType.effectSpecifiers,
                returnClause: ReturnClauseSyntax(
                    leadingTrivia: functionType.returnClause.leadingTrivia,
                    arrow: functionType.returnClause.arrow,
                    type: normalizedReturnType,
                    trailingTrivia: functionType.returnClause.trailingTrivia
                )
            ))
        }
        
        // Recursively normalize generic types
        if let identifierType = type.as(IdentifierTypeSyntax.self),
           let genericArgs = identifierType.genericArgumentClause {
            let normalizedArgs = genericArgs.arguments.map { arg in
                GenericArgumentSyntax(
                    argument: normalizeTypeInternal(arg.argument, replaceSelfWith: mockName, preserveInout: preserveInout),
                    trailingComma: arg.trailingComma
                )
            }
            return TypeSyntax(IdentifierTypeSyntax(
                name: identifierType.name,
                genericArgumentClause: GenericArgumentClauseSyntax(
                    leftAngle: genericArgs.leftAngle,
                    arguments: GenericArgumentListSyntax(normalizedArgs),
                    rightAngle: genericArgs.rightAngle
                )
            ))
        }
        
        // Return the type as-is if no normalization is needed
        return type
    }
}
