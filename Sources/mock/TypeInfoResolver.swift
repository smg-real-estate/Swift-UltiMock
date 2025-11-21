import UltiMockSwiftSyntaxParser

struct TypeInfoResolver {
    func resolve(_ types: [Syntax.TypeInfo]) -> [Syntax.TypeInfo] {
        var baseOrder: [String] = []
        var baseTypes: [String: Syntax.TypeInfo] = [:]
        var extensions: [String: [Syntax.TypeInfo]] = [:]

        for type in types {
            if type.isExtension {
                extensions[type.name, default: []].append(type)
            } else {
                if baseTypes[type.name] == nil {
                    baseOrder.append(type.name)
                    baseTypes[type.name] = type
                } else if let existing = baseTypes[type.name] {
                    baseTypes[type.name] = merge(base: existing, with: type)
                }
            }
        }

        for (name, attachedExtensions) in extensions {
            if var base = baseTypes[name] {
                for ext in attachedExtensions {
                    base = mergeAnnotations(from: ext, into: base)
                }
                baseTypes[name] = base
            } else if let synthetic = syntheticType(from: attachedExtensions) {
                baseOrder.append(name)
                baseTypes[name] = synthetic
            }
        }

        let resolvedProtocols = resolveProtocolInheritance(in: baseTypes)
        let resolvedClasses = resolveClassInheritance(in: resolvedProtocols)

        return baseOrder.compactMap { resolvedClasses[$0] }
    }
}

private extension TypeInfoResolver {
    func syntheticType(from extensions: [Syntax.TypeInfo]) -> Syntax.TypeInfo? {
        guard extensions.contains(where: { $0.annotations["AutoMockable"] != nil }) else {
            return nil
        }

        var annotations: [String: String] = [:]
        for ext in extensions {
            for (key, value) in ext.annotations {
                annotations[key] = value
            }
        }

        guard let sample = extensions.first else {
            return nil
        }

        return Syntax.TypeInfo(
            kind: .class,
            name: sample.name,
            localName: sample.localName,
            accessLevel: sample.accessLevel,
            inheritedTypes: sample.inheritedTypes,
            genericParameters: sample.genericParameters,
            methods: [],
            properties: [],
            subscripts: [],
            typealiases: sample.typealiases,
            extensions: sample.extensions,
            annotations: annotations,
            isExtension: false,
            comment: sample.comment,
            associatedTypes: sample.associatedTypes,
            genericRequirements: sample.genericRequirements
        )
    }

    func merge(base: Syntax.TypeInfo, with other: Syntax.TypeInfo) -> Syntax.TypeInfo {
        Syntax.TypeInfo(
            kind: base.kind,
            name: base.name,
            localName: base.localName,
            accessLevel: base.accessLevel,
            inheritedTypes: base.inheritedTypes,
            genericParameters: base.genericParameters,
            methods: base.methods + other.methods,
            properties: base.properties + other.properties,
            subscripts: base.subscripts + other.subscripts,
            typealiases: base.typealiases + other.typealiases,
            extensions: base.extensions,
            annotations: base.annotations,
            isExtension: base.isExtension,
            comment: base.comment ?? other.comment,
            associatedTypes: base.associatedTypes + other.associatedTypes,
            genericRequirements: base.genericRequirements + other.genericRequirements
        )
    }

    func mergeAnnotations(from extensionType: Syntax.TypeInfo, into base: Syntax.TypeInfo) -> Syntax.TypeInfo {
        guard !extensionType.annotations.isEmpty else {
            return base
        }

        var annotations = base.annotations
        for (key, value) in extensionType.annotations {
            annotations[key] = value
        }

        return Syntax.TypeInfo(
            kind: base.kind,
            name: base.name,
            localName: base.localName,
            accessLevel: base.accessLevel,
            inheritedTypes: base.inheritedTypes,
            genericParameters: base.genericParameters,
            methods: base.methods,
            properties: base.properties,
            subscripts: base.subscripts,
            typealiases: base.typealiases,
            extensions: base.extensions,
            annotations: annotations,
            isExtension: base.isExtension,
            comment: base.comment,
            associatedTypes: base.associatedTypes,
            genericRequirements: base.genericRequirements
        )
    }

