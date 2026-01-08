import SwiftParser
import SwiftSyntax

extension MockType {
    final class Property: SyntaxBuilder {
        let declaration: VariableDeclSyntax
        let mockName: String

        init(declaration: VariableDeclSyntax, mockName: String) {
            self.declaration = declaration
            self.mockName = mockName
        }

        static func collectProperties(from protocols: [ProtocolDeclSyntax], mockName: String) -> [MockType.Property] {
            protocols.flatMap { protocolDecl in
                protocolDecl.memberBlock.members.compactMap { member in
                    member.decl.as(VariableDeclSyntax.self)
                }
            }
            .map {
                MockType.Property(declaration: $0, mockName: mockName)
            }
        }

        lazy var getterFunctionType = declaration.getterFunctionType
        lazy var setterFunctionType = declaration.setterFunctionType

        var stubIdentifier: String {
            guard let binding = declaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let type = binding.typeAnnotation?.type else {
                return ""
            }

            var parts: [String] = []
            let propertyName = pattern.identifier.text
            parts.append(propertyName)

            if let effectSpecifiers = declaration.getterEffectSpecifiers {
                parts.append(contentsOf: [
                    effectSpecifiers.asyncSpecifier,
                    effectSpecifiers.throwsSpecifier
                ]
                    .compactMap(\.?.text)
                )
            }

            parts.append(type.stubIdentifierSlug)

            return parts.joined(separator: "_")
        }

        func implementation(isPublic: Bool = false) -> VariableDeclSyntax {
            guard let binding = declaration.bindings.first,
                  let type = binding.typeAnnotation?.type,
                  let accessorBlock = binding.accessorBlock else {
                return declaration
            }

            var newAccessors: [AccessorDeclSyntax] = []

            switch accessorBlock.accessors {
            case let .accessors(accessorList):
                for accessor in accessorList {
                    let accessorKind = accessor.accessorSpecifier.tokenKind

                    if accessorKind == .keyword(.get) {
                        newAccessors.append(buildGetAccessor(
                            type: type,
                            effectSpecifiers: accessor.effectSpecifiers
                        ))
                    } else if accessorKind == .keyword(.set) {
                        newAccessors.append(buildSetAccessor(
                            type: type
                        ))
                    }
                }
            case .getter:
                newAccessors.append(buildGetAccessor(
                    type: type,
                    effectSpecifiers: nil
                ))
            }

            let newAccessorBlock = AccessorBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                accessors: .accessors(AccessorDeclListSyntax(newAccessors)),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )

            let newBinding = binding
                .with(\.accessorBlock, newAccessorBlock)
                .with(\.typeAnnotation, binding.typeAnnotation?.with(\.type, binding.typeAnnotation!.type.with(\.trailingTrivia, [])))

