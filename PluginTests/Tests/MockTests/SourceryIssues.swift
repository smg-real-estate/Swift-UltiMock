private enum Foo {
    typealias Bar = Int
}

// sourcery:AutoMockable
protocol SourceryIssue1 {
    // The `actualTypeName` of `Bar` is incorrectly resolved as `Int` from the typealias in `Foo`
    associatedtype Bar

    var value: Bar { get }
}

// Ensure mock generation
typealias Mock1 = SourceryIssue1Mock<String>
