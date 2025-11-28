import SwiftSyntax
struct TypeAliasCollector {
    func collect(from source: SourceFileSyntax) -> [String: AliasDefinition] {
        let aliasBuilder = AliasTableBuilder(viewMode: .fixedUp)
        aliasBuilder.walk(source)

        let aliasTable = aliasBuilder.aliasesByScope
        var globalAliases: [String: AliasDefinition] = [:]
        for alias in aliasTable[AliasTableBuilder.globalScopeKey] ?? [] {
            globalAliases[alias.name] = alias
        }

        let globalAliasFallbacks = makeAliasFallbacks(from: aliasTable[AliasTableBuilder.globalScopeKey] ?? [])
        return globalAliases
    }
}

private final class AliasTableBuilder: SyntaxVisitor {
    static let globalScopeKey = ""

    private(set) var aliasesByScope: [String: [AliasDefinition]] = [:]
    private var scopeStack: [String] = []

    override init(viewMode: SyntaxTreeViewMode = .fixedUp) {
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.identifier.text)
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.identifier.text)
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.identifier.text)
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.identifier.text)
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(trimmedDescription(of: node.extendedType))
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: TypealiasDeclSyntax) -> SyntaxVisitorContinueKind {
        let target = TypeSyntax(node.initializer.value)
        let generics = node.genericParameterClause?.genericParameterList.map(\.name.text) ?? []
        let alias = AliasDefinition(name: node.identifier.text, genericParameters: generics, target: target)
        aliasesByScope[currentScopeKey, default: []].append(alias)
        return .skipChildren
    }

    private var currentScopeKey: String {
        scopeStack.joined(separator: ".")
    }
}

private struct TypeDetails {
    let text: String
    let resolvedText: String?
    let isOptional: Bool
    let isClosure: Bool
    let isInout: Bool
}

private struct TypeShape {
    let isOptional: Bool
    let isClosure: Bool
    let isInout: Bool
}

private func analyzeType(
    _ type: TypeSyntax?,
    aliasScope: [String: AliasDefinition],
    fallbackAliases: [String: String]
) -> TypeDetails? {
    guard let type else {
        return nil
    }

    let resolvedSyntax = resolveAliases(in: type, aliases: aliasScope)
    let text = trimmedDescription(of: type)
    let resolvedText: String?
    if let resolvedSyntax {
        resolvedText = trimmedDescription(of: resolvedSyntax)
    } else {
        let fallbackKey = fallbackAliases[text]
        ?? fallbackAliases[text.split(separator: ".").last.map(String.init) ?? text]
        resolvedText = fallbackKey
    }

    let originalShape = inspectTypeShape(type)
    let resolvedShape = resolvedSyntax.map { inspectTypeShape($0) }

    return TypeDetails(
        text: text,
        resolvedText: resolvedText,
        isOptional: originalShape.isOptional || (resolvedShape?.isOptional ?? false),
        isClosure: originalShape.isClosure || (resolvedShape?.isClosure ?? false),
        isInout: originalShape.isInout
    )
}

private func inspectTypeShape(_ type: TypeSyntax) -> TypeShape {
    var current = type
    var isInout = false
    current = stripAttributes(from: current, foundInout: &isInout)

    var isOptional = false
    if let optionalType = current.as(OptionalTypeSyntax.self) {
        isOptional = true
        current = stripAttributes(from: optionalType.wrappedType, foundInout: &isInout)
    } else if let implicitlyUnwrapped = current.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
        isOptional = true
        current = stripAttributes(from: implicitlyUnwrapped.wrappedType, foundInout: &isInout)
    }

    current = stripAttributes(from: current, foundInout: &isInout)
    let isClosure = current.is(FunctionTypeSyntax.self)

    return TypeShape(isOptional: isOptional, isClosure: isClosure, isInout: isInout)
}

private func stripAttributes(from type: TypeSyntax, foundInout: inout Bool) -> TypeSyntax {
    var current = type
    while let attributed = current.as(AttributedTypeSyntax.self) {
        if attributed.specifier?.tokenKind == .inoutKeyword {
            foundInout = true
        }
        current = attributed.baseType
    }
    return current
}

private func resolveAliases(in type: TypeSyntax, aliases: [String: AliasDefinition]) -> TypeSyntax? {
    var current = type
    var changed = false
    for _ in 0 ..< 8 {
        let resolver = AliasResolver(aliases: aliases)
        let rewritten = resolver.visit(current)
        if resolver.didRewrite {
            changed = true
            current = rewritten
        } else {
            break
        }
    }
    return changed ? current : nil
}

private final class AliasResolver: SyntaxRewriter {
    private let aliases: [String: AliasDefinition]
    private(set) var didRewrite = false

    init(aliases: [String: AliasDefinition]) {
        self.aliases = aliases
        super.init()
    }

