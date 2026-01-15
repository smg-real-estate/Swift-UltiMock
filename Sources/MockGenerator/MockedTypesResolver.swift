import SwiftParser
import SwiftSyntax

public protocol MockedType {
    var mockSyntax: CodeBlockItemListSyntax { get }
}

public struct MockedTypesResolver {
    let typeAliases: [String: [String: TypeAliasDeclSyntax]]
    var annotationKeys: [String]

    public init(
        typeAliases: [String: [String: TypeAliasDeclSyntax]],
        annotationKeys: [String]
    ) {
        self.typeAliases = typeAliases
        self.annotationKeys = annotationKeys
    }

    public static func resolve(
        from contentSequence: some Sequence<() throws -> String>,
        annotationKeys: [String]
    ) throws -> [MockedType] {
        let typesCollector = TypesVisitor()
        let aliasCollector = AliasTableBuilder()

        for content in contentSequence {
            do {
                let source = try Parser.parse(source: content())
                typesCollector.walk(source)
                aliasCollector.walk(source)
            }
        }

        let resolver = MockedTypesResolver(typeAliases: aliasCollector.aliasesByScope, annotationKeys: annotationKeys)
        return resolver.resolve(typesCollector.types)
    }

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

    func resolveTypeAlias(_ original: some TypeSyntaxProtocol, in scope: String) -> TypeSyntaxProtocol? {
        guard let type = original.as(IdentifierTypeSyntax.self) else {
            return nil
        }
        let typeName = type.name.text
        let scopes = generateScopeChain(scope)
        for scopeKey in scopes {
            if let alias = typeAliases[scopeKey]?[typeName] {
                var resolvedType = alias.initializer.value

                if let genericParams = alias.genericParameterClause?.parameters,
                   let genericArgs = type.genericArgumentClause?.arguments {
                    var substitutions: [String: TypeSyntax] = [:]
                    for (param, arg) in zip(genericParams, genericArgs) {
                        substitutions[param.name.text] = arg.argument.as(TypeSyntax.self)!
                    }

                    let rewriter = GenericArgumentRewriter(substitutions: substitutions)
                    return rewriter.rewrite(alias.initializer.value).as(TypeSyntax.self)
                } else if let genericArgs = type.genericArgumentClause,
                          let identifierType = resolvedType.as(IdentifierTypeSyntax.self) {
                    resolvedType = TypeSyntax(identifierType.with(\.genericArgumentClause, genericArgs))
                }

                return resolvedType
            }
        }
        return nil
    }

    private func generateScopeChain(_ scope: String) -> [String] {
        var result: [String] = [scope]
        var components = scope.split(separator: ".").map(String.init)

        while !components.isEmpty {
            components.removeLast()
            result.append(components.joined(separator: "."))
        }

        result.append("")
        return result
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
            let scopeKey = protocolDecl.name.text
            let rewrittenDecl: ProtocolDeclSyntax

            if hasTypeAliases(in: scopeKey) {
                let rewriter = TypeAliasRewriter(resolver: self, scope: scopeKey)
                rewrittenDecl = rewriter.rewrite(protocolDecl).as(ProtocolDeclSyntax.self)!
            } else {
                rewrittenDecl = protocolDecl
            }

            return MockedProtocol(
                declaration: rewrittenDecl,
                inherited: inherited
            )
        }
        return nil
    }

    func hasTypeAliases(in scope: String) -> Bool {
        let scopes = generateScopeChain(scope)
        for scopeKey in scopes {
            if let aliases = typeAliases[scopeKey], !aliases.isEmpty {
                return true
            }
        }
        return false
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
            var typeName = inheritedType.type.trimmedDescription

            if typeMap[typeName] == nil, let aliasedType = resolveTypeAlias(inheritedType.type, in: "") {
                typeName = aliasedType.trimmedDescription
            }

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
