import Foundation
import UltiMockSwiftSyntaxParser

extension Syntax.TypeInfo {
    var allMethods: [Syntax.Method] {
        methods
    }

    var allVariables: [Syntax.Property] {
        properties
    }

    var allSubscripts: [Syntax.Subscript] {
        subscripts
    }

    var mockAccessLevel: String {
        accessLevel == .open || accessLevel == .public ? "public" : "internal"
    }

    var mockClassAccessLevel: String {
        accessLevel == .open ? "open" : mockAccessLevel
    }

    var basedTypes: [String: String] {
        Dictionary(uniqueKeysWithValues: inheritedTypes.map { ($0, $0) })
    }

    var based: [String: String] {
        basedTypes
    }

    var associatedTypes: [String: Syntax.Typealias] {
        Dictionary(uniqueKeysWithValues: typealiases.map { ($0.name, $0) })
    }

    var refinedAssociatedTypes: [String: String] {
        [:]
    }

    var supertype: Syntax.TypeInfo? {
        nil
    }

    var implements: [String: Syntax.TypeInfo] {
        [:]
    }

    func genericParameters(_ associatedTypesList: [Syntax.Typealias]) -> String {
        guard !associatedTypesList.isEmpty else {
            return ""
        }
        let params = associatedTypesList.map(\.name).joined(separator: ", ")
        return "<\(params)>"
    }
}

extension Syntax.Method {
    var isStatic: Bool {
        annotations["static"] != nil
    }

    var isClass: Bool {
        annotations["class"] != nil
    }

    var definedInExtension: Bool {
        annotations["definedInExtension"] != nil
    }

    var isPrivate: Bool {
        annotations["private"] != nil
    }

    var callName: String {
        name
    }

    var shortName: String {
        name
    }

    var isAsync: Bool {
        annotations["async"] != nil
    }

    var `throws`: Bool {
        annotations["throws"] != nil
    }

    var isInitializer: Bool {
        name.hasPrefix("init")
    }

    var isRequired: Bool {
        annotations["required"] != nil
    }

    var unbacktickedCallName: String {
        callName.replacingOccurrences(of: "`", with: "")
    }

    var actualReturnTypeName: String {
        returnType ?? "Void"
    }

    func parameterDefinitions(named: Bool, _ mockTypeName: String) -> [String] {
        parameters.map {
            (named ? "\($0.name): " : "")
                + ($0.type ?? "")
                .replacingOccurrences(of: "Self", with: mockTypeName)
                .replacingOccurrences(of: "some ", with: "any ")
        }
    }

    var whereConstraints: String? {
        let components = (returnType ?? "").components(separatedBy: "where")
        guard components.count == 2 else {
            return nil
        }
        return components[1].trimmingCharacters(in: .whitespaces)
    }

    func postParametersDefinition(_ selfSubstitute: String? = nil, inClosure: Bool) -> String {
        var returnTypeStr = (returnType ?? "Void")
            .components(separatedBy: "where")[0]
            .trimmingCharacters(in: .whitespaces)

        if let selfSubstitute {
            returnTypeStr = returnTypeStr.replacingOccurrences(of: "Self", with: selfSubstitute)
        }
        return "\(isAsync ? "async " : "")\(`throws` ? "throws " : "")-> \(returnTypeStr)"
    }

    func closureDefinition(namedParameters: Bool = true, _ mockTypeName: String, _ substituteReturnSelf: Bool = false, forwarding: Bool) -> String {
        let params = (forwarding ? ["_ forwardToOriginal: " + closureDefinition(mockTypeName, substituteReturnSelf, forwarding: false)] : [])
            + parameterDefinitions(named: namedParameters, mockTypeName).map { "_ \($0)" }
        return "(\(params.joined(separator: ", "))) \(postParametersDefinition(substituteReturnSelf ? mockTypeName : nil, inClosure: true))"
    }

    func signature(namedParameters: Bool = true, _ mockTypeName: String, substituteReturnSelf: Bool = false) -> String {
        closureDefinition(namedParameters: namedParameters, mockTypeName, substituteReturnSelf, forwarding: false)
    }

    var rawSignature: String {
        signature(namedParameters: false, "Self")
    }

    var parametersPart: String {
        parameters.map {
            "\($0.label ?? "")_\($0.name)_\($0.type ?? "")"
        }
        .joined(separator: "_")
    }

