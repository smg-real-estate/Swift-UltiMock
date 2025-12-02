public struct TypeInfoResolver {
    var collectTypes: (_ content: String) -> [Syntax.TypeInfo]
}

public extension TypeInfoResolver {
    init() {
        self.init(collectTypes: TypesCollector().collect)
    }

    func resolve(from contentSequence: some Sequence<() throws -> String?>) throws -> [Syntax.TypeInfo] {
        let allTypes = try contentSequence.flatMap { content in
            if let content = try content() {
                collectTypes(content)
            } else {
                [Syntax.TypeInfo]()
            }
        }

        return resolve(allTypes)
    }
}

extension TypeInfoResolver {
    func resolve(_ types: [Syntax.TypeInfo]) -> [Syntax.TypeInfo] {
        var baseOrder: [String] = []
        var baseTypes: [String: Syntax.TypeInfo] = [:]
        var extensions: [String: [Syntax.TypeInfo]] = [:]

//        for type in types {
//            if type.isExtension {
//                extensions[type.name, default: []].append(type)
//            } else {
//                if let existing = baseTypes[type.name] {
//                    baseTypes[type.name] = merge(base: existing, with: type)
//                } else {
//                    baseOrder.append(type.name)
//                    baseTypes[type.name] = type
//                }
//            }
//        }

        for (name, attachedExtensions) in extensions {
            if var base = baseTypes[name] {
                for ext in attachedExtensions {
                    base = mergeAnnotations(from: ext, into: base)
                }
                baseTypes[name] = base
            }
        }

        let resolvedProtocols = resolveProtocolInheritance(in: baseTypes)
        let resolvedClasses = resolveClassInheritance(in: resolvedProtocols)

        return baseOrder.compactMap { resolvedClasses[$0] }
    }
}

private extension TypeInfoResolver {
    func merge(base: Syntax.TypeInfo, with other: Syntax.TypeInfo) -> Syntax.TypeInfo {
        var merged = base
//        merged.methods += other.methods
//        merged.properties += other.properties
//        merged.subscripts += other.subscripts
//        merged.comment = base.comment ?? other.comment
//        merged.associatedTypes += other.associatedTypes
//        merged.genericRequirements += other.genericRequirements
        return merged
    }

    func mergeAnnotations(from extensionType: Syntax.TypeInfo, into base: Syntax.TypeInfo) -> Syntax.TypeInfo {
//        guard !extensionType.annotations.isEmpty else {
//            return base
//        }

        var merged = base
//        for (key, value) in extensionType.annotations {
//            merged.annotations[key, default: []].append(contentsOf: value)
//        }
        return merged
    }

    func resolveProtocolInheritance(in types: [String: Syntax.TypeInfo]) -> [String: Syntax.TypeInfo] {
        var cache: [String: Syntax.TypeInfo] = [:]
        var visiting: Set<String> = []

//        func resolve(name: String) -> Syntax.TypeInfo? {
//            if let cached = cache[name] {
//                return cached
//            }
//            guard var type = types[name] else {
//                return nil
//            }
//            guard type.kind == .protocol else {
//                cache[name] = type
//                return type
//            }
//
//            if visiting.contains(name) {
//                return type
//            }
//
//            visiting.insert(name)
//            var methods = type.methods
//            var properties = type.properties
//            var subscripts = type.subscripts
//            var associatedTypes = type.associatedTypes
//            var seenAssociatedNames = Set(associatedTypes.map(\.name))
//
//            for inheritedName in type.inheritedTypes {
//                guard let inherited = resolve(name: inheritedName) else {
//                    continue
//                }
//                methods.append(contentsOf: inherited.methods)
//                properties.append(contentsOf: inherited.properties)
//                subscripts.append(contentsOf: inherited.subscripts)
//                for associated in inherited.associatedTypes where !seenAssociatedNames.contains(associated.name) {
//                    associatedTypes.append(associated)
//                    seenAssociatedNames.insert(associated.name)
//                }
//            }
//
//            visiting.remove(name)
//
//            type.methods = methods
//            type.properties = properties
//            type.subscripts = subscripts
//            type.associatedTypes = associatedTypes
//
//            cache[name] = type
//            return type
//        }

        var resolved: [String: Syntax.TypeInfo] = [:]
//        for name in types.keys {
//            resolved[name] = resolve(name: name)
//        }
        return resolved
    }

    func resolveClassInheritance(in types: [String: Syntax.TypeInfo]) -> [String: Syntax.TypeInfo] {
        var cache: [String: Syntax.TypeInfo] = [:]
        var visiting: Set<String> = []

//        func resolve(name: String) -> Syntax.TypeInfo? {
//            if let cached = cache[name] {
//                return cached
//            }
//            guard var type = types[name] else {
//                return nil
//            }
//            guard type.kind == .class else {
//                cache[name] = type
//                return type
//            }
//
//            if visiting.contains(name) {
//                return type
//            }
//            visiting.insert(name)
//
//            if let superclassName = type.inheritedTypes.first(where: { types[$0]?.kind == .class }),
//               let superclass = resolve(name: superclassName) {
//                type = mergeClass(type, with: superclass)
//            }
//
//            visiting.remove(name)
//            cache[name] = type
//            return type
//        }

        var resolved: [String: Syntax.TypeInfo] = types
        for name in types.keys {
//            if let updated = resolve(name: name) {
//                resolved[name] = updated
//            }
        }
        return resolved
    }

    func mergeClass(_ type: Syntax.TypeInfo, with superclass: Syntax.TypeInfo) -> Syntax.TypeInfo {
//        let methods = Set(type.methods.map(\.signatureData))
//        let inheritedMethods = superclass.methods.filter { !methods.contains($0.signatureData) }
//
//        let properties = Set(type.properties)
//        let inheritedProperties = superclass.properties.filter { !properties.contains($0) }
//
//        let subscripts = Set(type.subscripts)
//        let inheritedSubscripts = superclass.subscripts.filter { !subscripts.contains($0) }

        var merged = type
//        merged.methods += inheritedMethods
//        merged.properties += inheritedProperties
//        merged.subscripts += inheritedSubscripts
        return merged
    }
}
