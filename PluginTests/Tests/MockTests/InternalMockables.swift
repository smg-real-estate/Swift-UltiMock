@testable import TestableMockables

// sourcery:AutoMockable
protocol InternalMockable {
    func doSomething(with internal: Internal)
}

struct Internal {}

// sourcery:AutoMockable
extension TestableMockable {}
