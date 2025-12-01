struct TypeNameResolver {
    let typeAliases: [String: [String : AliasDefinition]]

    func resolvedTypeName(for name: String, scope: String) -> String {
        var currentScope = scope
        while true {
            if let aliasesInScope = typeAliases[currentScope],
               let alias = aliasesInScope[name] {
                return alias.text
            }
            if let dotRange = currentScope.range(of: ".", options: .backwards) {
                currentScope = String(currentScope[..<dotRange.lowerBound])
            } else {
                break
            }
        }
        return name
    }
}
