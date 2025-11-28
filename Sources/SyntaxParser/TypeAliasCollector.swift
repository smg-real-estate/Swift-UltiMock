import SwiftSyntax

struct TypeAliasCollector {
    func collect(from source: SourceFileSyntax) -> [String: [String : AliasDefinition]] {
        let aliasBuilder = AliasTableBuilder(viewMode: .fixedUp)
        aliasBuilder.walk(source)

        return aliasBuilder.aliasesByScope
    }
}

final class AliasTableBuilder: SyntaxVisitor {
    static let globalScopeKey = ""

    private(set) var aliasesByScope: [String: [String: AliasDefinition]] = [:]
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
        let text = trimmedDescription(of: target)
        let alias = AliasDefinition(name: node.identifier.text, genericParameters: generics, text: text)
        aliasesByScope[currentScopeKey, default: [:]][alias.name] = alias
        return .skipChildren
    }

    private var currentScopeKey: String {
        scopeStack.joined(separator: ".")
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

struct AliasDefinition: Equatable {
    let name: String
    let genericParameters: [String]
    let text: String
}

func makeAliasFallbacks(from definitions: [AliasDefinition]) -> [String: String] {
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
            let text = definition.text
            resolved[name] = text
            return text
        }

        visited.insert(name)
        let targetText = definition.text
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

func parseAttributes(_ attributeList: AttributeListSyntax?) -> [String: [Syntax.Attribute]] {
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

func makeModifiers(from modifierList: ModifierListSyntax?) -> [Syntax.Modifier] {
    guard let modifierList else {
        return []
    }
    return modifierList.map { modifier in
        Syntax.Modifier(name: trimmedDescription(of: modifier.name))
    }
}

func genericRequirements(from clause: GenericWhereClauseSyntax?) -> [Syntax.GenericRequirement] {
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

