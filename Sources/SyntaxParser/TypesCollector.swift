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
    private var currentTypeMethods: [Syntax.Method] = []
    private var currentTypeProperties: [Syntax.Property] = []
    private var currentTypeSubscripts: [Syntax.Subscript] = []
    private var currentTypeAssociatedTypes: [Syntax.AssociatedType] = []
    private var currentTypeAccessLevel: Syntax.AccessLevel = .internal
    private var currentTypeKind: Syntax.TypeInfo.Kind = .struct
    private var typeScopeStack: [String] = []

    private var isInsideType: Bool {
        !typeScopeStack.isEmpty
    }

    init() {
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
    }

    private func finalizeCurrentType() {
        if var lastType = types.last {
            types.removeLast()
            lastType.methods = currentTypeMethods
            lastType.properties = currentTypeProperties
            lastType.subscripts = currentTypeSubscripts
            lastType.associatedTypes = currentTypeAssociatedTypes
            types.append(lastType)
        }
        currentTypeMethods = []
        currentTypeProperties = []
        currentTypeSubscripts = []
        currentTypeAssociatedTypes = []
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
            commentTrivia: node.leadingTrivia,
            genericWhereClause: node.genericWhereClause
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
            commentTrivia: node.leadingTrivia,
            genericWhereClause: node.genericWhereClause
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
            genericParameters: genericParameters(from: node.genericParameters),
            commentTrivia: node.leadingTrivia,
            genericWhereClause: node.genericWhereClause
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
            genericParameters: primaryAssociatedTypes(from: node.primaryAssociatedTypeClause),
            commentTrivia: node.leadingTrivia,
            genericWhereClause: node.genericWhereClause
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
            genericWhereClause: node.genericWhereClause,
            isExtension: true
        )
        return .visitChildren
    }

    override func visitPost(_ node: ExtensionDeclSyntax) {
        finalizeCurrentType()
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isInsideType else {
            return .skipChildren
        }

        let parameterList = node.signature.input.parameterList
        let parameters = parameterList.map { parameter -> Syntax.Method.Parameter in
            return Syntax.Method.Parameter(parameter)
        }

        let methodModifiers = makeModifiers(from: node.modifiers)
        let modifierNames = Set(methodModifiers.map(\.name))

        let method = Syntax.Method(
            name: node.identifier.text,
            parameters: parameters,
            returnType: node.signature.output?.returnType.description.trimmingCharacters(in: .whitespacesAndNewlines),
            annotations: [:],
            accessLevel: effectiveMemberAccessLevel(from: node.modifiers).rawValue,
            modifiers: methodModifiers,
            attributes: parseAttributes(node.attributes),
            isAsync: node.signature.asyncOrReasyncKeyword != nil,
            throws: node.signature.throwsOrRethrowsKeyword != nil,
            definedInTypeIsExtension: currentTypeKind == .extension,
            isStatic: modifierNames.contains("static"),
            isClass: modifierNames.contains("class"),
            isInitializer: false,
            isRequired: modifierNames.contains("required"),
            genericParameters: genericParameters(from: node.genericParameterClause),
            genericRequirements: genericRequirements(from: node.genericWhereClause)
        )
        currentTypeMethods.append(method)

        return .skipChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isInsideType else {
            return .skipChildren
        }

        let parameters = node.signature.input.parameterList.map { parameter in
            Syntax.Method.Parameter(parameter)
        }

        let methodModifiers = makeModifiers(from: node.modifiers)
        let modifierNames = Set(methodModifiers.map(\.name))

        let initializer = Syntax.Method(
            name: initializerName(from: node),
            parameters: parameters,
            annotations: [:],
            accessLevel: effectiveMemberAccessLevel(from: node.modifiers).rawValue,
            modifiers: methodModifiers,
            attributes: parseAttributes(node.attributes),
            isAsync: node.signature.asyncOrReasyncKeyword != nil,
            throws: node.signature.throwsOrRethrowsKeyword != nil,
            definedInTypeIsExtension: currentTypeKind == .extension,
            isStatic: true,
            isClass: false,
            isInitializer: true,
            isRequired: modifierNames.contains("required"),
            genericParameters: genericParameters(from: node.genericParameterClause),
            genericRequirements: genericRequirements(from: node.genericWhereClause)
        )
        currentTypeMethods.append(initializer)

        return .skipChildren
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isInsideType else {
            return .skipChildren
        }

        let isVariable = node.letOrVarKeyword.tokenKind == .varKeyword
        let propAccessLevel = effectiveMemberAccessLevel(from: node.modifiers).rawValue
        let attributes = parseAttributes(node.attributes)
        let propertyModifiers = makeModifiers(from: node.modifiers)
        let modifierNames = Set(propertyModifiers.map(\.name))
        let isStatic = modifierNames.contains("static") || modifierNames.contains("class")
        let setterAccessOverride = setterAccessLevel(from: node.modifiers)

        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }

            let propertyName = pattern.identifier.text
            var propertyType = binding.typeAnnotation?.type.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if propertyType == nil, let initializer = binding.initializer {
                if let inferred = inferTypeName(from: initializer.value) {
                    propertyType = inferred
                }
            }
            let getterEffects = accessorEffects(from: binding.accessor)

            // Determine write access based on accessor block or explicit setter modifier
            let writeAccessLevel: String
            if let setterAccessOverride {
                writeAccessLevel = setterAccessOverride
            } else if let accessor = binding.accessor {
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
                type: propertyType ?? "",
                isVariable: isVariable,
                readAccess: propAccessLevel,
                writeAccess: writeAccessLevel,
                attributes: attributes,
                isAsync: getterEffects.isAsync,
                throws: getterEffects.throws,
                definedInTypeIsExtension: currentTypeKind == .extension,
                isStatic: isStatic
            )
            currentTypeProperties.append(property)
        }

        return .skipChildren
    }

    override func visit(_ node: SubscriptDeclSyntax) -> SyntaxVisitorContinueKind {
        guard isInsideType else {
            return .skipChildren
        }

        let parameters = node.indices.parameterList.map { parameter in
            Syntax.Method.Parameter(parameter)
        }

        let subscriptAccessLevel = effectiveMemberAccessLevel(from: node.modifiers).rawValue

        let writeAccessLevel: String
        if let accessor = node.accessor, case let .accessors(accessorBlock) = accessor {
            let hasSetter = accessorBlock.accessors.contains { accessor in
                let kindText = accessor.accessorKind.text
                return kindText == "set" || kindText == "_modify"
            }
            writeAccessLevel = hasSetter ? subscriptAccessLevel : ""
        } else {
            writeAccessLevel = subscriptAccessLevel
        }

        let subscriptInfo = Syntax.Subscript(
            parameters: parameters,
            returnType: node.result.returnType.description.trimmingCharacters(in: .whitespacesAndNewlines),
            readAccess: subscriptAccessLevel,
            writeAccess: writeAccessLevel,
            attributes: parseAttributes(node.attributes)
        )
        currentTypeSubscripts.append(subscriptInfo)

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
        guard isInsideType else {
            return .skipChildren
        }

        let constraint: String?
        if let clause = node.inheritanceClause {
            let inherited = clause.inheritedTypeCollection.map { inheritedType in
                trimmedDescription(of: inheritedType.typeName)
            }
            constraint = inherited.isEmpty ? nil : inherited.joined(separator: " & ")
        } else {
            constraint = nil
        }

        let associatedType = Syntax.AssociatedType(
            name: node.identifier.text,
            typeNameString: constraint
        )
        currentTypeAssociatedTypes.append(associatedType)

        return .skipChildren
    }

    // For protocol members without explicit access modifiers, inherit the protocol's access level
    private func effectiveMemberAccessLevel(from modifiers: ModifierListSyntax?) -> Syntax.AccessLevel {
        let explicitLevel = accessLevel(from: modifiers)

        // If the member has an explicit access level, use it
        if let modifiers, !modifiers.isEmpty {
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
        genericWhereClause: GenericWhereClauseSyntax? = nil,
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
            comment: rawComment(from: commentTrivia),
            genericRequirements: genericRequirements(from: genericWhereClause)
        )

        types.append(type)
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