    override func visit(_ node: SimpleTypeIdentifierSyntax) -> TypeSyntax {
        guard let alias = aliases[node.name.text],
              let replacement = alias.makeReplacement(arguments: node.genericArgumentClause, aliases: aliases) else {
            return super.visit(node)
        }

        didRewrite = true
        return replacement
    }
}

private final class GenericParameterSubstituter: SyntaxRewriter {
    private let substitutions: [String: TypeSyntax]

    init(substitutions: [String: TypeSyntax]) {
        self.substitutions = substitutions
        super.init()
    }

    override func visit(_ node: SimpleTypeIdentifierSyntax) -> TypeSyntax {
        if let replacement = substitutions[node.name.text] {
            return replacement
        }
        return super.visit(node)
    }
}

struct AliasDefinition {
    let name: String
    let genericParameters: [String]
    let target: TypeSyntax
}

private func makeAliasFallbacks(from definitions: [AliasDefinition]) -> [String: String] {
    guard !definitions.isEmpty else {
        return [:]
    }

    var map: [String: AliasDefinition] = [:]
    for definition in definitions {
        map[definition.name] = definition
    }

    var resolved: [String: String] = [:]

    func resolve(name: String, visited: inout Set<String>) -> String? {
        if let cached = resolved[name] {
            return cached
        }
        guard let definition = map[name] else {
            return nil
        }

        if visited.contains(name) {
            let text = trimmedDescription(of: definition.target)
            resolved[name] = text
            return text
        }

        visited.insert(name)
        let targetText = trimmedDescription(of: definition.target)
        if let nested = resolve(name: targetText, visited: &visited) {
            resolved[name] = nested
        } else {
            resolved[name] = targetText
        }
        visited.remove(name)
        return resolved[name]
    }

    for name in map.keys {
        var visited: Set<String> = []
        _ = resolve(name: name, visited: &visited)
    }

    return resolved
}

private extension AliasDefinition {
    func makeReplacement(arguments clause: GenericArgumentClauseSyntax?, aliases: [String: AliasDefinition]) -> TypeSyntax? {
        if genericParameters.isEmpty {
            return target
        }

        guard let clause else {
            return nil
        }

        guard clause.arguments.count == genericParameters.count else {
            return nil
        }

        var substitutions: [String: TypeSyntax] = [:]
        for (parameter, argument) in zip(genericParameters, clause.arguments) {
            substitutions[parameter] = argument.argumentType
        }

        let substituter = GenericParameterSubstituter(substitutions: substitutions)
        let substituted = substituter.visit(target)
        return TypeSyntax(substituted)
    }
}

private func parseAttributes(_ attributeList: AttributeListSyntax?) -> [String: [Syntax.Attribute]] {
    guard let attributeList else {
        return [:]
    }

    var attributes: [String: [Syntax.Attribute]] = [:]
    for element in attributeList {
        guard let attribute = element.as(AttributeSyntax.self) else {
            continue
        }
        let name = trimmedDescription(of: attribute.attributeName)
        let description = attribute.withoutTrivia().description.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = Syntax.Attribute(name: name, description: description.isEmpty ? "@\(name)" : description)
        attributes[name, default: []].append(value)
    }
    return attributes
}

private func makeModifiers(from modifierList: ModifierListSyntax?) -> [Syntax.Modifier] {
    guard let modifierList else {
        return []
    }
    return modifierList.map { modifier in
        Syntax.Modifier(name: trimmedDescription(of: modifier.name))
    }
}

private func genericRequirements(from clause: GenericWhereClauseSyntax?) -> [Syntax.GenericRequirement] {
    guard let clause else {
        return []
    }

    return clause.requirementList.compactMap { requirement in
        switch requirement.body {
        case let .conformanceRequirement(requirement):
            Syntax.GenericRequirement(
                leftTypeName: trimmedDescription(of: requirement.leftTypeIdentifier),
                rightTypeName: trimmedDescription(of: requirement.rightTypeIdentifier),
                relationshipSyntax: ":"
            )
        case let .sameTypeRequirement(requirement):
            Syntax.GenericRequirement(
                leftTypeName: trimmedDescription(of: requirement.leftTypeIdentifier),
                rightTypeName: trimmedDescription(of: requirement.rightTypeIdentifier),
                relationshipSyntax: "=="
            )
        case let .layoutRequirement(requirement):
            Syntax.GenericRequirement(
                leftTypeName: trimmedDescription(of: requirement.typeIdentifier),
                rightTypeName: trimmedDescription(of: requirement),
                relationshipSyntax: "layout"
            )
        }
    }
}

@inline(__always)
private func trimmedDescription(of syntax: SyntaxProtocol) -> String {
    syntax.withoutTrivia().description.trimmingCharacters(in: .whitespacesAndNewlines)
}

