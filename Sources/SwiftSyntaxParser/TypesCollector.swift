import Foundation
import SwiftSyntax

public struct TypesCollector {
    public init() {}

    public func collect(from source: SourceFileSyntax) -> [Syntax.TypeInfo] {
        let visitor = Visitor()
        visitor.walk(source)
        return visitor.types
    }
}

private final class Visitor: SyntaxVisitor {
    private(set) var types: [Syntax.TypeInfo] = []

    init() {
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        appendType(
            kind: .struct,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        appendType(
            kind: .class,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        appendType(
            kind: .enum,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        appendType(
            kind: .protocol,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        appendType(
            kind: .extension,
            name: trimmedDescription(of: node.extendedType),
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            commentTrivia: node.leadingTrivia,
            isExtension: true
        )
        return .visitChildren
    }

    private func accessLevel(from modifiers: ModifierListSyntax?) -> Syntax.AccessLevel {
        guard let modifiers else {
            return .internal
        }

        for modifier in modifiers {
            switch modifier.name.tokenKind {
            case .publicKeyword:
                return .public
            case .fileprivateKeyword:
                return .fileprivate
            case .privateKeyword:
                return .private
            case .internalKeyword:
                return .internal
            case .contextualKeyword("open"), .identifier("open"):
                return .open
            case .contextualKeyword("package"), .identifier("package"):
                return .package
            default:
                continue
            }
        }

        return .internal
    }

    private func inheritedTypes(from clause: TypeInheritanceClauseSyntax?) -> [String] {
        guard let inherited = clause?.inheritedTypeCollection else {
            return []
        }
        return inherited.map { trimmedDescription(of: $0.typeName) }
    }

    // Extracts contiguous comment trivia into a raw string, preserving explicit line breaks.
    private func rawComment(from trivia: Trivia?) -> String? {
        guard let trivia else {
            return nil
        }

        let text = trivia.compactMap { piece -> String? in
            switch piece {
            case let .lineComment(string),
                 let .docLineComment(string),
                 let .blockComment(string),
                 let .docBlockComment(string):
                return string
            case let .newlines(count):
                return String(repeating: "\n", count: count)
            default:
                return nil
            }
        }.joined()

        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        return text
    }

    private func appendType(
        kind: Syntax.TypeInfo.Kind,
        name: String,
        modifiers: ModifierListSyntax?,
        inheritanceClause: TypeInheritanceClauseSyntax?,
        commentTrivia: Trivia?,
        isExtension: Bool = false
    ) {
        let type = Syntax.TypeInfo(
            kind: kind,
            name: name,
            localName: localName(for: name),
            accessLevel: accessLevel(from: modifiers),
            inheritedTypes: inheritedTypes(from: inheritanceClause),
            isExtension: isExtension,
            comment: rawComment(from: commentTrivia)
        )

        types.append(type)
    }

    private func trimmedDescription(of syntax: SyntaxProtocol) -> String {
        syntax.withoutTrivia().description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func localName(for name: String) -> String {
        name.split(separator: ".").last.map(String.init) ?? name
    }
}
