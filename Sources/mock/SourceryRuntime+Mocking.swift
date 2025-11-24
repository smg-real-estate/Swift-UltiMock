import Foundation
import SyntaxParser

extension Syntax.Method {
    var isPrivate: Bool {
        modifiers.contains {
            $0.name == "private"
        }
    }

    var implementationAccessLevel: String {
        accessLevel.replacingOccurrences(of: "open", with: "public")
    }

    var definedInExtension: Bool {
        definedInType?.isExtension ?? false
    }

    func parameterDefinitions(named: Bool, _ mockTypeName: String) -> [String] {
        parameters.map {
            (named ? "\($0.name): " : "")
                + $0.typeName.actualTypeNameExceptSelf.name(convertingImplicitOptional: true)
                .replacingOccurrences(of: "Self", with: mockTypeName)
                .replacingOccurrences(of: "some ", with: "any ")
        }
    }

    var whereConstraints: String? {
        // First check if we have generic requirements
        if !genericRequirements.isEmpty {
            return genericRequirements.map { requirement in
                switch requirement.relationshipSyntax {
                case ":", "layout":
                    "\(requirement.leftTypeName): \(requirement.rightTypeName)"
                case "==":
                    "\(requirement.leftTypeName) == \(requirement.rightTypeName)"
                default:
                    "\(requirement.leftTypeName): \(requirement.rightTypeName)"
                }
            }.joined(separator: ", ")
        }

        // Fallback to parsing from return type for backward compatibility
        let components = returnTypeName.name
            .components(separatedBy: "where")

        guard components.count == 2 else {
            return nil
        }
        return components[1].trimmed
    }

    func postParametersDefinition(_ selfSubstitute: String? = nil, inClosure: Bool) -> String {
        var returnType = returnTypeName.actualTypeNameExceptSelf
            .name(convertingImplicitOptional: inClosure)
            .components(separatedBy: "where")[0]
            .trimmed

        if let selfSubstitute {
            returnType = returnType
                .replacingOccurrences(of: "Self", with: selfSubstitute)
        }
        return "\(isAsync ? "async " : "")\(`throws` ? "throws " : "")-> \(returnType)"
    }

    func closureDefinition(namedParameters: Bool = true, _ mockTypeName: String, _ substituteReturnSelf: Bool = false, forwarding: Bool) -> String {
        let parameters = (forwarding ? ["_ forwardToOriginal: " + closureDefinition(
            mockTypeName,
            substituteReturnSelf,
            forwarding: false
        )] : []
        )
            + parameterDefinitions(named: namedParameters, mockTypeName).map { "_ \($0)" }
        return "(\(parameters.joined(separator: ", "))) \(postParametersDefinition(substituteReturnSelf ? mockTypeName : nil, inClosure: true))"
    }

    func signature(namedParameters: Bool = true, _ mockTypeName: String, substituteReturnSelf: Bool = false) -> String {
        sanitizeFunctionType(
            closureDefinition(namedParameters: namedParameters, mockTypeName, substituteReturnSelf, forwarding: false)
        )
    }

    var rawSignature: String {
        signature(namedParameters: false, "Self")
    }

    var parametersPart: String {
        parameters.map {
            "\($0.argumentLabel?.trimmedBackticks ?? "")_\($0.name.trimmedBackticks)_\($0.argumentTypePart)"
        }
        .joined(separator: "_")
    }

    var unbacktickedCallName: String {
        callName.replacingOccurrences(of: "`", with: "")
    }

    var methodIdentifier: String {
        "\(unbacktickedCallName)_\(isAsync ? "async" : "sync")\(parametersPart)_ret_\(returnTypePart)\(whereClauseIdentifier)"
    }

    private var whereClauseIdentifier: String {
        guard !genericRequirements.isEmpty else {
            return ""
        }

        let components = genericRequirements.map { requirement -> String in
            let left = sanitizedIdentifierComponent(from: requirement.leftTypeName)
            let right = sanitizedIdentifierComponent(from: requirement.rightTypeName)
            switch requirement.relationshipSyntax {
            case ":":
                return "\(left)_conforms_\(right)"
            case "==":
                return "\(left)_equals_\(right)"
            default:
                return "\(left)_layout_\(right)"
            }
        }

        return "_where_" + components.joined(separator: "_and_")
    }

