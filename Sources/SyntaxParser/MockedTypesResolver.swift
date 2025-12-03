import SwiftSyntax

protocol MockedType {}

struct MockedTypesResolver {
    let typeAliases: [String: [String: TypeAliasDeclSyntax]]
    var annotationKeys: [String] = ["sourcery", "UltiMock"]

    func resolve(_ types: [Syntax.TypeInfo]) -> [MockedType] {
        let typeMap = buildTypeMap(from: types)
        var visitedIDs: Set<SyntaxIdentifier> = []

        return types.compactMap { type in
            guard hasAnnotation(type.declaration),
                  let decl = resolveDeclaration(for: type, using: typeMap),
                  !visitedIDs.contains(decl.id),
                  let mocked = createMockedType(from: decl, using: typeMap)
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

    func createMockedType(from decl: DeclSyntax, using typeMap: [String: DeclSyntax]) -> MockedType? {
        if let protocolDecl = decl.as(ProtocolDeclSyntax.self) {
            let inherited = resolveInheritedProtocols(from: protocolDecl.inheritanceClause, using: typeMap)
            return MockedProtocol(
                declaration: protocolDecl,
                inherited: inherited
            )
        }
        if let classDecl = decl.as(ClassDeclSyntax.self) {
            let superclasses = resolveInheritedClasses(from: classDecl.inheritanceClause, using: typeMap)
            let protocols = resolveAllProtocols(from: classDecl.inheritanceClause, superclasses: superclasses, using: typeMap)
            return MockedClass(
                declaration: classDecl,
                superclasses: superclasses,
                protocols: protocols
            )
        }
        return nil
    }

    func resolveInheritedProtocols(from clause: InheritanceClauseSyntax?, using typeMap: [String: DeclSyntax]) -> [ProtocolDeclSyntax] {
        guard let inherited = clause?.inheritedTypes else {
            return []
        }

        var result: [ProtocolDeclSyntax] = []
        var visited: Set<SyntaxIdentifier> = []

        for inheritedType in inherited {
            let typeName = inheritedType.type.trimmedDescription
            guard let decl = typeMap[typeName],
                  let protocolDecl = decl.as(ProtocolDeclSyntax.self)
            else {
                continue
            }
            collectInheritedProtocols(protocolDecl, into: &result, visited: &visited, using: typeMap)
        }

        return result
    }

    func collectInheritedProtocols(_ protocol: ProtocolDeclSyntax, into result: inout [ProtocolDeclSyntax], visited: inout Set<SyntaxIdentifier>, using typeMap: [String: DeclSyntax]) {
        guard !visited.contains(`protocol`.id) else {
            return
        }

        visited.insert(`protocol`.id)
        result.append(`protocol`)

        let nestedInherited = resolveDirectInheritedProtocols(from: `protocol`.inheritanceClause, using: typeMap)
        for inherited in nestedInherited {
            collectInheritedProtocols(inherited, into: &result, visited: &visited, using: typeMap)
        }
    }

    func resolveDirectInheritedProtocols(from clause: InheritanceClauseSyntax?, using typeMap: [String: DeclSyntax]) -> [ProtocolDeclSyntax] {
        guard let inherited = clause?.inheritedTypes else {
            return []
        }

        return inherited.compactMap { inheritedType in
            let typeName = inheritedType.type.trimmedDescription
            guard let decl = typeMap[typeName] else {
                return nil
            }
            return decl.as(ProtocolDeclSyntax.self)
        }
    }

    func resolveInheritedClasses(from clause: InheritanceClauseSyntax?, using typeMap: [String: DeclSyntax]) -> [ClassDeclSyntax] {
        guard let inherited = clause?.inheritedTypes else {
            return []
        }

        var result: [ClassDeclSyntax] = []
        var visited: Set<SyntaxIdentifier> = []

        for inheritedType in inherited {
            let typeName = inheritedType.type.trimmedDescription
            guard let decl = typeMap[typeName],
                  let classDecl = decl.as(ClassDeclSyntax.self)
            else {
                continue
            }
            collectInheritedClasses(classDecl, into: &result, visited: &visited, using: typeMap)
        }

        return result
    }

    func collectInheritedClasses(_ classDecl: ClassDeclSyntax, into result: inout [ClassDeclSyntax], visited: inout Set<SyntaxIdentifier>, using typeMap: [String: DeclSyntax]) {
        guard !visited.contains(classDecl.id) else {
            return
        }

        visited.insert(classDecl.id)
        result.append(classDecl)

        let nestedInherited = resolveDirectInheritedClasses(from: classDecl.inheritanceClause, using: typeMap)
        for inherited in nestedInherited {
            collectInheritedClasses(inherited, into: &result, visited: &visited, using: typeMap)
        }
    }

    func resolveDirectInheritedClasses(from clause: InheritanceClauseSyntax?, using typeMap: [String: DeclSyntax]) -> [ClassDeclSyntax] {
        guard let inherited = clause?.inheritedTypes else {
            return []
        }

        return inherited.compactMap { inheritedType in
            let typeName = inheritedType.type.trimmedDescription
            guard let decl = typeMap[typeName] else {
                return nil
            }
            return decl.as(ClassDeclSyntax.self)
        }
    }

    func resolveAllProtocols(from clause: InheritanceClauseSyntax?, superclasses: [ClassDeclSyntax], using typeMap: [String: DeclSyntax]) -> [ProtocolDeclSyntax] {
        var result: [ProtocolDeclSyntax] = []
        var visited: Set<SyntaxIdentifier> = []

        let directProtocols = resolveInheritedProtocols(from: clause, using: typeMap)
        for protocolDecl in directProtocols {
            if !visited.contains(protocolDecl.id) {
                visited.insert(protocolDecl.id)
                result.append(protocolDecl)
            }
        }

        for superclass in superclasses {
            let superclassProtocols = resolveInheritedProtocols(from: superclass.inheritanceClause, using: typeMap)
            for protocolDecl in superclassProtocols {
                if !visited.contains(protocolDecl.id) {
                    visited.insert(protocolDecl.id)
                    result.append(protocolDecl)
                }
            }
        }

        return result
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
