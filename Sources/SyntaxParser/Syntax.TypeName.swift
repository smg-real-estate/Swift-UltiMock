import Foundation

extension Syntax {
    public struct TypeName: Equatable {
        public let name: String
        public let isOptional: Bool
        public let isImplicitlyUnwrappedOptional: Bool
        public let unwrappedTypeName: String
        public let actualTypeNameString: String?
        public let isVoid: Bool
        public let isClosure: Bool
        public let closureDescription: String?
        public let attributes: [Attribute]

        public init(
            name: String,
            isOptional: Bool = false,
            isImplicitlyUnwrappedOptional: Bool = false,
            unwrappedTypeName: String? = nil,
            actualTypeNameString: String? = nil,
            isVoid: Bool = false,
            isClosure: Bool = false,
            closureDescription: String? = nil,
            attributes: [Attribute] = []
        ) {
            self.name = name
            self.isOptional = isOptional
            self.isImplicitlyUnwrappedOptional = isImplicitlyUnwrappedOptional
            self.unwrappedTypeName = unwrappedTypeName ?? name.replacingOccurrences(of: "?", with: "").replacingOccurrences(of: "!", with: "")
            self.actualTypeNameString = actualTypeNameString
            self.isVoid = isVoid || name == "Void" || name == "()"
            self.isClosure = isClosure
            self.closureDescription = closureDescription
            self.attributes = attributes
        }

        public var actualTypeName: TypeName? {
            actualTypeNameString.map { TypeName(name: $0) }
        }

        public var closure: ClosureType? {
            guard isClosure, let desc = closureDescription else {
                return nil
            }
            return ClosureType(description: desc)
        }

        public var fixedName: String {
            let escapingAttributes = attributes.filter { $0.name == "escaping" }
            if escapingAttributes.isEmpty {
                return name
            }

            var cleanName = name
            for attr in escapingAttributes {
                cleanName = cleanName.replacingOccurrences(of: "@\(attr.name)", with: "").trimmingCharacters(in: .whitespaces)
            }
            return cleanName
        }

        public var normalizedName: String {
            name
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

        public var nameWithoutAttributes: String {
            if attributes.isEmpty {
                return normalizedName
            }

            var cleanName = normalizedName
            for attr in attributes {
                cleanName = cleanName.replacingOccurrences(of: "@\(attr.name)", with: "").trimmingCharacters(in: .whitespaces)
            }
            return cleanName
        }

        public var asSource: String { name }

        public static func parse(_ typeString: String, actualTypeNameString: String? = nil) -> TypeName {
            let trimmed = typeString.trimmingCharacters(in: .whitespaces)

            var attributes: [Attribute] = []
            var workingString = trimmed

            if let escapingRange = workingString.range(of: "@escaping") {
                attributes.append(Attribute(name: "escaping"))
                let prefix = String(workingString[..<escapingRange.lowerBound])
                let suffix = String(workingString[escapingRange.upperBound...].drop(while: { $0.isWhitespace }))
                workingString = (prefix + suffix).trimmingCharacters(in: .whitespaces)
            }

            let cleanedString = workingString.trimmingCharacters(in: .whitespaces)

            if cleanedString.hasSuffix("!") {
                let unwrapped = String(cleanedString.dropLast())
                return TypeName(
                    name: cleanedString,
                    isOptional: false,
                    isImplicitlyUnwrappedOptional: true,
                    unwrappedTypeName: unwrapped,
                    actualTypeNameString: actualTypeNameString,
                    isVoid: unwrapped == "Void" || unwrapped == "()",
                    isClosure: unwrapped.contains("->"),
                    attributes: attributes
                )
            }

            if cleanedString.hasSuffix("?") {
                let unwrapped = String(cleanedString.dropLast())
                return TypeName(
                    name: cleanedString,
                    isOptional: true,
                    isImplicitlyUnwrappedOptional: false,
                    unwrappedTypeName: unwrapped,
                    actualTypeNameString: actualTypeNameString,
                    isVoid: unwrapped == "Void" || unwrapped == "()",
                    isClosure: unwrapped.contains("->"),
                    attributes: attributes
                )
            }

            return TypeName(
                name: cleanedString,
                isOptional: false,
                isImplicitlyUnwrappedOptional: false,
                unwrappedTypeName: cleanedString,
                actualTypeNameString: actualTypeNameString,
                isVoid: cleanedString == "Void" || cleanedString == "()",
                isClosure: cleanedString.contains("->"),
                attributes: attributes
            )
        }
    }
}
