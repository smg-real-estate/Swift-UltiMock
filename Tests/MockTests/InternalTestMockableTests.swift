import XCTest

final class InternalTestMockableTests: XCTestCase {
    func testExpectations() {
        let mock = InternalMockableMock()

        mock.expect(.doSomething(with: .matching { _ in true }))

        mock.doSomething(with: .init())

        mock.verify()
    }
}