    var returnTypePart: String {
        (returnType ?? "Void").replacingOccurrences(of: " ", with: "")
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
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    var definition: String {
        "    case \(methodIdentifier)"
    }

    func expectationConstructor(_ mockTypeName: String, forwarding: Bool) -> String {
        let sig = signature(mockTypeName, substituteReturnSelf: false)
        let params = parameters.map { "AnyParameter(\($0.name))" }.joined(separator: ", ")
        let forwardParam = forwarding ? "_ forwardToOriginal: @escaping \(closureDefinition(mockTypeName, false, forwarding: false)), " : ""

        return """
        \(mockTypeName == "" ? "public" : "public") static func \(name)(\(forwardParam)\(parameters.map { ($0.label.map { "\($0) " } ?? "") + "\($0.name): AnyParameter" }.joined(separator: ", "))) -> MethodExpectation<\(sig)> {
            .init(method: .\(methodIdentifier), parameters: [\(params)])
        }
        """
    }

    func implementation(_ mockTypeName: String, override: Bool) -> String {
        let overrideKw = override ? "override " : ""
        let paramList = parameters.map { ($0.label.map { "\($0) " } ?? "") + "\($0.name): \($0.type ?? "")" }.joined(separator: ", ")
        let performParams = parameters.map(\.name).joined(separator: ", ")
        let asyncKw = isAsync ? "async " : ""
        let throwsKw = `throws` ? "throws " : ""
        let retType = returnType ?? "Void"
        let returnStmt = retType == "Void" ? "" : "return _perform(.\(methodIdentifier), [\(performParams)]) as! \(retType)"

        return """
        \(overrideKw)public func \(name)(\(paramList)) \(asyncKw)\(throwsKw)-> \(retType) {
            \(retType == "Void" ? "_perform(.\(methodIdentifier), [\(performParams)])" : returnStmt)
        }
        """
    }

    func mockExpect(_ mockTypeName: String, forwarding: Bool) -> String {
        let sig = signature(mockTypeName, substituteReturnSelf: false)
        let forwardParam = forwarding ? "forwardToOriginal: @escaping \(closureDefinition(mockTypeName, false, forwarding: false)) = { _ in fatalError() }, " : ""
        let params = parameters.map { "_ \($0.name): AnyParameter" }.joined(separator: ", ")
        let performParam = forwarding ? "forwardToOriginal, " : ""

        return """
        public func expect\(name.capitalized)(\(forwardParam)\(params), fileID: String = #fileID, filePath: StaticString = #filePath, line: UInt = #line, column: Int = #column, perform: @escaping \(sig)) {
            _record(Methods.\(name)(\(performParam)\(parameters.map { "\($0.name)" }.joined(separator: ", "))).expectation, fileID, filePath, line, column, perform)
        }
        """
    }

    var forwardedLabeledParameters: String {
        parameters.map { ($0.label ?? $0.name) + ": " + $0.name }.joined(separator: ", ")
    }
}

extension Syntax.Property {
    var isStatic: Bool {
        annotations["static"] != nil
    }

    var definedInExtension: Bool {
        annotations["definedInExtension"] != nil
    }

    var unbacktickedName: String {
        name.replacingOccurrences(of: "`", with: "")
    }

    var getterSignature: String {
        "getter_\(name)_\(type ?? "")"
    }

    var setterSignature: String {
        "setter_\(name)_\(type ?? "")"
    }

    var definitions: [String] {
        var result = ["    case \(getterSignature)"]
        if isVariable {
            result.append("    case \(setterSignature)")
        }
        return result
    }

    func implementation(override: Bool) -> String {
        let overrideKw = override ? "override " : ""
        let typeStr = type ?? ""
        let varKw = isVariable ? "var" : "let"

        var result = """
        \(overrideKw)public \(varKw) \(name): \(typeStr) {
            get { _perform(.\(getterSignature)) as! \(typeStr) }
        """

        if isVariable {
            result += """

                set { _perform(.\(setterSignature), [newValue]) }
            }
            """
        } else {
            result += "\n}"
        }

        return result
    }

    func mockExpectGetter(forwarding: Bool) -> String {
        let typeStr = type ?? ""
        let forwardParam = forwarding ? "forwardToOriginal: @escaping () -> \(typeStr) = { fatalError() }, " : ""

        return """
        public func expect\(name.capitalized)Getter(\(forwardParam)fileID: String = #fileID, filePath: StaticString = #filePath, line: UInt = #line, column: Int = #column, perform: @escaping () -> \(typeStr)) {
            _record(PropertyExpectation<() -> \(typeStr)>(method: .\(getterSignature)).getterExpectation, fileID, filePath, line, column, perform)
        }
        """
    }

    func mockExpectSetter(forwarding: Bool) -> String {
        guard isVariable else {
            return ""
        }
        let typeStr = type ?? ""
        let forwardParam = forwarding ? "forwardToOriginal: @escaping (\(typeStr)) -> Void = { _ in fatalError() }, " : ""

        return """
        public func expect\(name.capitalized)Setter(\(forwardParam)_ newValue: AnyParameter, fileID: String = #fileID, filePath: StaticString = #filePath, line: UInt = #line, column: Int = #column, perform: @escaping (\(typeStr)) -> Void = { _ in }) {
            _record(PropertyExpectation<(\(typeStr)) -> Void>(method: .\(setterSignature)).setterExpectation(newValue), fileID, filePath, line, column, perform)
        }
        """
    }

