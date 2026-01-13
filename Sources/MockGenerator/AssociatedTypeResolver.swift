import SwiftSyntax

final class AssociatedTypeResolver {
    let associatedTypes: [AssociatedTypeDeclSyntax]
    let protocols: [ProtocolDeclSyntax]

    struct ResolvedType {
        let name: String
        let resolvedTo: TypeSyntax?
        let conformances: [TypeSyntax]
    }

    init(protocols: [ProtocolDeclSyntax]) {
        self.protocols = protocols
        self.associatedTypes = protocols
            .flatMap { protocolDecl in
                protocolDecl.memberBlock.members.compactMap { member in
                    member.decl.as(AssociatedTypeDeclSyntax.self)
                }
            }
            .unique(by: \.name.text)
    }

    lazy var sameTypeConstraints: [String: TypeSyntax] = {
        var constraints: [String: TypeSyntax] = [:]

        for protocolDecl in protocols {
            if let whereClause = protocolDecl.genericWhereClause {
                collectSameTypeConstraints(from: whereClause, into: &constraints)
            }
        }

        for associatedType in associatedTypes {
            if let whereClause = associatedType.genericWhereClause {
                collectSameTypeConstraints(from: whereClause, into: &constraints)
            }
        }

        return constraints
    }()

    lazy var conformanceConstraints: [String: [TypeSyntax]] = {
        var constraints: [String: [TypeSyntax]] = [:]

        for assoc in associatedTypes {
            let name = assoc.name.text
            if let inheritanceClause = assoc.inheritanceClause {
                let types = inheritanceClause.inheritedTypes.map(\.type)
                constraints[name, default: []].append(contentsOf: types)
            }
        }

        for protocolDecl in protocols {
            if let whereClause = protocolDecl.genericWhereClause {
                collectConformanceConstraints(from: whereClause, into: &constraints)
            }
        }

        for associatedType in associatedTypes {
            if let whereClause = associatedType.genericWhereClause {
                collectConformanceConstraints(from: whereClause, into: &constraints)
            }
        }

        return constraints
    }()

    lazy var resolvedTypes: [ResolvedType] = associatedTypes.map { assoc in
        let name = assoc.name.text
        let resolvedTo = sameTypeConstraints[name]
        let conformances = conformanceConstraints[name] ?? []
        return ResolvedType(name: name, resolvedTo: resolvedTo, conformances: conformances)
    }

    lazy var primaryTypes: [ResolvedType] = resolvedTypes.filter { $0.resolvedTo == nil }

    lazy var derivedTypes: [ResolvedType] = resolvedTypes.filter { $0.resolvedTo != nil }
}

private extension AssociatedTypeResolver {
    func collectSameTypeConstraints(from whereClause: GenericWhereClauseSyntax, into constraints: inout [String: TypeSyntax]) {
        for requirement in whereClause.requirements {
            guard case let .sameTypeRequirement(sameType) = requirement.requirement else {
                continue
            }

            let leftType = sameType.leftType.as(TypeSyntax.self)!
            let rightType = sameType.rightType.as(TypeSyntax.self)!

            if let leftIdent = leftType.as(IdentifierTypeSyntax.self),
               associatedTypeNames.contains(leftIdent.name.text) {
                constraints[leftIdent.name.text] = rightType
            } else if let rightIdent = rightType.as(IdentifierTypeSyntax.self),
                      associatedTypeNames.contains(rightIdent.name.text) {
                constraints[rightIdent.name.text] = leftType
            }
        }
    }

    func collectConformanceConstraints(from whereClause: GenericWhereClauseSyntax, into constraints: inout [String: [TypeSyntax]]) {
        for requirement in whereClause.requirements {
            guard case let .conformanceRequirement(conformance) = requirement.requirement else {
                continue
            }

            let leftType = conformance.leftType
            let rightType = conformance.rightType

            if let leftIdent = leftType.as(IdentifierTypeSyntax.self),
               associatedTypeNames.contains(leftIdent.name.text) {
                constraints[leftIdent.name.text, default: []].append(rightType)
            }
        }
    }

    var associatedTypeNames: Set<String> {
        Set(associatedTypes.map(\.name.text))
    }
}
