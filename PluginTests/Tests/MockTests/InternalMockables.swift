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

protocol BaseGenericProtocol<Base> {
    associatedtype Base
    var base: Base { get set }
}

// sourcery:AutoMockable
// Sourcery does not support where clause for associated types
// sourcery:typealias = "B = Base"
protocol RefinedGenericProtocol<A>: BaseGenericProtocol
    // The edge case needs Base.ID == A and not A == Base.ID
    where Base: Identifiable, Base.ID == A {
    associatedtype A
    associatedtype B where B == Base
}
