import SwiftSyntax

struct MockedProtocol: MockedType, Equatable {
    let declaration: ProtocolDeclSyntax
    let inherited: [ProtocolDeclSyntax]

    var mock: ClassDeclSyntax {
        let name = declaration.name.text + "Mock"
        
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
        
        let allProtocols = [declaration] + inherited
        let allAssociatedTypes = allProtocols.flatMap { protocolDecl in
            protocolDecl.memberBlock.members.compactMap { member in
                member.decl.as(AssociatedTypeDeclSyntax.self)
            }
        }

        var seen = Set<String>()
        var associatedTypes: [AssociatedTypeDeclSyntax] = []
        for assocType in allAssociatedTypes {
            let name = assocType.name.text
            if !seen.contains(name) {
                seen.insert(name)
                associatedTypes.append(assocType)
            }
        }
        
        let genericParameterClause: GenericParameterClauseSyntax?
        if !associatedTypes.isEmpty {
            let parameters = associatedTypes.enumerated().map { index, associatedType -> GenericParameterSyntax in
                let inheritedTypes = associatedType.inheritanceClause?.inheritedTypes.map { $0.type } ?? []
                
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
                    trailingComma: index < associatedTypes.count - 1 ? .commaToken(trailingTrivia: .space) : nil
                )
            }
            
            genericParameterClause = GenericParameterClauseSyntax(
                parameters: GenericParameterListSyntax(parameters)
            )
        } else {
            genericParameterClause = nil
        }
        
        return ClassDeclSyntax(
            classKeyword: .keyword(.class, trailingTrivia: .space),
            name: .identifier(name),
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
                members: MemberBlockItemListSyntax([]),
                rightBrace: .rightBraceToken()
            )
        )
    }
}