            let modifiers: DeclModifierListSyntax = isPublic ? DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))
            ]) : DeclModifierListSyntax([])

            return declaration
                .with(\.modifiers, modifiers)
                .with(\.bindingSpecifier, declaration.bindingSpecifier.with(\.leadingTrivia, []))
                .with(\.bindings, PatternBindingListSyntax([newBinding]))
        }

        var variableDeclaration: VariableDeclSyntax {
            guard let binding = declaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
            else {
                fatalError("Property must have accessor block")
            }

            let propertyName = pattern.identifier.text

            // All getters use closure signature { _ in }
            let callDescription = propertyName
            let closureSignature = ClosureSignatureSyntax(
                parameterClause: .simpleInput(
                    ClosureShorthandParameterListSyntax([
                        ClosureShorthandParameterSyntax(name: .wildcardToken(leadingTrivia: .space, trailingTrivia: .space))
                    ])
                ),
                inKeyword: .keyword(.in)
            )

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
                        pattern: IdentifierPatternSyntax(identifier: .identifier("get_\(stubIdentifier)")),
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
            guard let binding = declaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let accessorBlock = binding.accessorBlock else {
                return nil
            }

            // Check if this is a read-write property
            let hasSet: Bool = switch accessorBlock.accessors {
            case let .accessors(accessorList):
                accessorList.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
            case .getter:
                false
            }

            guard hasSet else {
                return nil
            }

            let propertyName = pattern.identifier.text
            let setterCallDescription = "\(propertyName) = \\($0 [0] ?? \"nil\")"

            let setterSourceFile = Parser.parse(source: "\"\(setterCallDescription)\"")
            guard let setterItem = setterSourceFile.statements.first?.item,
                  case let .expr(setterExpr) = setterItem else {
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
                        pattern: IdentifierPatternSyntax(identifier: .identifier("set_\(stubIdentifier)")),
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
                                                    item: .expr(setterExpr)
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

        var getterExpect: FunctionDeclSyntax {
            guard let binding = declaration.bindings.first,
                  let accessorBlock = binding.accessorBlock else {
                fatalError("Property must have accessor block")
            }

            var effectSpecifiers: AccessorEffectSpecifiersSyntax?
            switch accessorBlock.accessors {
            case let .accessors(accessorList):
                for accessor in accessorList {
                    if accessor.accessorSpecifier.tokenKind == .keyword(.get) {
                        effectSpecifiers = accessor.effectSpecifiers
                        break
                    }
                }
            case .getter:
                effectSpecifiers = nil
            }

            let signatureType = getterFunctionType
                .with(\.effectSpecifiers, effectSpecifiers?.asTypeEffectSpecifiersSyntax)

            return buildExpectFunction(
                expectationType: "PropertyExpectation",
                signatureType: signatureType,
                expectationPropertyName: "getterExpectation",
                isPublic: true
            )
        }

        var setterExpect: FunctionDeclSyntax {
            guard let binding = declaration.bindings.first,
                  let type = binding.typeAnnotation?.type else {
                fatalError("Property must have accessor block")
            }

            return buildSetterExpectFunction(
                expectationType: "PropertyExpectation",
                signatureType: setterFunctionType,
                valueType: type.replacingImplicitlyUnwrappedOptionals(),
                isPublic: true
            )
        }

        func getterExpectationExtension(isPublic: Bool) -> ExtensionDeclSyntax {
            guard let binding = declaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let accessorBlock = binding.accessorBlock else {
                fatalError("Property must have accessor block")
            }

            let propertyName = pattern.identifier.text

            var effectSpecifiers: AccessorEffectSpecifiersSyntax?
            switch accessorBlock.accessors {
            case let .accessors(accessorList):
                for accessor in accessorList {
                    if accessor.accessorSpecifier.tokenKind == .keyword(.get) {
                        effectSpecifiers = accessor.effectSpecifiers
                        break
                    }
                }
            case .getter:
                effectSpecifiers = nil
            }

            let signatureType = getterFunctionType
                .with(\.effectSpecifiers, effectSpecifiers?.asTypeEffectSpecifiersSyntax)

            let modifiers: DeclModifierListSyntax = isPublic ? DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))
            ]) : DeclModifierListSyntax([])

            return ExtensionDeclSyntax(
                modifiers: modifiers,
                extensionKeyword: .keyword(.extension, trailingTrivia: .space),
                extendedType: MemberTypeSyntax(
                    baseType: IdentifierTypeSyntax(name: .identifier(mockName)),
                    period: .periodToken(),
                    name: .identifier("PropertyExpectation")
                ),
                genericWhereClause: GenericWhereClauseSyntax(
                    whereKeyword: .keyword(.where, trailingTrivia: .space),
                    requirements: GenericRequirementListSyntax([
                        GenericRequirementSyntax(
                            requirement: .sameTypeRequirement(SameTypeRequirementSyntax(
                                leftType: IdentifierTypeSyntax(name: .identifier("Signature")),
                                equal: .binaryOperator("==", leadingTrivia: .space, trailingTrivia: .space),
                                rightType: TypeSyntax(signatureType)
                            ))
                        )
                    ])
                ),
                memberBlock: MemberBlockSyntax(
                    leftBrace: .leftBraceToken(leadingTrivia: .space),
                    members: MemberBlockItemListSyntax([
                        MemberBlockItemSyntax(
                            leadingTrivia: .newline,
                            decl: VariableDeclSyntax(
                                modifiers: DeclModifierListSyntax([
                                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                                ]),
                                bindingSpecifier: .keyword(.var, trailingTrivia: .space),
                                bindings: PatternBindingListSyntax([
                                    PatternBindingSyntax(
                                        pattern: IdentifierPatternSyntax(identifier: .identifier(propertyName)),
                                        typeAnnotation: TypeAnnotationSyntax(
                                            colon: .colonToken(trailingTrivia: .space),
                                            type: IdentifierTypeSyntax(name: .identifier("Self"))
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
                                                            LabeledExprSyntax(
                                                                label: .identifier("method"),
                                                                colon: .colonToken(trailingTrivia: .space),
                                                                expression: memberAccess(
                                                                    base: memberAccess(
                                                                        base: DeclReferenceExprSyntax(baseName: .identifier(mockName)),
                                                                        name: "Methods"
                                                                    ),
                                                                    name: "get_\(stubIdentifier)"
                                                                )
                                                            )
                                                        ]),
                                                        rightParen: .rightParenToken()
                                                    )))
                                                )
                                            ])),
                                            rightBrace: .rightBraceToken(leadingTrivia: .newline)
                                        )
                                    )
                                ])
                            )
                        )
                    ]),
                    rightBrace: .rightBraceToken(leadingTrivia: .newline)
                )
            )
        }

        func setterExpectationExtension(isPublic: Bool = false) -> ExtensionDeclSyntax? {
            guard let binding = declaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let accessors = declaration.accessors,
                  accessors.contains(where: { $0.accessorSpecifier.tokenKind == .keyword(.set) }) else {
                return nil
            }

            let propertyName = pattern.identifier.text

            let signatureType = setterFunctionType

            let modifiers: DeclModifierListSyntax = isPublic ? DeclModifierListSyntax([
                DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))
            ]) : DeclModifierListSyntax([])

            return ExtensionDeclSyntax(
                modifiers: modifiers,
                extensionKeyword: .keyword(.extension, trailingTrivia: .space),
                extendedType: MemberTypeSyntax(
                    baseType: IdentifierTypeSyntax(name: .identifier(mockName)),
                    period: .periodToken(),
                    name: .identifier("PropertyExpectation")
                ),
                genericWhereClause: GenericWhereClauseSyntax(
                    whereKeyword: .keyword(.where, trailingTrivia: .space),
                    requirements: GenericRequirementListSyntax([
                        GenericRequirementSyntax(
                            requirement: .sameTypeRequirement(SameTypeRequirementSyntax(
                                leftType: IdentifierTypeSyntax(name: .identifier("Signature")),
                                equal: .binaryOperator("==", leadingTrivia: .space, trailingTrivia: .space),
                                rightType: TypeSyntax(signatureType)
                            ))
                        )
                    ])
                ),
                memberBlock: MemberBlockSyntax(
                    leftBrace: .leftBraceToken(leadingTrivia: .space),
                    members: MemberBlockItemListSyntax([
                        MemberBlockItemSyntax(
                            leadingTrivia: .newline,
                            decl: VariableDeclSyntax(
                                modifiers: DeclModifierListSyntax([
                                    DeclModifierSyntax(name: .keyword(.static, trailingTrivia: .space))
                                ]),
                                bindingSpecifier: .keyword(.var, trailingTrivia: .space),
                                bindings: PatternBindingListSyntax([
                                    PatternBindingSyntax(
                                        pattern: IdentifierPatternSyntax(identifier: .identifier(propertyName)),
                                        typeAnnotation: TypeAnnotationSyntax(
                                            colon: .colonToken(trailingTrivia: .space),
                                            type: IdentifierTypeSyntax(name: .identifier("Self"))
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
                                                            LabeledExprSyntax(
                                                                label: .identifier("method"),
                                                                colon: .colonToken(trailingTrivia: .space),
                                                                expression: memberAccess(
                                                                    base: memberAccess(
                                                                        base: DeclReferenceExprSyntax(baseName: .identifier(mockName)),
                                                                        name: "Methods"
                                                                    ),
                                                                    name: "set_\(stubIdentifier)"
                                                                )
                                                            )
                                                        ]),
                                                        rightParen: .rightParenToken()
                                                    )))
                                                )
                                            ])),
                                            rightBrace: .rightBraceToken(leadingTrivia: .newline)
                                        )
                                    )
                                ])
                            )
                        )
                    ]),
                    rightBrace: .rightBraceToken(leadingTrivia: .newline)
                )
            )
        }
    }
}

