import SwiftSyntax

protocol MockedType {}

struct MockedTypesResolver {
    let typeAliases: [String: [String: AliasDefinition]]
    var annotationKeys: [String] = ["sourcery", "UltiMock"]

    func resolve(_ types: [Syntax.TypeInfo]) -> [MockedType] {
        let typeMap = buildTypeMap(from: types)
        var visitedIDs: Set<SyntaxIdentifier> = []

        return types.compactMap { type in
            guard hasAnnotation(type.declaration),
                  let decl = resolveDeclaration(for: type, using: typeMap),
                  !visitedIDs.contains(decl.id),
                  let mocked = createMockedType(from: decl)
            else {
                return nil
            }

            visitedIDs.insert(decl.id)
            return mocked
        }
    }
}

private extension MockedTypesResolver {
    func buildTypeMap(from types: [Syntax.TypeInfo]) -> [String: DeclSyntax] {
        var map: [String: DeclSyntax] = [:]
        for type in types {
            if let name = type.declarationName {
                if map[name] == nil {
                    map[name] = type.declaration
                }
            }
        }
        return map
    }

    func resolveDeclaration(for type: Syntax.TypeInfo, using map: [String: DeclSyntax]) -> DeclSyntax? {
        let decl = type.declaration
        if decl.is(ProtocolDeclSyntax.self) || decl.is(ClassDeclSyntax.self) {
            return decl
        }
        if let extensionDecl = decl.as(ExtensionDeclSyntax.self) {
            let typeName = extensionDecl.extendedType.trimmedDescription
            return map[typeName]
        }
        return nil
    }

    func createMockedType(from decl: DeclSyntax) -> MockedType? {
        if let protocolDecl = decl.as(ProtocolDeclSyntax.self) {
            return MockedProtocol(
                declaration: protocolDecl,
                inherited: []
            )
        }
        if let classDecl = decl.as(ClassDeclSyntax.self) {
            return MockedClass(
                declaration: classDecl,
                superclasses: [],
                protocols: []
            )
        }
        return nil
    }

    func hasAnnotation(_ decl: some SyntaxProtocol) -> Bool {
        decl.leadingTrivia.contains { piece in
            switch piece {
            case let .lineComment(text), let .blockComment(text):
                hasAnnotationKey(in: text)
            default:
                false
            }
        }
    }

    func hasAnnotationKey(in comment: String) -> Bool {
        annotationKeys.contains { key in
            comment.contains("\(key):AutoMockable")
        }
    }
}

private extension Syntax.TypeInfo {
    var declarationName: String? {
        if let p = declaration.as(ProtocolDeclSyntax.self) {
            return p.name.text
        } else if let c = declaration.as(ClassDeclSyntax.self) {
            return c.name.text
        }
        return nil
    }
}
