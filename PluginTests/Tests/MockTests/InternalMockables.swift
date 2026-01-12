import Foundation
@testable import TestableMockables

// sourcery:AutoMockable
protocol InternalMockable {
    func doSomething(with internal: Internal)
    func doSomething(withAny any: Any)
}

struct Internal {}

// sourcery:AutoMockable
extension TestableMockable {}

// swiftformat:disable preferFinalClasses
public class PublicMockableClass {
    public func doSomething() {}
    public var value: Int = 0
}

// sourcery:AutoMockable
class InternalSubclassOfAPublicClass: PublicMockableClass {}
// swiftformat:enable preferFinalClasses

// sourcery:AutoMockable
@objc protocol ObjCMockable {
    @objc(doSomethingWith:)
    func doSomething(with int: Int)
}

protocol BaseGenericProtocol<Base> {
    associatedtype Base
    var base: Base { get set }

    subscript(key: Int) -> String { get }
}

// sourcery:AutoMockable
protocol RefinedGenericProtocol<A>: BaseGenericProtocol
    // The edge case needs Base.ID == A and not A == Base.ID
    where Base: Identifiable, Base.ID == A {
    associatedtype A
    associatedtype B where B == Base

    var a: A { get set }

    subscript(key: A) -> B { get set }
    func value(for key: A) -> B

    // Subscript overriding
    subscript(key: Int) -> String { get set }
}
