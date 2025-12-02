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
        visitor.walk(source.strippingImplementation())
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

    private var currentScope: [String] {
        currentType?.scope ?? []
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
                scope: currentScope,
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
                scope: currentScope,
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
                scope: currentScope,
                declaration: DeclSyntax(node)
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
//        currentType?.methods.append(node)
        .skipChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
//        currentType?.initializers.append(node)
        .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
//        currentType?.properties.append(node)
        .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
//        currentType?.subscripts.append(node)

        .skipChildren
    }

    override func visit(_ node: AssociatedTypeDeclSyntax) -> SyntaxVisitorContinueKind {
//        currentType?.associatedTypes.append(node)
        .skipChildren
    }

    private func inheritedTypes(from clause: InheritanceClauseSyntax?) -> [String] {
        guard let inherited = clause?.inheritedTypes else {
            return []
        }
        return inherited.map(\.type.trimmedDescription)
    }

    private func genericParameters(from clause: GenericParameterClauseSyntax?) -> [Syntax.GenericParameter] {
        guard let parameters = clause?.parameters else {
            return []
        }

        return parameters.map { parameter in
            let constraints: [String] = if let inheritedType = parameter.inheritedType {
                [inheritedType.trimmedDescription]
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
        guard let types = clause?.primaryAssociatedTypes else {
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
            name += genericParameters.trimmedDescription
        }
        name += node.signature.parameterClause.trimmedDescription
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

    private func localName(for name: String) -> String {
        name.split(separator: ".").last.map(String.init) ?? name
    }
}

func makeModifiers(from modifierList: DeclModifierListSyntax?) -> [Syntax.Modifier] {
    guard let modifierList else {
        return []
    }
    return modifierList.map { modifier in
        Syntax.Modifier(name: modifier.name.trimmedDescription)
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
        let name = attribute.attributeName.trimmedDescription
        let description = attribute.trimmedDescription
        let value = Syntax.Attribute(name: name, description: description.isEmpty ? "@\(name)" : description)
        attributes[name, default: []].append(value)
    }
    return attributes
}
