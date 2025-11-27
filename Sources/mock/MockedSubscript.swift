import Foundation
import SyntaxParser

struct MockedSubscript {
    let subscriptDecl: Syntax.Subscript
    let mockTypeName: String

    init(_ subscriptDecl: Syntax.Subscript, mockTypeName: String) {
        self.subscriptDecl = subscriptDecl
        self.mockTypeName = mockTypeName
    }

    var getterIdentifier: String {
        "subscript_get_by_\(parametersPart)_\(returnTypePart)"
    }

    var setterIdentifier: String {
        "subscript_set_by_\(parametersPart)_\(returnTypePart)"
    }

    var parametersPart: String {
        subscriptDecl.parameters.map {
            "\($0.argumentLabel?.trimmedBackticks ?? "")_\($0.name.trimmedBackticks)_\(MockedMethodParameter($0).argumentTypePart)"
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
            .init {\(subscriptDecl.parameters.isEmpty ? " _ in" : "")
                "[\(subscriptDecl.parameters.enumerated().map { MockedMethodParameter($0.element).description(at: $0.offset) }.joined(separator: ", "))]"
            }
        }
        """
    }

    var setterDefinition: String {
        """
        static var \(setterIdentifier): MockMethod {
            .init {
                "[\(subscriptDecl.parameters.enumerated().map { MockedMethodParameter($0.element).description(at: $0.offset) }.joined(separator: ", "))] = \\($0.last! ?? \"nil\")"
            }
        }
        """
    }

    var returnTypePart: String {
        MockedTypeName(subscriptDecl.returnTypeName).escapedIdentifierName()
    }

    var isReadOnly: Bool {
        subscriptDecl.writeAccess.isEmpty || subscriptDecl.writeAccess == "private"
    }

    var getterAccessLevel: String {
        subscriptDecl.readAccess.replacingOccurrences(of: "open", with: "public")
    }

    var setterAccessLevel: String {
        subscriptDecl.writeAccess.replacingOccurrences(of: "open", with: "public")
    }

    var implementationAccessLevel: String {
        getterAccessLevel + (isReadOnly || setterAccessLevel.isEmpty || setterAccessLevel == getterAccessLevel
            ? ""
            : " \(setterAccessLevel)(set)")
    }

    var implementationAttributes: [String] {
        subscriptDecl.attributes.values.flatMap(\.self)
            .filter {
                $0.name != "NSCopying"
            }
            .map(\.description)
    }

    func fullDefinition(indentation: String) -> String {
        (implementationAttributes +
            ["\(implementationAccessLevel) subscript(\(parametersDefinition)) -> \(subscriptDecl.returnTypeName.fixedName)"])
            .joined(separator: "\n" + indentation)
    }

    var parametersDefinition: String {
        subscriptDecl.parameters.map { MockedMethodParameter($0).implementationDefinition }.joined(separator: ", ")
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
        subscriptDecl.parameters.map { MockedMethodParameter($0).forwardedString }
            .joined(separator: ", ")
    }

    var recordedParameters: String {
        subscriptDecl.parameters.map { MockedMethodParameter($0).forwardedName }
            .joined(separator: ", ")
    }

    func parameterDefinitions(named: Bool) -> [String] {
        subscriptDecl.parameters.map {
            (named ? "\($0.name): " : "")
                + MockedTypeName($0.typeName).name(convertingImplicitOptional: true)
                .replacingOccurrences(of: "some ", with: "any ")
        }
    }

    func postParametersDefinition(inClosure: Bool) -> String {
        let returnType = MockedTypeName(subscriptDecl.returnTypeName).name(convertingImplicitOptional: inClosure)
            .components(separatedBy: "where")[0]
            .trimmed

        return "-> \(returnType)"
    }

    func getterPerformDefinition(namedParameters: Bool = true) -> String {
        let parameters = parameterDefinitions(named: namedParameters).map { "_ \($0)" }
        return "(\(parameters.joined(separator: ", "))) \(postParametersDefinition(inClosure: true))"
    }

    var setterPerformDefinition: String {
        let type = MockedTypeName(subscriptDecl.returnTypeName).actualName(convertingImplicitOptional: true)
        let parameters = parameterDefinitions(named: false) + ["_ newValue: \(type)"]
        return "(\(parameters.joined(separator: ", "))) -> Void"
    }

    func expectationDefinitionParameters() -> String {
        subscriptDecl.parameters.map {
            MockedMethodParameter($0).expectationConstructorDefinition(mockTypeName)
        }
        .joined(separator: ", ")
    }

    @StringBuilder
    func expectationConstructor() -> String {
        """
        \(implementationAccessLevel) subscript(\(expectationDefinitionParameters())) -> \(mockTypeName).SubscriptExpectation<\(getterSignature)> {
            .init(
                method: Methods.\(getterIdentifier),
                parameters: [\(subscriptDecl.parameters.map { "\(MockedMethodParameter($0).forwardedName).anyParameter" }.joined(separator: ", "))]
            )
        }
        """
        if let setterSignature {
            """

            \(implementationAccessLevel) subscript(\(expectationDefinitionParameters())) -> \(mockTypeName).SubscriptExpectation<\(setterSignature)> {
                .init(
                    method: Methods.\(setterIdentifier),
                    parameters: [\(subscriptDecl.parameters.map { "\(MockedMethodParameter($0).forwardedName).anyParameter" }.joined(separator: ", "))]
                )
            }
            """
        }
    }

    var defaultSetterPerformClosure: String {
        " = { \(parameterPlaceholders), _ in  }"
    }

    var parameterPlaceholders: String {
        " \(subscriptDecl.parameters.map { _ in "_" }.joined(separator: ", "))"
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
                to newValue: Parameter<\(MockedTypeName(subscriptDecl.returnTypeName).name(convertingImplicitOptional: true))>,
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
