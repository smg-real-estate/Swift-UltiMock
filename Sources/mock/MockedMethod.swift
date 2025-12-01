import Foundation
import SyntaxParser

struct MockedMethod {
    let method: Syntax.Method
    let mockTypeName: String
    let parameters: [MockedMethodParameter]

    init(_ method: Syntax.Method, mockTypeName: String, resolveTypeName: (String, String) -> String) {
        self.method = method
        self.mockTypeName = mockTypeName
        self.parameters = method.parameters.map {
            MockedMethodParameter(parameter: $0, resolvedTypeName: resolveTypeName($0.type, mockTypeName))
        }
    }

    var isPrivate: Bool {
        method.modifiers.contains { $0.name == "private" }
    }

    var implementationAccessLevel: String {
        method.accessLevel.replacingOccurrences(of: "open", with: "public")
    }

    var definedInExtension: Bool {
        method.definedInType?.isExtension ?? false
    }

    func parameterDefinitions(named: Bool) -> [String] {
        method.parameters.map {
            let mockedTypeName = $0.typeName
            let actualTypeName = mockedTypeName.actualTypeNameExceptSelf
            let convertedName = actualTypeName.name(convertingImplicitOptional: true)
            return (named ? "\($0.name): " : "")
                + convertedName
                .replacingOccurrences(of: "Self", with: mockTypeName)
                .replacingOccurrences(of: "some ", with: "any ")
        }
    }

