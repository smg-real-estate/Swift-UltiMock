import SwiftParser
import SwiftSyntax

extension MockType {
    final class Method: SyntaxBuilder {
        let declaration: FunctionDeclSyntax
        let mockName: String

        init(declaration: FunctionDeclSyntax, mockName: String) {
            self.declaration = declaration
            self.mockName = mockName
        }

        static func collectMethods(from protocols: [ProtocolDeclSyntax], mockName: String) -> [MockType.Method] {
            protocols.flatMap { protocolDecl in
                protocolDecl.memberBlock.members.compactMap { member in
                    member.decl.as(FunctionDeclSyntax.self)
                }
            }
            .map {
                MockType.Method(declaration: $0, mockName: mockName)
            }
        }

        lazy var functionType = declaration.asType(mockName: mockName)
            .replacingSomeWithAny()

        lazy var stubIdentifier = {
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
        }()

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

                let typeDescription = param.type.description.trimmingCharacters(in: .whitespaces)
                let isStringType = typeDescription == "String"

                if isStringType {
                    description += "\\\"\\($0[\(index)] ?? \"nil\")\\\""
                } else {
                    description += "\\($0[\(index)] ?? \"nil\")"
                }
            }
            description += ")"

            return description
        }

        func implementation(isPublic: Bool = false) -> FunctionDeclSyntax {
            var implementationDeclaration = declaration

            let rewrittenParameters = declaration.signature.parameterClause.parameters.map { param -> FunctionParameterSyntax in
                var updatedParam = param

                if param.type.as(IdentifierTypeSyntax.self)?.name.text == "Self" {
                    updatedParam = updatedParam.with(\.type, TypeSyntax(IdentifierTypeSyntax(name: .identifier(mockName))))
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

            let castExpression = ExprSyntax(SequenceExprSyntax(
                elements: ExprListSyntax([
                    ExprSyntax(performCall),
                    ExprSyntax(BinaryOperatorExprSyntax(
                        leadingTrivia: [],
                        operator: .binaryOperator("as!", leadingTrivia: .space, trailingTrivia: .space),
                        trailingTrivia: []
                    )),
                    ExprSyntax(TypeExprSyntax(type: functionType.replacingSomeWithAny()))
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

            if isPublic {
                implementationDeclaration.modifiers = [
                    DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))
                ] + declaration.modifiers.trimmed(matching: \.isNewline)

                implementationDeclaration.funcKeyword.leadingTrivia = []
            }

            return implementationDeclaration
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

        func expectationMethodDeclaration(isPublic: Bool = false) -> FunctionDeclSyntax {
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

            let modifiers: [DeclModifierSyntax] = if isPublic {
                [
                    DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space)),
                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                ]
            } else {
                [
                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                ]
            }

            let originalGenericRequirements = declaration.genericWhereClause?.requirements ?? []
            let genericRequirements = [
                GenericRequirementSyntax(
                    requirement: .sameTypeRequirement(SameTypeRequirementSyntax(
                        leftType: IdentifierTypeSyntax(name: .identifier("Signature"), trailingTrivia: .space),
                        equal: .binaryOperator("==", trailingTrivia: .space),
                        rightType: functionType.replacingSelfWithTypeName(mockName)
                    ))
                )
            ] + originalGenericRequirements

            let attributes = declaration.attributes.filter {
                $0.attributeNameKind != .identifier("objc")
            }

            return declaration.with(\.leadingTrivia, [])
                .with(\.attributes, attributes)
                .withExpectationParameters(mockName: mockName)
                .with(\.modifiers, DeclModifierListSyntax(modifiers))
                .with(\.signature.effectSpecifiers, nil)
                .with(\.signature.returnClause, ReturnClauseSyntax(
                    arrow: .arrowToken(trailingTrivia: .space),
                    type: IdentifierTypeSyntax(name: .keyword(.Self)),
                ))
                .with(\.genericWhereClause, GenericWhereClauseSyntax(
                    leadingTrivia: .space,
                    whereKeyword: .keyword(.where, trailingTrivia: .space),
                    requirements: genericRequirements.commaSeparated()
                ))
                .with(
                    \.body,
                    CodeBlockSyntax(
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
            buildExpectFunction(
                expectationType: "MethodExpectation",
                signatureType: functionType.replacingSelfWithTypeName(mockName),
                genericParameterClause: declaration.genericParameterClause,
                isPublic: true
            )
        }
    }
}

private extension MockType.Method {
    func parameterArrayExpression(for parameters: [FunctionParameterSyntax]) -> ArrayExprSyntax {
        arrayExpression(elements: parameters.map(\.reference))
    }
}