    var genericClause: String {
        guard !genericParameters.isEmpty else {
            return ""
        }

        let params = genericParameters.map { param in
            if param.constraints.isEmpty {
                param.name
            } else {
                "\(param.name): \(param.constraints.joined(separator: " & "))"
            }
        }.joined(separator: ", ")

        return "<\(params)>"
    }

    var definition: String {
        """
        static var \(methodIdentifier): MockMethod {
            .init {\(parameters.isEmpty ? " _ in" : "")
                \"\(shortName)(\(parameters.enumerated().map { $0.element.description(at: $0.offset) }.joined(separator: ", ")))\"
            }
        }
        """
    }

    var parameterPlaceholders: String {
        if parameters.isEmpty {
            ""
        } else {
            " \(parameters.map { _ in "_" }.joined(separator: ", ")) in "
        }
    }

    func performClosureParameters(prepending: [String]) -> String {
        let parameters = prepending + parameters.map(\.name)
        return parameters.isEmpty ? "" : " \(parameters.joined(separator: ", ")) in"
    }

    func expectationDefinitionParameters(_ mockTypeName: String) -> String {
        parameters.map {
            $0.expectationConstructorDefinition(mockTypeName)
        }
        .joined(separator: ", ")
    }

    func expectationConstructor(_ mockTypeName: String, forwarding: Bool) -> String {
        (
            expectationAttributes +
                [
                    """
                    \(implementationAccessLevel) static func \(shortName)\(genericClause)(\(expectationDefinitionParameters(mockTypeName))) -> Self
                    where Signature == \(signature(mockTypeName, substituteReturnSelf: true))\(whereConstraints.map { ", \($0)" } ?? "") {
                        .init(
                            method: Methods.\(methodIdentifier),
                            parameters: [\(parameters.map { "\($0.forwardedName).anyParameter" }.joined(separator: ", "))]
                        )
                    }
                    """
                ]
        ).joined(separator: "\n")
    }

    func mockExpect(_ mockTypeName: String, forwarding: Bool) -> String {
        [
            """
                \(attributes.filter { !["discardableResult", "objc"].contains($0.key) }.values.flatMap(\.self).map(\.description).joined(separator: "\n"))
                \(implementationAccessLevel) func expect\(genericClause)(
                    _ expectation: MethodExpectation<\(signature(mockTypeName, substituteReturnSelf: true))>,
                    fileID: String = #fileID,
                    filePath: StaticString = #filePath,
                    line: UInt = #line,
                    column: Int = #column,
                    perform: @escaping \(closureDefinition(mockTypeName, true, forwarding: forwarding))\(defaultPerformClosure(forwarding: forwarding))
                ) {
                    _record(
                        expectation.expectation,
                        fileID,
                        filePath,
                        line,
                        column,
                        perform
                    )
                }
            """
        ]
            .joined(separator: "\n")
    }

    func defaultPerformClosure(forwarding: Bool) -> String {
        guard forwarding else {
            guard returnTypeName.isVoid else {
                return ""
            }
            return " = {\(parameterPlaceholders)}"
        }
        let forwardingParameterName = "_forwardToSuper"
        return """
         = {\(performClosureParameters(prepending: [forwardingParameterName]))
                    \(callAttributes)\(forwardingParameterName)(\(forwardedParameters()))
                }
        """
    }

    func fullDefinition(_ mockTypeName: String, override: Bool) -> String {
        (
            attributes.values.flatMap(\.self).map(\.description) +
                [
                    "\(implementationAccessLevel)\(override ? " override" : "") func \(shortName)\(genericClause)("
                        + parameters.map {
                            $0.implementationDefinition(mockTypeName)
                        }
                        .joined(separator: ", ")
                        + ") \(postParametersDefinition(inClosure: false))"
                ]
        )
        .joined(separator: "\n")
    }

    func forwardedParameters(prepending: [String] = []) -> String {
        (prepending + parameters.map(\.forwardedString))
            .joined(separator: ", ")
    }

    func recordedParameters() -> String {
        parameters.map(\.forwardedName)
            .joined(separator: ", ")
    }

    func forwardedParameters(callToSuper: Bool) -> String {
        forwardedParameters(prepending: callToSuper ? [selectorName == "`self`" ? "{ self }" : "super.\(selectorName)"] : [])
    }