private extension MockType.Property {
    func buildGetAccessor(
        type: TypeSyntax,
        effectSpecifiers: AccessorEffectSpecifiersSyntax?
    ) -> AccessorDeclSyntax {
        let methodReference = memberAccess(
            base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
            name: "get_\(stubIdentifier)"
        )

        let performCall = functionCall(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_perform")),
            arguments: [labeledExpr(expression: methodReference)].commaSeparated(leadingTrivia: .newline),
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

        let performInvocation = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("perform")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax([]),
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

    func buildSetAccessor(type: TypeSyntax) -> AccessorDeclSyntax {
        let methodReference = memberAccess(
            base: DeclReferenceExprSyntax(baseName: .identifier("Methods")),
            name: "set_\(stubIdentifier)"
        )

        let performCall = functionCall(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("_perform")),
            arguments: [
                labeledExpr(expression: methodReference),
                labeledExpr(expression: arrayExpression(elements: [
                    DeclReferenceExprSyntax(baseName: .identifier("newValue"))
                ]))
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

        let performInvocation = FunctionCallExprSyntax(
            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("perform")),
            leftParen: .leftParenToken(),
            arguments: LabeledExprListSyntax([
                LabeledExprSyntax(
                    expression: DeclReferenceExprSyntax(baseName: .identifier("newValue"))
                )
            ]),
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
