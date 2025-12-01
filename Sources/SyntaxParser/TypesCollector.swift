import Foundation
import SwiftParser
import SwiftSyntax

struct TypesCollector {
    init() {}

    func collect(from content: String) -> [Syntax.TypeInfo] {
        let source = Parser.parse(source: content)
        return collect(from: source)
    }

    func collect(from source: SourceFileSyntax) -> [Syntax.TypeInfo] {
        let visitor = Visitor()
        visitor.walk(source)
        return visitor.types
    }
}

private final class Visitor: SyntaxVisitor {
    private(set) var types: [Syntax.TypeInfo] = []
    private var typesStack: [Syntax.TypeInfo] = []

    init() {
        super.init(viewMode: .fixedUp)
    }

    private var currentType: Syntax.TypeInfo? {
        get {
            typesStack.last
        }
        set {
            if let newValue, !typesStack.isEmpty {
                typesStack[typesStack.count - 1] = newValue
            }
        }
    }

    private func finalizeCurrentType() {
        if let currentType = typesStack.popLast() {
            types.append(currentType)
        }
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        typesStack.append(
            .init(
                scope: (typesStack.last?.scope ?? []) + [node.identifier.text],
                declaration: DeclSyntax(node)
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
                scope: (typesStack.last?.scope ?? []) + [node.identifier.text],
                declaration: DeclSyntax(node)
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
                scope: (typesStack.last?.scope ?? []) + [node.identifier.text],
                declaration: DeclSyntax(node)
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
                scope: (typesStack.last?.scope ?? []) + [node.identifier.text],
                declaration: DeclSyntax(node)
            )
        )
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedName = trimmedDescription(of: node.extendedType)
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
        currentType?.methods.append(node)
        return .skipChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        currentType?.initializers.append(node)
        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        currentType?.properties.append(node)
        return .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        currentType?.subscripts.append(node)

        return .skipChildren
    }

    private func accessLevel(from modifiers: ModifierListSyntax?) -> Syntax.AccessLevel {
        guard let modifiers else {
            return .internal
        }

        for modifier in modifiers {
            if let level = accessLevel(for: modifier.name.tokenKind) {
                return level
            }
        }

        return .internal
    }

    private func accessLevel(for tokenKind: TokenKind) -> Syntax.AccessLevel? {
        switch tokenKind {
        case .publicKeyword:
            .public
        case .fileprivateKeyword:
            .fileprivate
        case .privateKeyword:
            .private
        case .internalKeyword:
            .internal
        case .contextualKeyword("open"), .identifier("open"):
            .open
        case .contextualKeyword("package"), .identifier("package"):
            .package
        default:
            nil
        }
    }

    private func setterAccessLevel(from modifiers: ModifierListSyntax?) -> String? {
        guard let modifiers else {
            return nil
        }

        for modifier in modifiers {
            guard let detail = modifier.detail, detail.detail.text == "set" else {
                continue
            }
            if let level = accessLevel(for: modifier.name.tokenKind) {
                return level.rawValue
            }
        }

        return nil
    }

    override func visit(_ node: AssociatedtypeDeclSyntax) -> SyntaxVisitorContinueKind {
        currentType?.associatedTypes.append(node)
        return .skipChildren
    }

    private func inheritedTypes(from clause: TypeInheritanceClauseSyntax?) -> [String] {
        guard let inherited = clause?.inheritedTypeCollection else {
            return []
        }
        return inherited.map { trimmedDescription(of: $0.typeName) }
    }

    private func genericParameters(from clause: GenericParameterClauseSyntax?) -> [Syntax.GenericParameter] {
        guard let parameters = clause?.genericParameterList else {
            return []
        }

        return parameters.map { parameter in
            let constraints: [String] = if let inheritedType = parameter.inheritedType {
                [trimmedDescription(of: inheritedType)]
            } else {
                []
            }
            return Syntax.GenericParameter(
                name: parameter.name.text,
                constraints: constraints
            )
        }
    }