    var forwardedLabeledParameters: String {
        if parameters.isEmpty {
            ""
        } else {
            "\(parameters.map { "\($0.argumentLabel.map { $0 + ": " } ?? "")\($0.name)" }.joined(separator: ", "))"
        }
    }

    var returnTypePart: String {
        returnTypeName.escapedIdentifierName()
    }

    var callAttributes: String {
        callAttributesArray.joined(separator: " ")
    }

    @ArrayBuilder<String>
    var callAttributesArray: [String] {
        if `throws` {
            "try"
        }
        if isAsync {
            "await"
        }
        ""
    }

    @StringBuilder
    func implementation(_ mockTypeName: String, override: Bool) -> String {
        """
        \(fullDefinition(mockTypeName, override: override)) {
        """
        if override {
            """
                guard !autoForwardingEnabled else {
                    return \(callAttributes)super.\(callName)(\(forwardedLabeledParameters))
                }
            """
        }
        if parameters.isEmpty {
            """
                let perform = _perform(Methods.\(methodIdentifier)) as! \(closureDefinition(mockTypeName, forwarding: override))
                return \(callAttributes)perform(\(forwardedParameters(callToSuper: override)))
            }
            """
        } else {
            """
                let perform = _perform(
                    Methods.\(methodIdentifier),
                    [\(recordedParameters())]
                ) as! \(closureDefinition(mockTypeName, forwarding: override))
                return \(callAttributes)perform(\(forwardedParameters(callToSuper: override)))
            }
            """
        }
    }

    var expectationAttributes: [String] {
        attributes.filter { $0.key != "objc" }.values.flatMap(\.self).map(\.description)
    }
}

extension Syntax.Method.Parameter {
    var definitionName: String {
        if let label = argumentLabel, label == name {
            return label
        }

        return "\(argumentLabel ?? "_") \(name)"
    }

    var isEscapingClosure: Bool {
        isClosure && !isOptional
    }

    func implementationDefinition(_ mockTypeName: String) -> String {
        "\(definitionName): \(isEscapingClosure ? "@escaping " : "")\(typeName.fixedName.replacingOccurrences(of: "Self", with: mockTypeName))"
    }

    var implementationDefinition: String {
        "\(definitionName): \(isEscapingClosure ? "@escaping " : "")\(typeName.name)"
    }

    func expectationConstructorDefinition(_ mockTypeName: String) -> String {
        let typeName = typeName.nameWithoutAttributes
            .replacingOccurrences(of: "!", with: "?") // Convert implicit optionals
            .replacingOccurrences(of: "Self", with: mockTypeName)
            .replacingOccurrences(of: "inout ", with: "")
        return "\(definitionName): Parameter<\(typeName)>"
    }

    var argumentTypePart: String {
        typeName.escapedIdentifierName()
    }

    var forwardedString: String {
        "\(`inout` ? "&" : "")\(forwardedName)"
    }

    var forwardedName: String {
        keywords.contains(name) ? name.backticked : name
    }

    func description(at index: Int) -> String {
        let value = typeName.name == "String"
            ? "\\\"\\($0[\(index)]!)\\\""
            : "\\($0[\(index)] ?? \"nil\")"

        let label = argumentLabel == "_" ? nil : argumentLabel
        return "\(label.map { "\($0): " } ?? "")\(value)"
    }
}

let keywords = [
    "internal"
]

extension Syntax.TypeInfo {
    func genericParameters(_ associatedTypes: [Syntax.AssociatedType]) -> String {
        if associatedTypes.isEmpty {
            return ""
        }
        let conformanceConstraints = conformanceConstraints
        let parameters = associatedTypes
            .map {
                let conformances = [
                    $0.typeName?.name,
                    conformanceConstraints[$0.name]
                ]
                    .compactMap(\.self)
                    .joined(separator: " & ")

                return "\($0.name)\(conformances.isEmpty ? "" : ": \(conformances)")"
            }
        return "<\(parameters.joined(separator: ", "))>"
    }

    var conformanceConstraints: [String: String] {
        genericRequirements
            .filter {
                $0.relationshipSyntax == ":"
            }
            .reduce(into: [:]) { partialResult, requirement in
                partialResult[requirement.leftType.name] = requirement.rightType.typeName.name
            }
    }
}

extension Syntax.TypeInfo {
    var mockAccessLevel: String {
        accessLevel.rawValue.replacingOccurrences(of: "open", with: "public")
            .trimmingCharacters(in: .whitespaces)
    }

