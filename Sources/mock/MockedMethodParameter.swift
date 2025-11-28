import Foundation
import SyntaxParser

struct MockedMethodParameter {
    let parameter: Syntax.Method.Parameter

    init(_ parameter: Syntax.Method.Parameter) {
        self.parameter = parameter
    }

    var definitionName: String {
        if let label = parameter.argumentLabel, label == parameter.name {
            return label
        }

        return "\(parameter.argumentLabel ?? "_") \(parameter.name)"
    }

    var isEscapingClosure: Bool {
        parameter.isClosure && !parameter.isOptional
    }

    func implementationDefinition(_ mockTypeName: String) -> String {
        "\(definitionName): \(isEscapingClosure ? "@escaping " : "")\(parameter.typeName.fixedName.replacingOccurrences(of: "Self", with: mockTypeName))"
    }

    var implementationDefinition: String {
        "\(definitionName): \(isEscapingClosure ? "@escaping " : "")\(parameter.typeName.name)"
    }

    func expectationConstructorDefinition(_ mockTypeName: String) -> String {
        let typeName = parameter.typeName.nameWithoutAttributes
            .replacingOccurrences(of: "!", with: "?")
            .replacingOccurrences(of: "Self", with: mockTypeName)
            .replacingOccurrences(of: "inout ", with: "")
        return "\(definitionName): Parameter<\(typeName)>"
    }

    var argumentTypePart: String {
        parameter.typeName.escapedIdentifierName()
    }

    var forwardedString: String {
        "\(parameter.inout ? "&" : "")\(forwardedName)"
    }

    var forwardedName: String {
        keywords.contains(parameter.name) ? parameter.name.backticked : parameter.name
    }

    func description(at index: Int) -> String {
        let value = parameter.typeName.name == "String"
            ? "\\\"\\($0[\(index)]!)\\\""
            : "\\($0[\(index)] ?? \"nil\")"

        let label = parameter.argumentLabel == "_" ? nil : parameter.argumentLabel
        return "\(label.map { "\($0): " } ?? "")\(value)"
    }
}

let keywords = [
    "internal"
]
