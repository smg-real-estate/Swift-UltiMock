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
    private var currentTypeMethods: [Syntax.Method] = []
    private var currentTypeProperties: [Syntax.Property] = []
    private var currentTypeSubscripts: [Syntax.Subscript] = []
    private var currentTypeTypealiases: [Syntax.Typealias] = []

    init() {
        super.init(viewMode: .fixedUp)
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []

        appendType(
            kind: .struct,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            genericParameters: genericParameters(from: node.genericParameterClause),
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visitPost(_ node: StructDeclSyntax) {
        if var lastType = types.last {
            types.removeLast()
            lastType = Syntax.TypeInfo(
                kind: lastType.kind,
                name: lastType.name,
                localName: lastType.localName,
                accessLevel: lastType.accessLevel,
                inheritedTypes: lastType.inheritedTypes,
                genericParameters: lastType.genericParameters,
                methods: currentTypeMethods,
                properties: currentTypeProperties,
                subscripts: currentTypeSubscripts,
                typealiases: currentTypeTypealiases,
                annotations: lastType.annotations,
                isExtension: lastType.isExtension,
                comment: lastType.comment
            )
            types.append(lastType)
        }
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []

        appendType(
            kind: .class,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            genericParameters: genericParameters(from: node.genericParameterClause),
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visitPost(_ node: ClassDeclSyntax) {
        if var lastType = types.last {
            types.removeLast()
            lastType = Syntax.TypeInfo(
                kind: lastType.kind,
                name: lastType.name,
                localName: lastType.localName,
                accessLevel: lastType.accessLevel,
                inheritedTypes: lastType.inheritedTypes,
                genericParameters: lastType.genericParameters,
                methods: currentTypeMethods,
                properties: currentTypeProperties,
                subscripts: currentTypeSubscripts,
                typealiases: currentTypeTypealiases,
                annotations: lastType.annotations,
                isExtension: lastType.isExtension,
                comment: lastType.comment
            )
            types.append(lastType)
        }
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []

        appendType(
            kind: .enum,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            genericParameters: genericParameters(from: node.genericParameters),
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        if var lastType = types.last {
            types.removeLast()
            lastType = Syntax.TypeInfo(
                kind: lastType.kind,
                name: lastType.name,
                localName: lastType.localName,
                accessLevel: lastType.accessLevel,
                inheritedTypes: lastType.inheritedTypes,
                genericParameters: lastType.genericParameters,
                methods: currentTypeMethods,
                properties: currentTypeProperties,
                subscripts: currentTypeSubscripts,
                typealiases: currentTypeTypealiases,
                annotations: lastType.annotations,
                isExtension: lastType.isExtension,
                comment: lastType.comment
            )
            types.append(lastType)
        }
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []

        appendType(
            kind: .protocol,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            genericParameters: primaryAssociatedTypes(from: node.primaryAssociatedTypeClause),
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        if var lastType = types.last {
            types.removeLast()
            lastType = Syntax.TypeInfo(
                kind: lastType.kind,
                name: lastType.name,
                localName: lastType.localName,
                accessLevel: lastType.accessLevel,
                inheritedTypes: lastType.inheritedTypes,
                genericParameters: lastType.genericParameters,
                methods: currentTypeMethods,
                properties: currentTypeProperties,
                subscripts: currentTypeSubscripts,
                typealiases: currentTypeTypealiases,
                annotations: lastType.annotations,
                isExtension: lastType.isExtension,
                comment: lastType.comment
            )
            types.append(lastType)
        }
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []

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

    override func visitPost(_ node: ExtensionDeclSyntax) {
        if var lastType = types.last {
            types.removeLast()
            lastType = Syntax.TypeInfo(
                kind: lastType.kind,
                name: lastType.name,
                localName: lastType.localName,
                accessLevel: lastType.accessLevel,
                inheritedTypes: lastType.inheritedTypes,
                genericParameters: lastType.genericParameters,
                methods: currentTypeMethods,
                properties: currentTypeProperties,
                subscripts: currentTypeSubscripts,
                typealiases: currentTypeTypealiases,
                annotations: lastType.annotations,
                isExtension: lastType.isExtension,
                comment: lastType.comment
            )
            types.append(lastType)
        }
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let parameters = node.signature.input.parameterList.map { parameter in
            let label: String? = if let firstName = parameter.firstName {
                firstName.text
            } else {
                nil
            }
            let name = parameter.secondName?.text ?? parameter.firstName?.text ?? ""
            let type: String? = if let paramType = parameter.type {
                trimmedDescription(of: paramType)
            } else {
                nil
            }
            return Syntax.Method.Parameter(label: label, name: name, type: type)
        }

        let returnType: String? = if let output = node.signature.output {
            trimmedDescription(of: output.returnType)
        } else {
            nil
        }

        let method = Syntax.Method(
            name: node.identifier.text,
            parameters: parameters,
            returnType: returnType
        )
        currentTypeMethods.append(method)

        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isVariable = node.letOrVarKeyword.tokenKind == .varKeyword

        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let propertyName = pattern.identifier.text
            let typeAnnotation: String? = if let annotation = binding.typeAnnotation {
                trimmedDescription(of: annotation.type)
            } else {
                nil
            }

            let property = Syntax.Property(
                name: propertyName,
                type: typeAnnotation,
                isVariable: isVariable
            )
            currentTypeProperties.append(property)
        }

        return .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        let parameters = node.indices.parameterList.map { parameter in
            let label: String? = if let firstName = parameter.firstName {
                firstName.text
            } else {
                nil
            }
            let name = parameter.secondName?.text ?? parameter.firstName?.text ?? ""
            let type: String? = if let paramType = parameter.type {
                trimmedDescription(of: paramType)
            } else {
                nil
            }
            return Syntax.Method.Parameter(label: label, name: name, type: type)
        }

        let returnType = trimmedDescription(of: node.result.returnType)

        let subscriptInfo = Syntax.Subscript(
            parameters: parameters,
            returnType: returnType
        )
        currentTypeSubscripts.append(subscriptInfo)

        return .skipChildren
    }

    override func visit(_ node: TypealiasDeclSyntax) -> SyntaxVisitorContinueKind {
        let target = trimmedDescription(of: node.initializer.value)
        let typealiasInfo = Syntax.Typealias(
            name: node.identifier.text,
            target: target
        )
        currentTypeTypealiases.append(typealiasInfo)

        return .skipChildren
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

    private func appendType(
        kind: Syntax.TypeInfo.Kind,
        name: String,
        modifiers: ModifierListSyntax?,
        inheritanceClause: TypeInheritanceClauseSyntax?,
        genericParameters: [Syntax.GenericParameter] = [],
        commentTrivia: Trivia?,
        isExtension: Bool = false
    ) {
        let type = Syntax.TypeInfo(
            kind: kind,
            name: name,
            localName: localName(for: name),
            accessLevel: accessLevel(from: modifiers),
            inheritedTypes: inheritedTypes(from: inheritanceClause),
            genericParameters: genericParameters,
            annotations: parseAnnotations(from: rawComment(from: commentTrivia)),
            isExtension: isExtension,
            comment: rawComment(from: commentTrivia)
        )

        types.append(type)
    }

    private func parseAnnotations(from comment: String?) -> [String: String] {
        guard let comment = comment else { return [:] }
        
        var annotations: [String: String] = [:]
        let lines = comment.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Check if line contains sourcery annotation
            guard trimmed.contains("sourcery:") else { continue }
            
            // Extract the part after "sourcery:"
            guard let sourceryRange = trimmed.range(of: "sourcery:") else { continue }
            let annotationContent = String(trimmed[sourceryRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // Skip empty annotations
            guard !annotationContent.isEmpty else { continue }
            
            // Parse key=value or just key
            if let equalIndex = annotationContent.firstIndex(of: "=") {
                let key = String(annotationContent[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(annotationContent[annotationContent.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    annotations[key] = value
                }
            } else {
                annotations[annotationContent] = annotationContent
            }
        }
        
        return annotations
    }

    private func trimmedDescription(of syntax: SyntaxProtocol) -> String {
        syntax.withoutTrivia().description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func localName(for name: String) -> String {
        name.split(separator: ".").last.map(String.init) ?? name
    }
}