    var mockClassAccessLevel: String {
        accessLevel.rawValue.contains("public") ? "open" : accessLevel.rawValue
    }
}

extension Syntax.TypeName {
    var actualTypeNameExceptSelf: Syntax.TypeName {
        name == "Self" ? self : actualTypeName ?? self
    }

    func name(convertingImplicitOptional: Bool) -> String {
        let baseName = convertingImplicitOptional && isImplicitlyUnwrappedOptional ? unwrappedTypeName + "?" : fixedName
        // Normalize module-qualified standard library types
        return baseName
            .replacingOccurrences(of: "Swift.Int", with: "Int")
            .replacingOccurrences(of: "Swift.String", with: "String")
            .replacingOccurrences(of: "Swift.Bool", with: "Bool")
            .replacingOccurrences(of: "Swift.Double", with: "Double")
            .replacingOccurrences(of: "Swift.Float", with: "Float")
            .replacingOccurrences(of: "Swift.Array", with: "Array")
            .replacingOccurrences(of: "Swift.Dictionary", with: "Dictionary")
            .replacingOccurrences(of: "Swift.Set", with: "Set")
            .replacingOccurrences(of: "Swift.Optional", with: "Optional")
    }

    func actualName(convertingImplicitOptional: Bool) -> String {
        (actualTypeName ?? self).name(convertingImplicitOptional: convertingImplicitOptional)
    }

    func escapedIdentifierName() -> String {
        name
            .replacingOccurrences(of: "->", with: "_ret_")
            .replacingOccurrences(of: "@", with: "_at_")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "<", with: "_lab_")
            .replacingOccurrences(of: ">", with: "_rab_")
            .replacingOccurrences(of: "[", with: "_lsb_")
            .replacingOccurrences(of: "]", with: "_rsb_")
            .replacingOccurrences(of: "(", with: "_lp_")
            .replacingOccurrences(of: ")", with: "_rp_")
            .replacingOccurrences(of: ":", with: "_col_")
            .replacingOccurrences(of: "?", with: "_opt_")
            .replacingOccurrences(of: "!", with: "_impopt_")
            .replacingOccurrences(of: ".", with: "_")
            .replacingOccurrences(of: ",", with: "_")
            .replacingOccurrences(of: "==", with: "_eq_")
    }

    var fixedName: String {
        if isOptional, let term = unwrappedTypeName.hasPrefix("any ") ? unwrappedTypeName : closure?.asFixedSource {
            "(\((attributes.flatMap(\.value).map(\.asSource).sorted() + [term]).joined(separator: " ")))?"
        } else {
            closure?.asFixedSource ?? name
        }
    }
}

private func sanitizedIdentifierComponent(from typeName: String) -> String {
    Syntax.TypeName.parse(typeName).escapedIdentifierName()
}

private func sanitizeFunctionType(_ functionType: String) -> String {
    var sanitized = functionType.replacingOccurrences(of: "@escaping", with: "")
    while sanitized.contains("  ") {
        sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
    }
    sanitized = sanitized
        .replacingOccurrences(of: "( ", with: "(")
        .replacingOccurrences(of: " )", with: ")")
        .replacingOccurrences(of: " ,", with: ",")
    return sanitized.trimmingCharacters(in: .whitespaces)
}

extension Syntax.Property {
    var definedInExtension: Bool {
        definedInType?.isExtension ?? false
    }

    var getterAccessLevel: String {
        readAccess.replacingOccurrences(of: "open", with: "public")
    }

    var setterAccessLevel: String {
        writeAccess.replacingOccurrences(of: "open", with: "public")
    }

    var implementationAccessLevel: String {
        getterAccessLevel + (isReadOnly || setterAccessLevel.isEmpty || setterAccessLevel == getterAccessLevel
            ? ""
            : " \(setterAccessLevel)(set)")
    }

    var implementationAttributes: [String] {
        attributes.values.flatMap(\.self)
            .filter {
                $0.name != "NSCopying"
            }
            .map(\.description)
    }

    func fullDefinition(override: Bool, indentation: String) -> String {
        (implementationAttributes +
            ["\(implementationAccessLevel)\(override ? " override" : "") var \(name): \(typeName.fixedName)"])
            .joined(separator: "\n" + indentation)
    }

