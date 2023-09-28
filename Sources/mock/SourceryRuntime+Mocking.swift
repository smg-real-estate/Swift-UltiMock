import SourceryRuntime
import XFoundation

func additionalImports(_ arguments: [String: Any]) -> [String] {
    arguments["import"]
        .flatMap { $0 as? [String] }
        .map { imports in
            imports.map { "import \($0)" }
        } ?? []
}

extension SourceryRuntime.Method {
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
                + $0.typeName.name(convertingImplicitOptional: true)
                .replacingOccurrences(of: "Self", with: mockTypeName)
                .replacingOccurrences(of: "some ", with: "any ")
        }
    }

    var whereConstraints: String? {
        let components = returnTypeName.name
            .components(separatedBy: "where")

        guard components.count == 2 else {
            return nil
        }
        return components[1].trimmed
    }

    func postParametersDefinition(_ selfSubstitute: String? = nil, inClosure: Bool) -> String {
        var returnType = returnTypeName.name(convertingImplicitOptional: inClosure)
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
            forwarding: false)] : []
        )
            + parameterDefinitions(named: namedParameters, mockTypeName).map { "_ \($0)" }
        return "(\(parameters.joined(separator: ", "))) \(postParametersDefinition(substituteReturnSelf ? mockTypeName : nil, inClosure: true))"
    }

    func signature(namedParameters: Bool = true, _ mockTypeName: String, substituteReturnSelf: Bool = false) -> String {
        closureDefinition(namedParameters: namedParameters, mockTypeName, substituteReturnSelf, forwarding: false)
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
        "\(unbacktickedCallName)_\(isAsync ? "async" : "sync")\(parametersPart)_ret_\(returnTypePart)"
    }

    var genericTypeNames: [String] {
        guard let genericClauseIndex = shortName.firstIndex(of: "<") else {
            return []
        }

        return shortName.suffix(from: genericClauseIndex)
            .trimmingCharacters(in: ["<", ">"])
            .components(separatedBy: ",")
            .map {
                $0.components(separatedBy: ":")[0].trimmed
            }
    }

    var genericClause: String {
        guard let genericClauseIndex = shortName.firstIndex(of: "<") else {
            return ""
        }

        return String(shortName.suffix(from: genericClauseIndex))
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
            return ""
        } else {
            return " \(parameters.map { _ in "_" }.joined(separator: ", ")) in "
        }
    }

    func performClosureParameters(prepending: [String]) -> String {
        let parameters = prepending + parameters.map(\.name)
        return parameters.isEmpty ? "" : " \(parameters.joined(separator: ", ")) in"
    }

    var invocationDescription: String {
        if parameters.isEmpty {
            return selectorName
        } else {
            return "\(callName)(\(parameters.map { "\($0.argumentLabel.map { $0 + ": " } ?? "")\\(\($0.name))" }.joined(separator: ", ")))"
        }
    }

    func expectationDefinitionParameters(_ mockTypeName: String) -> String {
        parameters.map {
            $0.expectationConstructorDefinition(mockTypeName)
        }
        .joined(separator: ", ")
    }

    func expectationConstructor(_ mockTypeName: String, forwarding: Bool) -> String {
        (
            attributes.values.flatMap { $0 }.map(\.description) +
                [
                    """
                    \(implementationAccessLevel) static func \(shortName)(\(expectationDefinitionParameters(mockTypeName))) -> Self
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
        (
            attributes.values.flatMap { $0 }.map(\.description) +
                [
                    """
                        \(implementationAccessLevel) func expect\(genericClause)(
                            _ expectation: MethodExpectation<\(signature(mockTypeName, substituteReturnSelf: true))>,
                            file: StaticString = #filePath,
                            line: UInt = #line,
                            perform: @escaping \(closureDefinition(mockTypeName, true, forwarding: forwarding))\(defaultPerformClosure(forwarding: forwarding))
                        ) {
                            _record(expectation.expectation, file, line, perform)
                        }
                    """
                ]
        ).joined(separator: "\n")
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
            attributes.values.flatMap { $0 }.map(\.description) +
                [
                    "\(implementationAccessLevel)\(override ? " override" : "") func \(shortName)("
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
        forwardedParameters(prepending: callToSuper ? ["super.\(selectorName)"] : [])
    }

    var forwardedLabeledParameters: String {
        if parameters.isEmpty {
            return ""
        } else {
            return "\(parameters.map { "\($0.argumentLabel.map { $0 + ": " } ?? "")\($0.name)" }.joined(separator: ", "))"
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

    @ArrayBuilder<String>
    func implementation(_ mockTypeName: String, override: Bool) -> [String] {
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
}

extension MethodParameter {
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
        "\(definitionName): \(isEscapingClosure ? "@escaping " : "")\(typeName.name.replacingOccurrences(of: "Self", with: mockTypeName))"
    }

    func expectationConstructorDefinition(_ mockTypeName: String) -> String {
        let typeName = typeName.name(convertingImplicitOptional: true)
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

        return "\(argumentLabel.map { "\($0): " } ?? "")\(value)"
    }
}

let keywords = [
    "internal"
]

extension SourceryRuntime.`Protocol` {
    var genericParameters: String {
        if associatedTypes.isEmpty {
            return ""
        }
        let parameters = associatedTypes.values
            .sorted { $0.name < $1.name }
            .map {
                "\($0.name)\($0.typeName.map { ": " + $0.name } ?? "")"
            }
        return "<\(parameters.joined(separator: ", "))>"
    }

    var equatableAssociatedTypes: [String] {
        associatedTypes.values.filter {
            $0.typeName?.name == "Equatable"
        }
        .map(\.name)
    }
}

extension SourceryRuntime.`Type` {
    var mockAccessLevel: String {
        accessLevel.replacingOccurrences(of: "open", with: "public")
            .trimmingCharacters(in: .whitespaces)
    }

    var mockClassAccessLevel: String {
        accessLevel.contains("public") ? "open" : accessLevel
    }
}

extension SourceryRuntime.TypeName {
    func name(convertingImplicitOptional: Bool) -> String {
        convertingImplicitOptional && isImplicitlyUnwrappedOptional ? unwrappedTypeName + "?" : name
    }

    func actualName(convertingImplicitOptional: Bool) -> String {
        (actualTypeName ?? self).name(convertingImplicitOptional: convertingImplicitOptional)
    }

    func escapedIdentifierName() -> String {
        name
            .replacingOccurrences(of: "->", with: "_ret_")
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
}

extension Variable {
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
        attributes.values.flatMap { $0 }
            .filter {
                $0.name != "NSCopying"
            }
            .map(\.description)
    }

    func fullDefinition(override: Bool, indentation: String) -> String {
        (implementationAttributes +
            ["\(implementationAccessLevel)\(override ? " override" : "") var \(name): \(typeName)"])
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

    var getterSignature: String {
        getterPerformDefinition(forwarding: false)
    }

    var setterSignature: String? {
        setterPerformDefinition(forwarding: false)
    }

    func getterPerformDefinition(forwarding: Bool) -> String {
        let parameters = forwarding ? ["_ forwardToOriginal: " + getterPerformDefinition(forwarding: false)] : []
        return "(\(parameters.joined(separator: ", "))) -> \(typeName.actualName(convertingImplicitOptional: true))"
    }

    func setterPerformDefinition(forwarding: Bool) -> String {
        let parameters = (forwarding ? ["_ forwardToOriginal: " + setterPerformDefinition(forwarding: false)] : [])
            + ["_ newValue: \(typeName.actualName(convertingImplicitOptional: true))"]
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

    func defaultGetterPerformClosure(forwarding: Bool) -> String {
        forwarding ? " = { $0() }" : ""
    }

    func defaultSetterPerformClosure(forwarding: Bool) -> String {
        forwarding ? " = { $0($1) }" : " = { _ in }"
    }

    var isReadOnly: Bool {
        writeAccess.isEmpty || writeAccess == "private"
    }

    @ArrayBuilder<String>
    func implementation(override: Bool) -> [String] {
        """
        \(fullDefinition(override: override, indentation: "    ")) {
        """
        if isReadOnly {
            getter(override: override)
                .indented(1)
        } else {
            "    get {"
            getter(override: override)
                .indented(2)
            "    }"
            "    set {"
            setter(override: override)
                .indented(2)
            "    }"
        }
        """
        }
        """
    }

    @ArrayBuilder<String>
    func getter(override: Bool) -> [String] {
        if override {
            """
            guard !autoForwardingEnabled else {
                return super.\(name)
            }
            """
        }
        """
        let perform = _perform(Methods.\(getterIdentifier)) as! \(getterPerformDefinition(forwarding: override))
        return perform(\(override ? "{ super.\(name) }" : ""))
        """
    }

    @ArrayBuilder<String>
    func setter(override: Bool) -> [String] {
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
    func expectationExtensions(_ mockAccessLevel: String, _ mockTypeName: String, forwarding: Bool) -> [String] {
        """
        \(mockAccessLevel.replacingOccurrences(of: "open", with: "public")) \
        extension \(mockTypeName).PropertyExpectation where Signature == \(getterPerformDefinition(forwarding: false)) {
            static var \(name): Self {
                .init(method: \(mockTypeName).Methods.\(getterIdentifier))
            }
        }
        """

        if !isReadOnly {
            """
            \(mockAccessLevel.replacingOccurrences(of: "open", with: "public")) \
            extension \(mockTypeName).PropertyExpectation where Signature == \(setterPerformDefinition(forwarding: false)) {
                static var \(name): Self {
                    .init(method: \(mockTypeName).Methods.\(setterIdentifier))
                }
            }
            """
        }
    }

    func mockExpectGetter(forwarding: Bool) -> String {
        """
            public func expect(
                _ expectation: PropertyExpectation<\(getterSignature)>,
                file: StaticString = #filePath,
                line: UInt = #line,
                perform: @escaping \(getterPerformDefinition(forwarding: forwarding))\(defaultGetterPerformClosure(forwarding: forwarding))
            ) {
                _record(expectation.getterExpectation, file, line, perform)
            }
        """
    }

    func mockExpectSetter(forwarding: Bool) -> String {
        guard let setterSignature else {
            return ""
        }
        return """
            public func expect(
                set expectation: PropertyExpectation<\(setterSignature)>,
                to newValue: Parameter<\(typeName.name(convertingImplicitOptional: true))>,
                file: StaticString = #filePath,
                line: UInt = #line,
                perform: @escaping \(setterPerformDefinition(forwarding: forwarding))\(defaultSetterPerformClosure(forwarding: forwarding))
            ) {
                _record(expectation.setterExpectation(newValue.anyParameter), file, line, perform)
            }
        """
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
}

extension Sequence<String> {
    func indented(_ level: Int, width: Int = 4) -> [String] {
        map {
            $0.indented(level, width: width)
        }
    }
}