    func expectationExtensions(_ accessLevel: String, _ mockTypeName: String, _ namespacedTypes: [String: String], forwarding: Bool) -> [String] {
        []
    }
}

extension Syntax.Subscript {
    var isReadOnly: Bool {
        annotations["readOnly"] != nil
    }

    var getterSignature: String {
        let params = parameters.map { "\($0.name)_\($0.type ?? "")" }.joined(separator: "_")
        return "subscript_getter_\(params)_\(returnType ?? "")"
    }

    var setterSignature: String {
        let params = parameters.map { "\($0.name)_\($0.type ?? "")" }.joined(separator: "_")
        return "subscript_setter_\(params)_\(returnType ?? "")"
    }

    var definitions: [String] {
        var result = ["    case \(getterSignature)"]
        if !isReadOnly {
            result.append("    case \(setterSignature)")
        }
        return result
    }

    func expectationConstructor(_ mockTypeName: String) -> String {
        let params = parameters.map { ($0.label.map { "\($0) " } ?? "") + "\($0.name): AnyParameter" }.joined(separator: ", ")
        let paramNames = parameters.map { "AnyParameter(\($0.name))" }.joined(separator: ", ")
        let sig = "(\(parameters.map { $0.type ?? "" }.joined(separator: ", "))) -> \(returnType ?? "")"

        return """
        public static func `subscript`(\(params)) -> SubscriptExpectation<\(sig)> {
            .init(method: .\(getterSignature), parameters: [\(paramNames)])
        }
        """
    }

    var implementation: String {
        let paramList = parameters.map { ($0.label.map { "\($0) " } ?? "") + "\($0.name): \($0.type ?? "")" }.joined(separator: ", ")
        let performParams = parameters.map(\.name).joined(separator: ", ")
        let retType = returnType ?? ""

        var result = """
        public subscript(\(paramList)) -> \(retType) {
            get { _perform(.\(getterSignature), [\(performParams)]) as! \(retType) }
        """

        if !isReadOnly {
            result += """

                set { _perform(.\(setterSignature), [\(performParams), newValue]) }
            }
            """
        } else {
            result += "\n}"
        }

        return result
    }

    var mockExpectGetter: String {
        let paramList = parameters.map { "_ \($0.name): AnyParameter" }.joined(separator: ", ")
        let retType = returnType ?? ""
        let sig = "(\(parameters.map { $0.type ?? "" }.joined(separator: ", "))) -> \(retType)"

        return """
        public func expectSubscriptGetter(\(paramList), fileID: String = #fileID, filePath: StaticString = #filePath, line: UInt = #line, column: Int = #column, perform: @escaping \(sig)) {
            _record(SubscriptExpectation<\(sig)>.`subscript`(\(parameters.map(\.name).joined(separator: ", "))).getterExpectation, fileID, filePath, line, column, perform)
        }
        """
    }

    var mockExpectSetter: String {
        guard !isReadOnly else {
            return ""
        }
        let paramList = parameters.map { "_ \($0.name): AnyParameter" }.joined(separator: ", ")
        let retType = returnType ?? ""
        let sig = "(\(parameters.map { $0.type ?? "" }.joined(separator: ", ")), \(retType)) -> Void"

        return """
        public func expectSubscriptSetter(\(paramList), _ newValue: AnyParameter, fileID: String = #fileID, filePath: StaticString = #filePath, line: UInt = #line, column: Int = #column, perform: @escaping \(sig) = { _ in }) {
            _record(SubscriptExpectation<\(sig)>.`subscript`(\(parameters.map(\.name).joined(separator: ", "))).setterExpectation(newValue), fileID, filePath, line, column, perform)
        }
        """
    }
}

extension [Syntax.Subscript] {
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>, _ conflictResolver: (Element, Element) -> Element) -> [Element] {
        var seen = [T: Element]()
        for element in self {
            let key = element[keyPath: keyPath]
            if let existing = seen[key] {
                seen[key] = conflictResolver(existing, element)
            } else {
                seen[key] = element
            }
        }
        return Array(seen.values)
    }
}

extension [Syntax.Method] {
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        var result: [Element] = []
        for element in self {
            let key = element[keyPath: keyPath]
            if !seen.contains(key) {
                seen.insert(key)
                result.append(element)
            }
        }
        return result
    }
}

extension [Syntax.Property] {
    func unique<T: Hashable>(by keyPath: KeyPath<Element, T>) -> [Element] {
        var seen = Set<T>()
        var result: [Element] = []
        for element in self {
            let key = element[keyPath: keyPath]
            if !seen.contains(key) {
                seen.insert(key)
                result.append(element)
            }
        }
        return result
    }
}

extension [String] {
    func indented(_ level: Int) -> [String] {
        let indent = String(repeating: "    ", count: level)
        return map { indent + $0 }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }

    func indented(_ level: Int) -> String {
        let indent = String(repeating: "    ", count: level)
        return split(separator: "\n", omittingEmptySubsequences: false)
            .map { indent + $0 }
            .joined(separator: "\n")
    }
}

extension String.SubSequence {
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
