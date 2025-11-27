import Foundation
import SyntaxParser

struct MockedTypeInfo {
    let typeInfo: Syntax.TypeInfo
    let mockTypeName: String
    let methods: [MockedMethod]
    let properties: [MockedProperty]
    let subscripts: [MockedSubscript]
    
    init(_ typeInfo: Syntax.TypeInfo) {
        self.typeInfo = typeInfo
        let mockTypeName = "\(typeInfo.name)Mock"
        self.mockTypeName = mockTypeName
        
        let skipped = Set(typeInfo.annotations["skip", default: []])
        
        // Filter and map methods
        self.methods = typeInfo.allMethods.compactMap { method -> MockedMethod? in
            let mockedMethod = MockedMethod(method, mockTypeName: mockTypeName)
            guard !method.isStatic
                && !method.isClass
                && !mockedMethod.definedInExtension
                && !mockedMethod.isPrivate
                && !skipped.contains(method.unbacktickedCallName)
                && method.callName != "deinit"
            else { return nil }
            return mockedMethod
        }
        
        // Filter and map properties
        self.properties = typeInfo.allVariables.compactMap { property -> MockedProperty? in
            let mockedProperty = MockedProperty(property)
            guard !property.isStatic
                && !mockedProperty.definedInExtension
                && !skipped.contains(property.unbacktickedName)
            else { return nil }
            return mockedProperty
        }
        
        // Filter and map subscripts (with uniquing)
        self.subscripts = typeInfo.allSubscripts
            .map { MockedSubscript($0, mockTypeName: mockTypeName) }
            .unique(by: \.getterSignature) { old, new in old.isReadOnly ? new : old }
    }
    
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
        typeInfo.genericRequirements
            .filter {
                $0.relationshipSyntax == ":"
            }
            .reduce(into: [:]) { partialResult, requirement in
                partialResult[requirement.leftType.name] = requirement.rightType.typeName.name
            }
    }

    var mockAccessLevel: String {
        typeInfo.accessLevel.rawValue.replacingOccurrences(of: "open", with: "public")
            .trimmingCharacters(in: .whitespaces)
    }

    var mockClassAccessLevel: String {
        typeInfo.accessLevel.rawValue.contains("public") ? "open" : typeInfo.accessLevel.rawValue
    }

    var refinedAssociatedTypes: [String: String] {
        guard typeInfo.kind == .protocol else {
            return [:]
        }
        return typeInfo.genericRequirements
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
