import SwiftSyntax
import SwiftParser

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

        let allProtocols = inherited + [declaration]
        let allAssociatedTypes = allProtocols.flatMap { protocolDecl in
            protocolDecl.memberBlock.members.compactMap { member in
                member.decl.as(AssociatedTypeDeclSyntax.self)
            }
        }

        let allMethods = allProtocols.flatMap { protocolDecl in
            protocolDecl.memberBlock.members.compactMap { member in
                member.decl.as(FunctionDeclSyntax.self)
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
                    trailingComma: index < associatedTypes.count - 1 ? .commaToken(trailingTrivia: .space) : nil
                )
            }

            genericParameterClause = GenericParameterClauseSyntax(
                parameters: GenericParameterListSyntax(parameters)
            )
        } else {
            genericParameterClause = nil
        }

        let methodVars = allMethods.map { method -> VariableDeclSyntax in
            let mockMethod = MockType.Method(declaration: method)
            let identifier = mockMethod.stubIdentifier
            let callDescription = mockMethod.callDescription

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

        let members: [MemberBlockItemSyntax]
        if !methodVars.isEmpty {
            let methodsEnum = EnumDeclSyntax(
                leadingTrivia: .newline,
                enumKeyword: .keyword(.enum, trailingTrivia: .space),
                name: .identifier("Methods"),
                memberBlock: MemberBlockSyntax(
                    leftBrace: .leftBraceToken(leadingTrivia: .space),
                    members: MemberBlockItemListSyntax(
                        methodVars.map { MemberBlockItemSyntax(decl: $0) }
                    ),
                    rightBrace: .rightBraceToken(leadingTrivia: .newline)
                )
            )
            members = [MemberBlockItemSyntax(decl: methodsEnum)]
        } else {
            members = []
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
                members: MemberBlockItemListSyntax(members),
                rightBrace: .rightBraceToken()
            )
        )
    }
}
