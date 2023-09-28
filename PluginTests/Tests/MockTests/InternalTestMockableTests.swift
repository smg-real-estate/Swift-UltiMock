import XCTest

final class InternalTestMockableTests: XCTestCase {
    struct TestIdentifiable: Identifiable {
        let id: Int
    }

    // Testing definitions
    var refinedGenericProtocolMock: RefinedGenericProtocolMock<TestIdentifiable>!

    func testExpectations() {
        let mock = InternalMockableMock()

        mock.expect(.doSomething(with: .matching { _ in true }))

        mock.doSomething(with: .init())

        mock.verify()
    }
}
