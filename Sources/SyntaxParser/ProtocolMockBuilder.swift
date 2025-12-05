import SwiftSyntax

final class ProtocolMockBuilder {
    let mockedProtocol: MockedProtocol
    let allMethods: [MockType.Method]

    lazy var allAssociatedTypes = mockedProtocol.allProtocols
        .flatMap { protocolDecl in
            protocolDecl.memberBlock.members.compactMap { member in
                member.decl.as(AssociatedTypeDeclSyntax.self)
            }
        }
        .unique(by: \.name.text)

    init(_ mockedProtocol: MockedProtocol) {
        self.mockedProtocol = mockedProtocol
        self.allMethods = MockType.Method.collectMethods(from: mockedProtocol.allProtocols)
    }

    var mockClassName: String {
        mockedProtocol.declaration.name.text + "Mock"
    }

    var methodsEnum: EnumDeclSyntax {
        EnumDeclSyntax(
            leadingTrivia: .newline,
            enumKeyword: .keyword(.enum, trailingTrivia: .space),
            name: .identifier("Methods"),
            memberBlock: MemberBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space),
                members: MemberBlockItemListSyntax(
                    allMethods.map(\.variableDeclaration).map { MemberBlockItemSyntax(decl: $0) }
                ),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    var genericParameterClause: GenericParameterClauseSyntax? {
        guard !allAssociatedTypes.isEmpty else {
            return nil
        }
        let parameters = allAssociatedTypes.enumerated().map { index, associatedType -> GenericParameterSyntax in
            let inheritedTypes = associatedType.inheritanceClause?.inheritedTypes.map(\.type) ?? []

            let inheritedType: TypeSyntax?
            if inheritedTypes.isEmpty {
                inheritedType = nil
            } else if inheritedTypes.count == 1 {
                inheritedType = inheritedTypes.first
            } else {
                let elements = inheritedTypes.enumerated().map { i, type -> CompositionTypeElementSyntax in
                    CompositionTypeElementSyntax(
                        type: type,
                        ampersand: i < inheritedTypes.count - 1 ? TokenSyntax.binaryOperator("&", leadingTrivia: .space, trailingTrivia: .space) : nil
                    )
                }
                inheritedType = TypeSyntax(CompositionTypeSyntax(elements: CompositionTypeElementListSyntax(elements)))
            }

            return GenericParameterSyntax(
                name: associatedType.name,
                colon: inheritedType != nil ? .colonToken(trailingTrivia: .space) : nil,
                inheritedType: inheritedType,
                trailingComma: index < allAssociatedTypes.count - 1 ? .commaToken(trailingTrivia: .space) : nil
            )
        }

        return GenericParameterClauseSyntax(
            parameters: GenericParameterListSyntax(parameters)
        )
    }

    var methodExpectations: StructDeclSyntax {
        var members: [MemberBlockItemSyntax] = []

        // expectation property
        members.append(MemberBlockItemSyntax(
            leadingTrivia: .newline + .spaces(4),
            decl: VariableDeclSyntax(
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
            ),
            trailingTrivia: .newline
        ))

        // init
        members.append(MemberBlockItemSyntax(
            leadingTrivia: .newline + .spaces(4),
            decl: InitializerDeclSyntax(
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
            ),
            trailingTrivia: .newline
        ))

        // Static methods for each protocol method
        for method in allMethods {
            members.append(MemberBlockItemSyntax(
                leadingTrivia: .newline + .spaces(4),
                decl: method.expectationMethodDeclaration,
                trailingTrivia: .newline
            ))
        }

        return StructDeclSyntax(
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
        MemberBlockItemSyntax(decl: methodsEnum)
    }

    var mockClass: ClassDeclSyntax {
        let mockType = IdentifierTypeSyntax(name: .identifier("Mock"))

        let sendableType = IdentifierTypeSyntax(name: .identifier("Sendable"))
        let uncheckedAttribute = AttributeSyntax(
            attributeName: IdentifierTypeSyntax(name: .identifier("unchecked")),
            trailingTrivia: .space
        )
        let uncheckedSendableType = AttributedTypeSyntax(
            attributes: AttributeListSyntax([.attribute(uncheckedAttribute)]),
            baseType: sendableType
        )

        return ClassDeclSyntax(
            classKeyword: .keyword(.class, trailingTrivia: .space),
            name: .identifier(mockClassName),
            genericParameterClause: genericParameterClause,
            inheritanceClause: InheritanceClauseSyntax(
                colon: .colonToken(trailingTrivia: .space),
                inheritedTypes: InheritedTypeListSyntax([
                    InheritedTypeSyntax(
                        type: mockType,
                        trailingComma: .commaToken(trailingTrivia: .space)
                    ),
                    InheritedTypeSyntax(type: uncheckedSendableType)
                ])
            ),
            memberBlock: MemberBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space, trailingTrivia: .newline),
                members: MemberBlockItemListSyntax(members),
                rightBrace: .rightBraceToken()
            )
        )
    }
}
