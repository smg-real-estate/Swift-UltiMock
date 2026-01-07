import SwiftParser
import SwiftSyntax

extension MockType {
    struct Property: SyntaxBuilder {
        let declaration: VariableDeclSyntax

        static func collectProperties(from protocols: [ProtocolDeclSyntax]) -> [MockType.Property] {
            protocols.flatMap { protocolDecl in
                protocolDecl.memberBlock.members.compactMap { member in
                    member.decl.as(VariableDeclSyntax.self)
                }
            }.map { MockType.Property(declaration: $0) }
        }

        var stubIdentifier: String {
            guard let binding = declaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let type = binding.typeAnnotation?.type,
                  let accessorBlock = binding.accessorBlock else {
                return ""
            }

            var parts: [String] = []
            let propertyName = pattern.identifier.text
            parts.append(propertyName)

            // Add accessor effect specifiers (async, throws)
            switch accessorBlock.accessors {
            case let .accessors(accessorList):
                for accessor in accessorList {
                    if accessor.accessorSpecifier.tokenKind == .keyword(.get) {
                        if let effectSpecifiers = accessor.effectSpecifiers {
                            if effectSpecifiers.asyncSpecifier != nil {
                                parts.append("async")
                            }
                            if effectSpecifiers.throwsSpecifier != nil {
                                parts.append("throws")
                            }
                        }
                    }
                }
            case .getter:
                break
            }

            parts.append(type.stubIdentifierSlug)

            return parts.joined(separator: "_")
        }

        var callDescription: String {
            ""
        }

        func implementation(in mockType: String? = nil, isPublic: Bool = false) -> VariableDeclSyntax {
            guard let binding = declaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
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

        func expectationMethodDeclaration(mockName: String) -> FunctionDeclSyntax {
            fatalError()
        }

        var variableDeclaration: VariableDeclSyntax {
            guard let binding = declaration.bindings.first,
                  let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  let accessorBlock = binding.accessorBlock else {
                fatalError("Property must have accessor block")
            }

            let propertyName = pattern.identifier.text

            // Check if this is a read-write property
            let hasSet: Bool
            switch accessorBlock.accessors {
            case let .accessors(accessorList):
                hasSet = accessorList.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
            case .getter:
                hasSet = false
            }

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
            let hasSet: Bool
            switch accessorBlock.accessors {
            case let .accessors(accessorList):
                hasSet = accessorList.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
            case .getter:
                hasSet = false
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

        var expect: FunctionDeclSyntax {
            fatalError()
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

        // Determine if this is a read-write property (has a setter)
        let isReadWrite: Bool
        if let binding = declaration.bindings.first,
           let accessorBlock = binding.accessorBlock {
            switch accessorBlock.accessors {
            case let .accessors(accessorList):
                isReadWrite = accessorList.contains { $0.accessorSpecifier.tokenKind == .keyword(.set) }
            case .getter:
                isReadWrite = false
            }
        } else {
            isReadWrite = false
        }

        // For async properties, closure signature always includes throws
        // For read-write properties, getter returns Void
        let closureEffectSpecifiers: TypeEffectSpecifiersSyntax?
        if effectSpecifiers?.asyncSpecifier != nil {
            // Async getters always have throws in their closure signature
            closureEffectSpecifiers = TypeEffectSpecifiersSyntax(
                throwsSpecifier: .keyword(.throws, leadingTrivia: .space, trailingTrivia: .space)
            )
        } else {
            closureEffectSpecifiers = typeEffectSpecifiers(
                asyncSpecifier: nil,
                throwsSpecifier: effectSpecifiers?.throwsSpecifier
            )
        }

        let returnType: TypeSyntax = isReadWrite ? TypeSyntax(IdentifierTypeSyntax(name: .identifier("Void"))) : type.trimmed

        let closureType = TypeSyntax(FunctionTypeSyntax(
            parameters: TupleTypeElementListSyntax([]),
            effectSpecifiers: closureEffectSpecifiers,
            returnClause: ReturnClauseSyntax(
                leadingTrivia: closureEffectSpecifiers == nil ? .space : [],
                arrow: .arrowToken(trailingTrivia: .space),
                type: returnType
            )
        ))

        let castExpression = ExprSyntax(SequenceExprSyntax(
            elements: ExprListSyntax([
                ExprSyntax(performCall),
                ExprSyntax(BinaryOperatorExprSyntax(
                    operator: .binaryOperator("as!", leadingTrivia: .space, trailingTrivia: .space)
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

    private func buildSetAccessor(type: TypeSyntax) -> AccessorDeclSyntax {
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

        let closureType = TypeSyntax(FunctionTypeSyntax(
            parameters: TupleTypeElementListSyntax([
                tupleTypeElement(secondName: "newValue", type: type.trimmed)
            ]),
            returnClause: ReturnClauseSyntax(
                leadingTrivia: .space,
                arrow: .arrowToken(trailingTrivia: .space),
                type: type.trimmed
            )
        ))

        let castExpression = ExprSyntax(SequenceExprSyntax(
            elements: ExprListSyntax([
                ExprSyntax(performCall),
                ExprSyntax(BinaryOperatorExprSyntax(
                    operator: .binaryOperator("as!", leadingTrivia: .space, trailingTrivia: .space)
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
