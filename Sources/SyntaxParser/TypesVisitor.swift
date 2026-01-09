import Foundation
import SwiftParser
import SwiftSyntax

final class TypesVisitor: SyntaxVisitor {
    private(set) var types: [Syntax.TypeInfo] = []
    private var typesStack: [Syntax.TypeInfo] = []

    init() {
        super.init(viewMode: .fixedUp)
    }

    private var currentScope: [String] {
        typesStack.last?.scope ?? []
    }

    private func finalizeCurrentType() {
        if let currentType = typesStack.popLast() {
            types.append(currentType)
        }
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        typesStack.append(
            .init(
                scope: (typesStack.last?.scope ?? []) + [node.name.text],
                declaration: DeclSyntax(node).detached
            )
        )
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        typesStack.append(
            .init(
                scope: currentScope,
                declaration: DeclSyntax(node).detached
            )
        )
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        typesStack.append(
            .init(
                scope: currentScope,
                declaration: DeclSyntax(node).detached
            )
        )
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        typesStack.append(
            .init(
                scope: currentScope,
                declaration: DeclSyntax(node).detached
            )
        )
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedName = node.extendedType.trimmedDescription
        typesStack.append(
            .init(
                scope: (typesStack.last?.scope ?? []) + [extendedName],
                declaration: DeclSyntax(node)
            )
        )
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }
}