    private func primaryAssociatedTypes(from clause: PrimaryAssociatedTypeClauseSyntax?) -> [Syntax.GenericParameter] {
        guard let types = clause?.primaryAssociatedTypeList else {
            return []
        }

        return types.map { type in
            Syntax.GenericParameter(name: type.name.text)
        }
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

    private func initializerName(from node: InitializerDeclSyntax) -> String {
        var name = node.initKeyword.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let optionalMark = node.optionalMark {
            name += optionalMark.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let genericParameters = node.genericParameterClause {
            name += trimmedDescription(of: genericParameters)
        }
        name += trimmedDescription(of: node.signature.input)
        return name
    }

    private func inferTypeName(from expression: ExprSyntax) -> String? {
        if expression.is(BooleanLiteralExprSyntax.self) {
            return "Bool"
        }
        if expression.is(IntegerLiteralExprSyntax.self) {
            return "Int"
        }
        if expression.is(FloatLiteralExprSyntax.self) {
            return "Double"
        }
        if expression.is(StringLiteralExprSyntax.self) {
            return "String"
        }
        return nil
    }

    private func parseAnnotations(from comment: String?) -> [String: [String]] {
        guard let comment else {
            return [:]
        }

        var annotations: [String: [String]] = [:]
        let lines = comment.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("sourcery:"),
                  let sourceryRange = trimmed.range(of: "sourcery:")
            else {
                continue
            }

            let annotationContent = String(trimmed[sourceryRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !annotationContent.isEmpty else {
                continue
            }

            if let equalIndex = annotationContent.firstIndex(of: "=") {
                let key = String(annotationContent[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let rawValue = String(annotationContent[annotationContent.index(after: equalIndex)...])
                    .trimmingCharacters(in: .whitespaces)
                let values = parseAnnotationValues(rawValue)
                guard !key.isEmpty, !values.isEmpty else {
                    continue
                }
                annotations[key, default: []].append(contentsOf: values)
            } else {
                annotations[annotationContent, default: []].append(annotationContent)
            }
        }

        return annotations
    }

    private func parseAnnotationValues(_ rawValue: String) -> [String] {
        let value = rawValue.trimmingCharacters(in: .whitespaces)

        if value.hasPrefix("["), value.hasSuffix("]") {
            if let data = value.data(using: .utf8),
               let array = try? JSONSerialization.jsonObject(with: data) as? [Any] {
                return array.compactMap { element in
                    if let string = element as? String {
                        return string
                    } else if let number = element as? NSNumber {
                        return number.stringValue
                    }
                    return nil
                }
            }

            let inner = value.dropFirst().dropLast()
            return inner
                .split(separator: ",")
                .map { segment in
                    segment.trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
                .filter { !$0.isEmpty }
        }

        return [value.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))]
    }

    private func trimmedDescription(of syntax: SyntaxProtocol) -> String {
        syntax.withoutTrivia().description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func localName(for name: String) -> String {
        name.split(separator: ".").last.map(String.init) ?? name
    }

    private func accessorEffects(from accessor: PatternBindingSyntax.Accessor?) -> (isAsync: Bool, `throws`: Bool) {
        guard let accessor else {
            return (false, false)
        }

        guard case let .accessors(accessorBlock) = accessor else {
            if case let .getter(codeBlock) = accessor {
                let text = codeBlock.description
                return (text.contains("async"), text.contains("throws"))
            }
            return (false, false)
        }

        var getterIsAsync = false
        var getterThrows = false

        for accessorDecl in accessorBlock.accessors {
            guard accessorDecl.accessorKind.text == "get" else {
                continue
            }
            if let asyncKeyword = accessorDecl.asyncKeyword, asyncKeyword.presence == .present {
                let keywordText = asyncKeyword.text
                if keywordText == "async" || keywordText == "reasync" {
                    getterIsAsync = true
                } else if keywordText == "throws" || keywordText == "rethrows" {
                    getterThrows = true
                }
            }
            if let throwsKeyword = accessorDecl.throwsKeyword, throwsKeyword.presence == .present {
                let keywordText = throwsKeyword.text
                if keywordText == "throws" || keywordText == "rethrows" {
                    getterThrows = true
                }
            }
        }

        if !getterIsAsync || !getterThrows {
            let accessorText = accessorBlock.description
            if !getterIsAsync, accessorText.contains("async") {
                getterIsAsync = true
            }
            if !getterThrows, accessorText.contains("throws") {
                getterThrows = true
            }
        }

        return (getterIsAsync, getterThrows)
    }
}

func makeModifiers(from modifierList: ModifierListSyntax?) -> [Syntax.Modifier] {
    guard let modifierList else {
        return []
    }
    return modifierList.map { modifier in
        Syntax.Modifier(name: trimmedDescription(of: modifier.name))
    }
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
func trimmedDescription(of syntax: SyntaxProtocol) -> String {
    syntax.withoutTrivia().description.trimmingCharacters(in: .whitespacesAndNewlines)
}
