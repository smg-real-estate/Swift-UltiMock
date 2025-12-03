import SwiftSyntax

struct TypeAliasCollector {
    func collect(from source: SourceFileSyntax) -> [String: [String: TypeAliasDeclSyntax]] {
        let aliasBuilder = AliasTableBuilder(viewMode: .fixedUp)
        aliasBuilder.walk(source)

        return aliasBuilder.aliasesByScope
    }
}

final class AliasTableBuilder: SyntaxVisitor {
    static let globalScopeKey = ""

    private(set) var aliasesByScope: [String: [String: TypeAliasDeclSyntax]] = [:]
    private var scopeStack: [String] = []

    override init(viewMode: SyntaxTreeViewMode = .fixedUp) {
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.name.text)
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        scopeStack.append(node.extendedType.trimmedDescription)
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        scopeStack.removeLast()
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        aliasesByScope[currentScopeKey, default: [:]][node.name.text] = node
        return .skipChildren
    }

    private var currentScopeKey: String {
        scopeStack.joined(separator: ".")
    }
}
