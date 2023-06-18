import XCTest
@testable import TestableMockables

final class TestableMockableTests: XCTestCase {
    func testExpectations() {
        let mock = TestableMockableMock()

        mock.expect(.doSomething(with: .matching { _ in true }))

        mock.doSomething(with: .init())

        mock.verify()
    }
}
