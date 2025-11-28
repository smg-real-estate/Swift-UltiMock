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

struct AliasDefinition: Equatable {
    let name: String
    let genericParameters: [String]
    let text: String
}
