import Foundation
import SyntaxParser

struct MockedProperty {
    let property: Syntax.Property
    let mockTypeName: String?
    let namespacedTypes: [String: String]

    init(_ property: Syntax.Property, mockTypeName: String? = nil, namespacedTypes: [String: String] = [:]) {
        self.property = property
        self.mockTypeName = mockTypeName
        self.namespacedTypes = namespacedTypes
    }

    var definedInExtension: Bool {
        property.definedInType?.isExtension ?? false
    }

    var getterAccessLevel: String {
        property.readAccess.replacingOccurrences(of: "open", with: "public")
    }

    var setterAccessLevel: String {
        property.writeAccess.replacingOccurrences(of: "open", with: "public")
    }

    var implementationAccessLevel: String {
        getterAccessLevel + (isReadOnly || setterAccessLevel.isEmpty || setterAccessLevel == getterAccessLevel
            ? ""
            : " \(setterAccessLevel)(set)")
    }

    var implementationAttributes: [String] {
        property.attributes.values.flatMap(\.self)
            .filter {
                $0.name != "NSCopying"
            }
            .map(\.description)
    }

    func fullDefinition(override: Bool, indentation: String) -> String {
        (implementationAttributes +
            ["\(implementationAccessLevel)\(override ? " override" : "") var \(property.name): \(property.typeName.fixedName)"])
            .joined(separator: "\n" + indentation)
    }

    var unbacktickedName: String {
        property.name.replacingOccurrences(of: "`", with: "")
    }

    var getterIdentifier: String {
        "\(unbacktickedName)_\(property.isAsync ? "async" : "sync")_ret_\(returnTypePart)"
    }

    var setterIdentifier: String {
        "set_\(unbacktickedName)_\(property.isAsync ? "async" : "sync")_ret_\(returnTypePart)"
    }

    var returnTypePart: String {
        MockedTypeName(property.typeName).escapedIdentifierName()
    }

    func getterPerformDefinition(forwarding: Bool) -> String {
        let parameters = forwarding ? ["_ forwardToOriginal: " + getterPerformDefinition(forwarding: false)] : []
        let returnType = MockedTypeName(property.typeName).actualName(convertingImplicitOptional: true)
        return "(\(parameters.joined(separator: ", "))) \(getterSpecifiers)-> \(namespacedTypes[returnType, default: returnType])"
    }

    func setterPerformDefinition(forwarding: Bool) -> String {
        let type = MockedTypeName(property.typeName).actualName(convertingImplicitOptional: true)
        let parameters = (forwarding ? ["_ forwardToOriginal: " + setterPerformDefinition(forwarding: false)] : [])
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
                \"\(property.name)\"
            }
        }
        """
    }

    var setterDefinition: String {
        """
        static var \(setterIdentifier): MockMethod {
            .init {
                \"\(property.name) = \\($0[0] ?? "nil")\"
            }
        }
        """
    }

    var isReadOnly: Bool {
        property.writeAccess.isEmpty || property.writeAccess == "private"
    }

    @ArrayBuilder<String>
    var getterSpecifiersArray: [String] {
        if property.isAsync {
            "async"
        }
        if property.throws {
            "throws"
        }
        ""
    }

    var getterSpecifiers: String {
        getterSpecifiersArray.joined(separator: " ")
    }

    @ArrayBuilder<String>
    var callAttributesArray: [String] {
        if property.throws {
            "try"
        }
        if property.isAsync {
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
                return super.\(property.name)
            }
            """
        }
        """
        let perform = _perform(Methods.\(getterIdentifier)) as! \(getterPerformDefinition(forwarding: override))
        return \(callAttributes)perform(\(override ? "{ super.\(property.name) }" : ""))
        """
    }

    @StringBuilder
    func setter(override: Bool) -> String {
        if override {
            """
            guard !autoForwardingEnabled else {
                super.\(property.name) = newValue
                return
            }
            """
        }

        """
        let perform = _perform(
            Methods.\(setterIdentifier),
            [newValue]
        ) as! \(setterPerformDefinition(forwarding: override))
        return perform(\(override ? "{ super.\(property.name) = $0 }, " : "")newValue)
        """
    }

    func expectationExtensions(
        _ mockAccessLevel: String
    ) -> [String] {
        guard let mockTypeName else {
            return []
        }

        var result = [
            """
            \(mockAccessLevel.replacingOccurrences(of: "open", with: "public")) \
            extension \(mockTypeName).PropertyExpectation where Signature == \(getterPerformDefinition(forwarding: false)) {
                static var \(property.name): Self {
                    .init(method: \(mockTypeName).Methods.\(getterIdentifier))
                }
            }
            """
        ]

        if !isReadOnly {
            result.append(
                """
                \(mockAccessLevel.replacingOccurrences(of: "open", with: "public")) \
                extension \(mockTypeName).PropertyExpectation where Signature == \(setterPerformDefinition(forwarding: false)) {
                    static var \(property.name): Self {
                        .init(method: \(mockTypeName).Methods.\(setterIdentifier))
                    }
                }
                """
            )
        }

        return result
    }
}