    func resolveProtocolInheritance(in types: [String: Syntax.TypeInfo]) -> [String: Syntax.TypeInfo] {
        var cache: [String: Syntax.TypeInfo] = [:]
        var visiting: Set<String> = []

        func resolve(name: String) -> Syntax.TypeInfo? {
            if let cached = cache[name] {
                return cached
            }
            guard var type = types[name] else {
                return nil
            }
            guard type.kind == .protocol else {
                cache[name] = type
                return type
            }

            if visiting.contains(name) {
                return type
            }

            visiting.insert(name)
            var methods = type.methods
            var properties = type.properties
            var subscripts = type.subscripts
            var associatedTypes = type.associatedTypes
            var seenAssociatedNames = Set(associatedTypes.map(\.name))

            for inheritedName in type.inheritedTypes {
                guard let inherited = resolve(name: inheritedName) else { continue }
                methods.append(contentsOf: inherited.methods)
                properties.append(contentsOf: inherited.properties)
                subscripts.append(contentsOf: inherited.subscripts)
                for associated in inherited.associatedTypes where !seenAssociatedNames.contains(associated.name) {
                    associatedTypes.append(associated)
                    seenAssociatedNames.insert(associated.name)
                }
            }

            visiting.remove(name)

            type = Syntax.TypeInfo(
                kind: type.kind,
                name: type.name,
                localName: type.localName,
                accessLevel: type.accessLevel,
                inheritedTypes: type.inheritedTypes,
                genericParameters: type.genericParameters,
                methods: methods,
                properties: properties,
                subscripts: subscripts,
                typealiases: type.typealiases,
                extensions: type.extensions,
                annotations: type.annotations,
                isExtension: type.isExtension,
                comment: type.comment,
                associatedTypes: associatedTypes,
                genericRequirements: type.genericRequirements
            )

            cache[name] = type
            return type
        }

        var resolved: [String: Syntax.TypeInfo] = [:]
        for name in types.keys {
            resolved[name] = resolve(name: name)
        }
        return resolved
    }

    func resolveClassInheritance(in types: [String: Syntax.TypeInfo]) -> [String: Syntax.TypeInfo] {
        var cache: [String: Syntax.TypeInfo] = [:]
        var visiting: Set<String> = []

        func resolve(name: String) -> Syntax.TypeInfo? {
            if let cached = cache[name] {
                return cached
            }
            guard var type = types[name] else {
                return nil
            }
            guard type.kind == .class else {
                cache[name] = type
                return type
            }

            if visiting.contains(name) {
                return type
            }
            visiting.insert(name)

            if let superclassName = type.inheritedTypes.first(where: { types[$0]?.kind == .class }),
               let superclass = resolve(name: superclassName) {
                type = mergeClass(type, with: superclass)
            }

            visiting.remove(name)
            cache[name] = type
            return type
        }

        var resolved: [String: Syntax.TypeInfo] = types
        for name in types.keys {
            if let updated = resolve(name: name) {
                resolved[name] = updated
            }
        }
        return resolved
    }

    func mergeClass(_ type: Syntax.TypeInfo, with superclass: Syntax.TypeInfo) -> Syntax.TypeInfo {
        let methodSignatures = Set(type.methods.map(\.methodIdentifier))
        let inheritedMethods = superclass.methods.filter { !methodSignatures.contains($0.methodIdentifier) }

        var propertySignatures = Set(type.properties.map(\.getterIdentifier))
        let inheritedProperties = superclass.properties.filter { property in
            let signature = property.getterIdentifier
            if propertySignatures.contains(signature) {
                return false
            }
            propertySignatures.insert(signature)
            return true
        }

        let subscriptSignatures = Set(type.subscripts.map(\.getterSignature))
        let inheritedSubscripts = superclass.subscripts.filter { !subscriptSignatures.contains($0.getterSignature) }

        return Syntax.TypeInfo(
            kind: type.kind,
            name: type.name,
            localName: type.localName,
            accessLevel: type.accessLevel,
            inheritedTypes: type.inheritedTypes,
            genericParameters: type.genericParameters,
            methods: type.methods + inheritedMethods,
            properties: type.properties + inheritedProperties,
            subscripts: type.subscripts + inheritedSubscripts,
            typealiases: type.typealiases,
            extensions: type.extensions,
            annotations: type.annotations,
            isExtension: type.isExtension,
            comment: type.comment,
            associatedTypes: type.associatedTypes,
            genericRequirements: type.genericRequirements
        )
    }
}
