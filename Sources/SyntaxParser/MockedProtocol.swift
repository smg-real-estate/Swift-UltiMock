import SwiftSyntax

struct MockedProtocol: MockedType, Equatable {
    let declaration: ProtocolDeclSyntax
    let inherited: [ProtocolDeclSyntax]

    var mock: ClassDeclSyntax {
        let builder = ProtocolMockBuilder(self)

        return builder.mockClass
    }

    var allProtocols: [ProtocolDeclSyntax] {
        inherited + [declaration]
    }
}

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
