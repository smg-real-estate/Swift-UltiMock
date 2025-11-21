import Foundation
import SwiftSyntax

public struct TypesCollector {
    public init() {}

    public func collect(from source: SourceFileSyntax) -> [Syntax.TypeInfo] {
        let aliasBuilder = AliasTableBuilder(viewMode: .fixedUp)
        aliasBuilder.walk(source)

        let aliasTable = aliasBuilder.aliasesByScope
        let globalAliases = Dictionary(uniqueKeysWithValues: (aliasTable[AliasTableBuilder.globalScopeKey] ?? [])
            .map { ($0.name, $0) })

        let visitor = Visitor(globalAliases: globalAliases, aliasTable: aliasTable)
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
    private var currentTypeAssociatedTypes: [Syntax.AssociatedType] = []
    private var currentTypeAccessLevel: Syntax.AccessLevel = .internal
    private var currentTypeKind: Syntax.TypeInfo.Kind = .struct
    private let globalAliases: [String: AliasDefinition]
    private let aliasTable: [String: [AliasDefinition]]
    private var aliasScopeStack: [[String: AliasDefinition]]
    private var typeScopeStack: [String] = []

    init(globalAliases: [String: AliasDefinition], aliasTable: [String: [AliasDefinition]]) {
        self.globalAliases = globalAliases
        self.aliasTable = aliasTable
        self.aliasScopeStack = [globalAliases]
        super.init(viewMode: .fixedUp)
    }

    private var currentScopeKey: String {
        typeScopeStack.joined(separator: ".")
    }

    private func beginType(kind: Syntax.TypeInfo.Kind, name: String, modifiers: ModifierListSyntax?) {
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeAssociatedTypes = []
        currentTypeKind = kind
        currentTypeAccessLevel = accessLevel(from: modifiers)
        typeScopeStack.append(name)
        let aliasDefinitions = aliasTable[currentScopeKey] ?? []
        currentTypeTypealiases = aliasDefinitions.map { Syntax.Typealias(name: $0.name, target: $0.target) }
        pushAliasScope(with: aliasDefinitions)
    }

    private func pushAliasScope(with definitions: [AliasDefinition]) {
        let parent = aliasScopeStack.last ?? [:]
        guard !definitions.isEmpty else {
            aliasScopeStack.append(parent)
            return
        }
        var merged = parent
        for definition in definitions {
            merged[definition.name] = definition
        }
        aliasScopeStack.append(merged)
    }

    private func popAliasScope() {
        guard aliasScopeStack.count > 1 else { return }
        aliasScopeStack.removeLast()
    }

    private func finalizeCurrentType() {
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
                extensions: lastType.extensions,
                annotations: lastType.annotations,
                isExtension: lastType.isExtension,
                comment: lastType.comment,
                associatedTypes: currentTypeAssociatedTypes,
                genericRequirements: lastType.genericRequirements
            )
            types.append(lastType)
        }
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeTypealiases = []
        currentTypeAssociatedTypes = []
        popAliasScope()
        if !typeScopeStack.isEmpty {
            typeScopeStack.removeLast()
        }
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        beginType(kind: .struct, name: node.identifier.text, modifiers: node.modifiers)
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
        finalizeCurrentType()
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        beginType(kind: .class, name: node.identifier.text, modifiers: node.modifiers)
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
        finalizeCurrentType()
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        beginType(kind: .enum, name: node.identifier.text, modifiers: node.modifiers)
        appendType(
            kind: .enum,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visitPost(_ node: EnumDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        beginType(kind: .protocol, name: node.identifier.text, modifiers: node.modifiers)
        appendType(
            kind: .protocol,
            name: node.identifier.text,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            commentTrivia: node.leadingTrivia
        )
        return .visitChildren
    }

    override func visitPost(_ node: ProtocolDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedName = trimmedDescription(of: node.extendedType)
        beginType(kind: .extension, name: extendedName, modifiers: node.modifiers)

        appendType(
            kind: .extension,
            name: extendedName,
            modifiers: node.modifiers,
            inheritanceClause: node.inheritanceClause,
            commentTrivia: node.leadingTrivia,
            isExtension: true
        )
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        finalizeCurrentType()
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

        let methodGenericParameters = genericParameters(from: node.genericParameterClause)
        
        let methodGenericRequirements: [Syntax.GenericRequirement]
        if let whereClause = node.genericWhereClause {
            methodGenericRequirements = whereClause.requirementList.compactMap { requirement in
                guard let conformanceRequirement = requirement.body.as(ConformanceRequirementSyntax.self) else {
                    return nil
                }
                return Syntax.GenericRequirement(
                    leftTypeName: trimmedDescription(of: conformanceRequirement.leftTypeIdentifier),
                    rightTypeName: trimmedDescription(of: conformanceRequirement.rightTypeIdentifier),
                    relationshipSyntax: ":"
                )
            }
        } else {
            methodGenericRequirements = []
        }

        let method = Syntax.Method(
            name: node.identifier.text,
            parameters: parameters,
            returnType: returnType,
            accessLevel: effectiveMemberAccessLevel(from: node.modifiers).rawValue,
            genericParameters: methodGenericParameters,
            genericRequirements: methodGenericRequirements
        )
        currentTypeMethods.append(method)

        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        let isVariable = node.letOrVarKeyword.tokenKind == .varKeyword
        let propAccessLevel = effectiveMemberAccessLevel(from: node.modifiers).rawValue

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

            // Determine write access based on accessor block
            let writeAccessLevel: String
            if let accessor = binding.accessor {
                if case let .accessors(accessorBlock) = accessor {
                    // Check if there's a setter
                    let hasSetter = accessorBlock.accessors.contains(where: { accessor in
                        let kind = accessor.accessorKind.text
                        return kind == "set" || kind == "_modify"
                    })
                    
                    if hasSetter {
                        writeAccessLevel = propAccessLevel
                    } else {
                        writeAccessLevel = "" // No write access (read-only with { get })
                    }
                } else {
                    // Has getter/setter code block, not just accessors
                    // Assume it's a computed property if there's a code block and it's a var
                    writeAccessLevel = isVariable ? propAccessLevel : ""
                }
            } else {
                // No accessor block means stored property - has write access if it's var
                writeAccessLevel = isVariable ? propAccessLevel : ""
            }

            let property = Syntax.Property(
                name: propertyName,
                type: typeAnnotation,
                isVariable: isVariable,
                readAccess: propAccessLevel,
                writeAccess: writeAccessLevel
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
        let subscriptAccessLevel = effectiveMemberAccessLevel(from: node.modifiers).rawValue

        let subscriptInfo = Syntax.Subscript(
            parameters: parameters,
            returnType: returnType,
            readAccess: subscriptAccessLevel,
            writeAccess: subscriptAccessLevel
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
    
    // For protocol members without explicit access modifiers, inherit the protocol's access level
    private func effectiveMemberAccessLevel(from modifiers: ModifierListSyntax?) -> Syntax.AccessLevel {
        let explicitLevel = accessLevel(from: modifiers)
        
        // If the member has an explicit access level, use it
        if let modifiers = modifiers, !modifiers.isEmpty {
            return explicitLevel
        }
        
        // For protocol members without explicit modifiers, use the protocol's access level
        if currentTypeKind == .protocol {
            return currentTypeAccessLevel
        }
        
        // For other types, use internal as default
        return explicitLevel
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

private struct AliasDefinition: Equatable {
    let name: String
    let genericParameters: [String]
    let target: String
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
        let target = trimmedDescription(of: node.initializer.value)
        let generics = node.genericParameterClause?.genericParameterList.map { $0.name.text } ?? []
        let alias = AliasDefinition(name: node.identifier.text, genericParameters: generics, target: target)
        aliasesByScope[currentScopeKey, default: []].append(alias)
        return .skipChildren
    }

    private var currentScopeKey: String {
        scopeStack.joined(separator: ".")
    }

    private func trimmedDescription(of syntax: SyntaxProtocol) -> String {
        syntax.withoutTrivia().description.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
