import Testing

final class MockableTests {
    @Test func expectations() {
        let mock = MockableMock()

        func callNonisolated(_ closure: @Sendable () -> Void) {
            closure()
        }

        func callIsolated(_ closure: @MainActor () -> Void) {
            closure()
        }

        mock.expect(.nonisolatedMethod())
        mock.expect(.isolatedMethod())

        // If `nonisolatedMethod` is not annotated with `nonisolated`
        // it would inherit @MainActor isolation and cause the error:
        // "Converting function value of type '@MainActor @Sendable () -> ()' to '@Sendable () -> Void' loses global actor 'MainActor'"
        callNonisolated(mock.nonisolatedMethod)

        callIsolated(mock.isolatedMethod)

        mock.verify()
    }
}
