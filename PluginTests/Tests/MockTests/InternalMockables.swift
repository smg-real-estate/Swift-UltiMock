import Foundation
@testable import TestableMockables

// sourcery:AutoMockable
protocol InternalMockable {
    func doSomething(with internal: Internal)
}

struct Internal {}

// sourcery:AutoMockable
extension TestableMockable {}

public class PublicMockableClass {
    public func doSomething() {}
    public var value: Int = 0
}

// sourcery:AutoMockable
class InternalSubclassOfAPublicClass: PublicMockableClass {}

// sourcery:AutoMockable
@objc protocol ObjCMockable {
    @objc(doSomethingWith:)
    func doSomething(with int: Int)
}