    var whereConstraints: String? {
        if !method.genericRequirements.isEmpty {
            return method.genericRequirements.map { requirement in
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

        let components = method.returnTypeName.name
            .components(separatedBy: "where")

        guard components.count == 2 else {
            return nil
        }
        return components[1].trimmed
    }

    func postParametersDefinition(_ selfSubstitute: String? = nil, inClosure: Bool) -> String {
        let actualTypeName = method.returnTypeName.actualTypeNameExceptSelf
        var returnType = actualTypeName.name(convertingImplicitOptional: inClosure)
            .components(separatedBy: "where")[0]
            .trimmed

        if let selfSubstitute {
            returnType = returnType
                .replacingOccurrences(of: "Self", with: selfSubstitute)
        }
        return "\(method.isAsync ? "async " : "")\(method.throws ? "throws " : "")-> \(returnType)"
    }

    func closureDefinition(namedParameters: Bool = true, _ substituteReturnSelf: Bool = false, forwarding: Bool) -> String {
        let parameters = (forwarding ? ["_ forwardToOriginal: " + closureDefinition(
            namedParameters: namedParameters,
            substituteReturnSelf,
            forwarding: false
        )] : []
        )
            + parameterDefinitions(named: namedParameters).map { "_ \($0)" }
        return "(\(parameters.joined(separator: ", "))) \(postParametersDefinition(substituteReturnSelf ? mockTypeName : nil, inClosure: true))"
    }

    func signature(namedParameters: Bool = true, substituteReturnSelf: Bool = false) -> String {
        sanitizeFunctionType(
            closureDefinition(namedParameters: namedParameters, substituteReturnSelf, forwarding: false)
        )
    }

    var rawSignature: String {
        signature(namedParameters: false, substituteReturnSelf: false)
    }

    var parametersPart: String {
        method.parameters.map {
            "\($0.argumentLabel?.trimmedBackticks ?? "")_\($0.name.trimmedBackticks)_\(MockedMethodParameter($0).argumentTypePart)"
        }
        .joined(separator: "_")
    }

    var unbacktickedCallName: String {
        method.callName.replacingOccurrences(of: "`", with: "")
    }

    var methodIdentifier: String {
        "\(unbacktickedCallName)_\(method.isAsync ? "async" : "sync")\(parametersPart)_ret_\(returnTypePart)\(whereClauseIdentifier)"
    }

    private var whereClauseIdentifier: String {
        guard !method.genericRequirements.isEmpty else {
            return ""
        }

        let components = method.genericRequirements.map { requirement -> String in
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
        guard !method.genericParameters.isEmpty else {
            return ""
        }

        let params = method.genericParameters.map { param in
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
            .init {\(method.parameters.isEmpty ? " _ in" : "")
                "\(method.shortName)(\(method.parameters.enumerated().map { MockedMethodParameter($0.element).description(at: $0.offset) }.joined(separator: ", ")))"
            }
        }
        """
    }

    var parameterPlaceholders: String {
        if method.parameters.isEmpty {
            ""
        } else {
            " \(method.parameters.map { _ in "_" }.joined(separator: ", ")) in "
        }
    }

    func performClosureParameters(prepending: [String]) -> String {
        let parameters = prepending + method.parameters.map(\.name)
        return parameters.isEmpty ? "" : " \(parameters.joined(separator: ", ")) in"
    }

    func expectationDefinitionParameters() -> String {
        method.parameters.map {
            MockedMethodParameter($0).expectationConstructorDefinition(mockTypeName)
        }
        .joined(separator: ", ")
    }

    func expectationConstructor(forwarding: Bool) -> String {
        (
            expectationAttributes +
                [
                    """
                    \(implementationAccessLevel) static func \(method.shortName)\(genericClause)(\(expectationDefinitionParameters())) -> Self
                    where Signature == \(signature(substituteReturnSelf: true))\(whereConstraints.map { ", \($0)" } ?? "") {
                        .init(
                            method: Methods.\(methodIdentifier),
                            parameters: [\(method.parameters.map { "\(MockedMethodParameter($0).forwardedName).anyParameter" }.joined(separator: ", "))]
                        )
                    }
                    """
                ]
        ).joined(separator: "\n")
    }

    func mockExpect(forwarding: Bool) -> String {
        [
            """
                \(method.attributes.filter { !["discardableResult", "objc"].contains($0.key) }.values.flatMap(\.self).map(\.description).joined(separator: "\n"))
                \(implementationAccessLevel) func expect\(genericClause)(
                    _ expectation: MethodExpectation<\(signature(substituteReturnSelf: true))>,
                    fileID: String = #fileID,
                    filePath: StaticString = #filePath,
                    line: UInt = #line,
                    column: Int = #column,
                    perform: @escaping \(closureDefinition(namedParameters: true, true, forwarding: forwarding))\(defaultPerformClosure(forwarding: forwarding))
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
            guard method.returnTypeName.isVoid else {
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

    func fullDefinition(override: Bool) -> String {
        (
            method.attributes.values.flatMap(\.self).map(\.description) +
                [
                    "\(implementationAccessLevel)\(override ? " override" : "") func \(method.shortName)\(genericClause)("
                        + method.parameters.map {
                            MockedMethodParameter($0).implementationDefinition(mockTypeName)
                        }
                        .joined(separator: ", ")
                        + ") \(postParametersDefinition(inClosure: false))"
                ]
        )
        .joined(separator: "\n")
    }

    func forwardedParameters(prepending: [String] = []) -> String {
        (prepending + method.parameters.map { MockedMethodParameter($0).forwardedString })
            .joined(separator: ", ")
    }

    func recordedParameters() -> String {
        method.parameters.map { MockedMethodParameter($0).forwardedName }
            .joined(separator: ", ")
    }

    func forwardedParameters(callToSuper: Bool) -> String {
        forwardedParameters(prepending: callToSuper ? [method.selectorName == "`self`" ? "{ self }" : "super.\(method.selectorName)"] : [])
    }

    var forwardedLabeledParameters: String {
        if method.parameters.isEmpty {
            ""
        } else {
            "\(method.parameters.map { "\($0.argumentLabel.map { $0 + ": " } ?? "")\($0.name)" }.joined(separator: ", "))"
        }
    }

    var returnTypePart: String {
        method.returnTypeName.escapedIdentifierName()
    }

    var callAttributes: String {
        callAttributesArray.joined(separator: " ")
    }

    @ArrayBuilder<String>
    var callAttributesArray: [String] {
        if method.throws {
            "try"
        }
        if method.isAsync {
            "await"
        }
        ""
    }

    @StringBuilder
    func implementation(override: Bool) -> String {
        """
        \(fullDefinition(override: override)) {
        """
        if override {
            """
                guard !autoForwardingEnabled else {
                    return \(callAttributes)super.\(method.callName)(\(forwardedLabeledParameters))
                }
            """
        }
        if method.parameters.isEmpty {
            """
                let perform = _perform(Methods.\(methodIdentifier)) as! \(closureDefinition(forwarding: override))
                return \(callAttributes)perform(\(forwardedParameters(callToSuper: override)))
            }
            """
        } else {
            """
                let perform = _perform(
                    Methods.\(methodIdentifier),
                    [\(recordedParameters())]
                ) as! \(closureDefinition(forwarding: override))
                return \(callAttributes)perform(\(forwardedParameters(callToSuper: override)))
            }
            """
        }
    }

    var expectationAttributes: [String] {
        method.attributes.filter { $0.key != "objc" }.values.flatMap(\.self).map(\.description)
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
