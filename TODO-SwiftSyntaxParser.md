## Plan: SyntaxParser Scaffold

Add a SwiftSyntax-powered target that captures every type declaration (and extension) with raw comments and extension metadata, preserving them as distinct entries for future filtering/composition.

### Steps
1. Update `Package.swift` to add the SwiftSyntax package dependency and declare a new `SyntaxParser` target depending on `.product(name: "SwiftSyntax", package: "swift-syntax")`.
2. Create `Sources/SyntaxParser/SyntaxTypes.swift` defining `enum Syntax { struct Type … }` where `Syntax.Type` mirrors `SourceryRuntime.Type` fields (name/localName, access level, inheritance, generics, members, annotations) plus `isExtension`, `comment: String?` (raw, line breaks preserved), and separate collections for methods/properties/subscripts/typealiases/extensions.
3. Implement `Sources/SyntaxParser/TypesCollector.swift` with `struct TypesCollector { func collect(from source: SourceFileSyntax) -> [Syntax.Type] }` that walks every declaration using SwiftSyntax, storing each protocol/class/struct/enum, and each extension as its own `Syntax.Type` entry with `isExtension = true` and untouched comment trivia.
4. Add `Tests/SyntaxParserTests/TypesCollectorTests.swift` containing fixture snippets to assert `collect` emits distinct entries for a protocol and its extensions, with accurate names, `isExtension` flags, and comment text. Make sure to use Swift Testing instead of XCTest.

### Further Considerations
1. Decide later whether we need a merging phase to combine extensions with base declarations or keep them distinct through templating; current plan keeps them separate per request.