    var unbacktickedName: String {
        name.replacingOccurrences(of: "`", with: "")
    }

    var getterIdentifier: String {
        "\(unbacktickedName)_\(isAsync ? "async" : "sync")_ret_\(returnTypePart)"
    }

    var setterIdentifier: String {
        "set_\(unbacktickedName)_\(isAsync ? "async" : "sync")_ret_\(returnTypePart)"
    }

    var returnTypePart: String {
        typeName.escapedIdentifierName()
    }

    func getterPerformDefinition(forwarding: Bool, _ namespacedTypes: [String: String] = [:]) -> String {
        let parameters = forwarding ? ["_ forwardToOriginal: " + getterPerformDefinition(forwarding: false, namespacedTypes)] : []
        let returnType = typeName.actualName(convertingImplicitOptional: true)
        return "(\(parameters.joined(separator: ", "))) \(getterSpecifiers)-> \(namespacedTypes[returnType, default: returnType])"
    }

    func setterPerformDefinition(forwarding: Bool, _ namespacedTypes: [String: String] = [:]) -> String {
        let type = typeName.actualName(convertingImplicitOptional: true)
        let parameters = (forwarding ? ["_ forwardToOriginal: " + setterPerformDefinition(forwarding: false, namespacedTypes)] : [])
            + ["_ newValue: \(namespacedTypes[type, default: type])"]
        return "(\(parameters.joined(separator: ", "))) -> Void"
    }

    @ArrayBuilder<String>
    var definitions: [String] {
        getterDefinition
        if !isReadOnly {
            setterDefinition
        }
    }

    var getterDefinition: String {
        """
        static var \(getterIdentifier): MockMethod {
            .init { _ in
                \"\(name)\"
            }
        }
        """
    }

    var setterDefinition: String {
        """
        static var \(setterIdentifier): MockMethod {
            .init {
                \"\(name) = \\($0[0] ?? "nil")\"
            }
        }
        """
    }

    var isReadOnly: Bool {
        writeAccess.isEmpty || writeAccess == "private"
    }

    @ArrayBuilder<String>
    var getterSpecifiersArray: [String] {
        if isAsync {
            "async"
        }
        if `throws` {
            "throws"
        }
        ""
    }

    var getterSpecifiers: String {
        getterSpecifiersArray.joined(separator: " ")
    }

    @ArrayBuilder<String>
    var callAttributesArray: [String] {
        if `throws` {
            "try"
        }
        if isAsync {
            "await"
        }
        ""
    }

    var callAttributes: String {
        callAttributesArray.joined(separator: " ")
    }

    @StringBuilder
    func implementation(override: Bool) -> String {
        """
        \(fullDefinition(override: override, indentation: "    ")) {
        """
        "    get \(getterSpecifiers){"
        getter(override: override)
            .indented(2)
        "    }"
        if !isReadOnly {
            "    set {"
            setter(override: override)
                .indented(2)
            "    }"
        }
        """
        }
        """
    }

    @StringBuilder
    func getter(override: Bool) -> String {
        if override {
            """
            guard !autoForwardingEnabled else {
                return super.\(name)
            }
            """
        }
        """
        let perform = _perform(Methods.\(getterIdentifier)) as! \(getterPerformDefinition(forwarding: override))
        return \(callAttributes)perform(\(override ? "{ super.\(name) }" : ""))
        """
    }

    @StringBuilder
    func setter(override: Bool) -> String {
        if override {
            """
            guard !autoForwardingEnabled else {
                super.\(name) = newValue
                return
            }
            """
        }

        """
        let perform = _perform(
            Methods.\(setterIdentifier),
            [newValue]
        ) as! \(setterPerformDefinition(forwarding: override))
        return perform(\(override ? "{ super.\(name) = $0 }, " : "")newValue)
        """
    }

    @ArrayBuilder<String>
    func expectationExtensions(
        _ mockAccessLevel: String,
        _ mockTypeName: String,
        _ namespacedTypes: [String: String],
        forwarding: Bool
    ) -> [String] {
        """
        \(mockAccessLevel.replacingOccurrences(of: "open", with: "public")) \
        extension \(mockTypeName).PropertyExpectation where Signature == \(getterPerformDefinition(forwarding: false, namespacedTypes)) {
            static var \(name): Self {
                .init(method: \(mockTypeName).Methods.\(getterIdentifier))
            }
        }
        """

        if !isReadOnly {
            """
            \(mockAccessLevel.replacingOccurrences(of: "open", with: "public")) \
            extension \(mockTypeName).PropertyExpectation where Signature == \(setterPerformDefinition(forwarding: false, namespacedTypes)) {
                static var \(name): Self {
                    .init(method: \(mockTypeName).Methods.\(setterIdentifier))
                }
            }
            """
        }
    }
}

