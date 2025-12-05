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
        MethodExpectationBuilder(allMethods: allMethods).declaration
    }

    @ArrayBuilder<MemberBlockItemSyntax>
    var properties: [MemberBlockItemSyntax] {
        property(.public, name: "recorder", initializer: InitializerClauseSyntax(
            equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
            value: FunctionCallExprSyntax(
                calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Recorder")),
                leftParen: .leftParenToken(),
                arguments: LabeledExprListSyntax([]),
                rightParen: .rightParenToken()
            )
        ))
        .with(\.leadingTrivia, .newline)

        property(name: "fileID", type: "String").with(\.leadingTrivia, .newlines(2))
        property(name: "filePath", type: "StaticString")
        property(name: "line", type: "UInt")
        property(name: "column", type: "Int")
    }

    var initializer: InitializerDeclSyntax {
        InitializerDeclSyntax(
            leadingTrivia: .newline,
            modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.public, trailingTrivia: .space))]),
            initKeyword: .keyword(.`init`),
            signature: FunctionSignatureSyntax(
                parameterClause: FunctionParameterClauseSyntax(
                    leftParen: .leftParenToken(trailingTrivia: .newline + .spaces(4)),
                    parameters: FunctionParameterListSyntax([
                        FunctionParameterSyntax(
                            firstName: .identifier("fileID"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("String")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("#fileID")))
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline + .spaces(4))
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("filePath"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("StaticString")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("#filePath")))
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline + .spaces(4))
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("line"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("UInt")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("#line")))
                            ),
                            trailingComma: .commaToken(trailingTrivia: .newline + .spaces(4))
                        ),
                        FunctionParameterSyntax(
                            firstName: .identifier("column"),
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier("Int")),
                            defaultValue: InitializerClauseSyntax(
                                equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space),
                                value: ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier("#column")))
                            )
                        )
                    ]),
                    rightParen: .rightParenToken(leadingTrivia: .newline)
                )
            ),
            body: CodeBlockSyntax(
                leadingTrivia: .space,
                leftBrace: .leftBraceToken(),
                statements: CodeBlockItemListSyntax([
                    assignmentCodeBlockItem(target: "self.fileID", value: "fileID"),
                    assignmentCodeBlockItem(target: "self.filePath", value: "filePath"),
                    assignmentCodeBlockItem(target: "self.line", value: "line"),
                    assignmentCodeBlockItem(target: "self.column", value: "column")
                ]),
                rightBrace: .rightBraceToken(leadingTrivia: .newline)
            )
        )
    }

    @ArrayBuilder<MemberBlockItemSyntax>
    var members: [MemberBlockItemSyntax] {
        properties
        MemberBlockItemSyntax(decl: methodsEnum)
        MemberBlockItemSyntax(decl: methodExpectations)
    }

    var inheritanceClause: InheritanceClauseSyntax {
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

        return InheritanceClauseSyntax(
            colon: .colonToken(trailingTrivia: .space),
            inheritedTypes: InheritedTypeListSyntax([
                InheritedTypeSyntax(
                    type: mockType,
                    trailingComma: .commaToken(trailingTrivia: .space)
                ),
                InheritedTypeSyntax(type: uncheckedSendableType)
            ])
        )
    }

    var mockClass: ClassDeclSyntax {
        ClassDeclSyntax(
            classKeyword: .keyword(.class, trailingTrivia: .space),
            name: .identifier(mockClassName),
            genericParameterClause: genericParameterClause,
            inheritanceClause: inheritanceClause,
            memberBlock: MemberBlockSyntax(
                leftBrace: .leftBraceToken(leadingTrivia: .space, trailingTrivia: .newline),
                members: MemberBlockItemListSyntax(members),
                rightBrace: .rightBraceToken()
            )
        )
    }
}

func property(
    _ accessLevel: Keyword = .private,
    name: String,
    type: String? = nil,
    initializer: InitializerClauseSyntax? = nil
) -> MemberBlockItemSyntax {
    MemberBlockItemSyntax(
        leadingTrivia: .newline,
        decl: VariableDeclSyntax(
            modifiers: DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(accessLevel, trailingTrivia: .space))]),
            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
            bindings: PatternBindingListSyntax([
                PatternBindingSyntax(
                    pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
                    typeAnnotation: type.map {
                        TypeAnnotationSyntax(
                            colon: .colonToken(trailingTrivia: .space),
                            type: IdentifierTypeSyntax(name: .identifier($0))
                        )
                    },
                    initializer: initializer
                )
            ])
        )
    )
}

func assignmentCodeBlockItem(
    target: String,
    value: String,
    isLast: Bool = false
) -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
        leadingTrivia: .newline + .spaces(4),
        item: .expr(ExprSyntax(SequenceExprSyntax(
            elements: ExprListSyntax([
                ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(target))),
                ExprSyntax(AssignmentExprSyntax(equal: .equalToken(leadingTrivia: .space, trailingTrivia: .space))),
                ExprSyntax(DeclReferenceExprSyntax(baseName: .identifier(value)))
            ])
        ))),
        trailingTrivia: isLast ? .newline : []
    )
}
