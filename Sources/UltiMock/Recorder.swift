import os
import XCTest

public final class Recorder: Sendable {
    private struct State {
        var stubs: [Stub] = []
        var onEmpty: (() -> Void)?

        mutating func next() -> Stub? {
            stubs.isEmpty ? nil : stubs.removeFirst()
        }

        mutating func reset() {
            onEmpty = nil
            stubs.removeAll()
        }
    }

    private let state = AllocatedUnfairLock(uncheckedState: State())

    public init() {}

    public var stubs: [Stub] {
        state.withLock(\.stubs)
    }

    public func record(_ stub: Stub) {
        state.withLock {
            $0.stubs.append(stub)
        }
    }

    public func next() -> Stub? {
        state.withLock {
            $0.next()
        }
    }

    public func checkVerification() {
        state.withLock {
            if $0.stubs.isEmpty {
                $0.onEmpty?()
            }
        }
    }

    func reset() {
        state.withLock {
            $0.reset()
        }
    }

    func verify(file: StaticString, line: UInt) {
        if stubs.count > 1 {
            XCTFail("Missing expected calls:\n\(stubs.map { "  \($0.expectation)" }.joined(separator: "\n"))", file: file, line: line)
        } else if stubs.count == 1 {
            XCTFail("Missing expected call: \(stubs[0].expectation)", file: file, line: line)
        }
        reset()
    }

    func verifyAsync(timeout: TimeInterval, file: StaticString, line: UInt) {
        guard stubs.count > 0 else {
            return
        }

        let expectation = XCTestExpectation(description: "Mock verify \(file):\(line)")
        state.withLock {
            guard $0.onEmpty == nil else {
                XCTFail("Attempt to verify the mock multiple times.", file: file, line: line)
                return
            }
            $0.onEmpty = {
                expectation.fulfill()
            }
        }
        XCTWaiter().wait(for: [expectation], timeout: timeout)
        verify(file: file, line: line)
    }
}
