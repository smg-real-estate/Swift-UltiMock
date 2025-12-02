import SwiftSyntax

struct MockType {
    let declaration: DeclSyntax

    init(_ typeInfo: Syntax.TypeInfo) {
        self.declaration = typeInfo.declaration
    }

    struct Method {
        let declaration: FunctionDeclSyntax

        var stubIdentifier: String {
            var parts: [String] = []
            var name = declaration.name.text.replacingOccurrences(of: "`", with: "")

            let parameters = declaration.signature.parameterClause.parameters
            let isAsync = declaration.signature.effectSpecifiers?.asyncSpecifier != nil

            if isAsync && !parameters.isEmpty {
                name += "_async"
            }
            parts.append(name)

            for param in parameters {
                let label = param.firstName.text
                let typeName = param.type.description.trimmingCharacters(in: .whitespaces)

                if label == "_" {
                    let paramName = param.secondName?.text ?? ""
                    if paramName == "anonymous" {
                        parts.append("_\(typeName)")
                    } else {
                        parts.append("_\(paramName)_\(typeName)")
                    }
                } else {
                    parts.append("\(label)_\(typeName)")
                }
            }

            let returnTypeString = declaration.signature.returnClause?.type.description.trimmingCharacters(in: .whitespaces) ?? "Void"

            if isAsync {
                parts.append("async")
            } else {
                if returnTypeString == "Void" {
                    parts.append("sync")
                }
            }

            if declaration.signature.effectSpecifiers?.throwsSpecifier != nil {
                parts.append("throws")
            }

            parts.append("ret_\(returnTypeString)")

            return parts.joined(separator: "_")
        }
    }
}