extension Syntax.Subscript {
    var getterIdentifier: String {
        "subscript_get_by_\(parametersPart)_\(returnTypePart)"
    }

    var setterIdentifier: String {
        "subscript_set_by_\(parametersPart)_\(returnTypePart)"
    }

    var parametersPart: String {
        parameters.map {
            "\($0.argumentLabel?.trimmedBackticks ?? "")_\($0.name.trimmedBackticks)_\($0.argumentTypePart)"
        }
        .joined(separator: "_")
    }

    var getterSignature: String {
        getterPerformDefinition()
    }

    var setterSignature: String? {
        isReadOnly ? nil : setterPerformDefinition
    }

    @ArrayBuilder<String>
    var definitions: [String] {
        getterDefinition
        if !isReadOnly {
            setterDefinition
        }
    }

    var getterDefinition: String {
        """
        static var \(getterIdentifier): MockMethod {
            .init {\(parameters.isEmpty ? " _ in" : "")
                \"[\(parameters.enumerated().map { $0.element.description(at: $0.offset) }.joined(separator: ", "))]\"
            }
        }
        """
    }

    var setterDefinition: String {
        """
        static var \(setterIdentifier): MockMethod {
            .init {
                \"[\(parameters.enumerated().map { $0.element.description(at: $0.offset) }.joined(separator: ", "))] = \\($0.last! ?? "nil")\"
            }
        }
        """
    }

    var returnTypePart: String {
        returnTypeName.escapedIdentifierName()
    }

    var isReadOnly: Bool {
        writeAccess.isEmpty || writeAccess == "private"
    }

    var getterAccessLevel: String {
        readAccess.replacingOccurrences(of: "open", with: "public")
    }

    var setterAccessLevel: String {
        writeAccess.replacingOccurrences(of: "open", with: "public")
    }

    var implementationAccessLevel: String {
        getterAccessLevel + (isReadOnly || setterAccessLevel.isEmpty || setterAccessLevel == getterAccessLevel
            ? ""
            : " \(setterAccessLevel)(set)")
    }

    var implementationAttributes: [String] {
        attributes.values.flatMap(\.self)
            .filter {
                $0.name != "NSCopying"
            }
            .map(\.description)
    }

    func fullDefinition(indentation: String) -> String {
        (implementationAttributes +
            ["\(implementationAccessLevel) subscript(\(parametersDefinition)) -> \(returnTypeName.fixedName)"])
            .joined(separator: "\n" + indentation)
    }

    var parametersDefinition: String {
        parameters.map(\.implementationDefinition).joined(separator: ", ")
    }

    @StringBuilder
    var implementation: String {
        """
        \(fullDefinition(indentation: "    ")) {
        """
        if isReadOnly {
            getter.indented(1)
        } else {
            "    get {"
            getter.indented(2)
            "    }"
            "    set {"
            setter.indented(2)
            "    }"
        }
        """
        }
        """
    }

    var getter: String {
        """
        let perform = _perform(
            Methods.\(getterIdentifier),
            [\(recordedParameters)]
        ) as! \(getterPerformDefinition())
        return perform(\(forwardedParameters))
        """
    }

    var setter: String {
        """
        let perform = _perform(
            Methods.\(setterIdentifier),
            [\(recordedParameters), newValue]
        ) as! \(setterPerformDefinition)
        return perform(\(forwardedParameters), newValue)
        """
    }

    var forwardedParameters: String {
        parameters.map(\.forwardedString)
            .joined(separator: ", ")
    }

    var recordedParameters: String {
        parameters.map(\.forwardedName)
            .joined(separator: ", ")
    }

    func parameterDefinitions(named: Bool) -> [String] {
        parameters.map {
            (named ? "\($0.name): " : "")
                + $0.typeName.name(convertingImplicitOptional: true)
                .replacingOccurrences(of: "some ", with: "any ")
        }
    }

