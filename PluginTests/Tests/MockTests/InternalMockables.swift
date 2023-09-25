@testable import TestableMockables

// sourcery:AutoMockable
protocol InternalMockable {
    func doSomething(with internal: Internal)
}

struct Internal {}

// sourcery:AutoMockable
extension TestableMockable {}

public class PublicMockableClass {
    init() {}

    public func doSomething() {}
    public var value: Int = 0
}

// sourcery:AutoMockable
class InternalSubclassOfAPublicClass: PublicMockableClass {}