    func postParametersDefinition(inClosure: Bool) -> String {
        let returnType = returnTypeName.name(convertingImplicitOptional: inClosure)
            .components(separatedBy: "where")[0]
            .trimmed

        return "-> \(returnType)"
    }

    func getterPerformDefinition(namedParameters: Bool = true) -> String {
        let parameters = parameterDefinitions(named: namedParameters).map { "_ \($0)" }
        return "(\(parameters.joined(separator: ", "))) \(postParametersDefinition(inClosure: true))"
    }

    var setterPerformDefinition: String {
        let type = returnTypeName.actualName(convertingImplicitOptional: true)
        let parameters = parameterDefinitions(named: false) + ["_ newValue: \(type)"]
        return "(\(parameters.joined(separator: ", "))) -> Void"
    }

    func expectationDefinitionParameters(_ mockTypeName: String) -> String {
        parameters.map {
            $0.expectationConstructorDefinition(mockTypeName)
        }
        .joined(separator: ", ")
    }

    @StringBuilder
    func expectationConstructor(_ mockTypeName: String) -> String {
        """
        \(implementationAccessLevel) subscript(\(expectationDefinitionParameters(mockTypeName))) -> \(mockTypeName).SubscriptExpectation<\(getterSignature)> {
            .init(
                method: Methods.\(getterIdentifier),
                parameters: [\(parameters.map { "\($0.forwardedName).anyParameter" }.joined(separator: ", "))]
            )
        }
        """
        if let setterSignature {
            """

            \(implementationAccessLevel) subscript(\(expectationDefinitionParameters(mockTypeName))) -> \(mockTypeName).SubscriptExpectation<\(setterSignature)> {
                .init(
                    method: Methods.\(setterIdentifier),
                    parameters: [\(parameters.map { "\($0.forwardedName).anyParameter" }.joined(separator: ", "))]
                )
            }
            """
        }
    }

    var defaultSetterPerformClosure: String {
        " = { \(parameterPlaceholders), _ in  }"
    }

    var parameterPlaceholders: String {
        " \(parameters.map { _ in "_" }.joined(separator: ", "))"
    }

    var mockExpectGetter: String {
        """
            public func expect(
                _ expectation: SubscriptExpectation<\(getterSignature)>,
                file: StaticString = #filePath,
                line: UInt = #line,
                perform: @escaping \(getterPerformDefinition())
            ) {
                _record(
                    expectation.getterExpectation,
                    fileID,
                    filePath, 
                    line,
                    column,
                    perform
                )
            }
        """
    }

    var mockExpectSetter: String {
        guard let setterSignature else {
            return ""
        }
        return """
            public func expect(
                set expectation: SubscriptExpectation<\(setterSignature)>,
                to newValue: Parameter<\(returnTypeName.name(convertingImplicitOptional: true))>,
                file: StaticString = #filePath,
                line: UInt = #line,
                perform: @escaping \(setterPerformDefinition)\(defaultSetterPerformClosure)
            ) {
                _record(
                    expectation.setterExpectation(newValue.anyParameter),
                    fileID,
                    filePath, 
                    line,
                    column,
                    perform
                )
            }
        """
    }
}

extension Syntax.TypeInfo {
    var refinedAssociatedTypes: [String: String] {
        guard kind == .protocol else {
            return [:]
        }
        return genericRequirements
            .filter { $0.relationshipSyntax == "==" }
            .reduce(into: [:]) { partialResult, requirement in
                let left = requirement.leftType.name
                let right = requirement.rightType.typeName.name

                if !left.contains(".") {
                    partialResult[left] = right
                }
                if !right.contains(".") {
                    partialResult[right] = left
                }
            }
    }
}

extension String {
    func indented(_ level: Int, width: Int = 4) -> Self {
        components(separatedBy: "\n")
            .map { String(repeating: " ", count: level * width) + $0 }
            .joined(separator: "\n")
    }

    var trimmedBackticks: Self {
        trimmingCharacters(in: .init(charactersIn: "`"))
    }

    var backticked: Self {
        "`\(self)`"
    }

    var trimmed: Self {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var unquoted: Self {
        trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
    }
}

extension Sequence<String> {
    func indented(_ level: Int, width: Int = 4) -> [String] {
        map {
            $0.indented(level, width: width)
        }
    }
}
