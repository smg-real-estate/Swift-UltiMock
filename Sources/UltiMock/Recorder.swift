import os
import XCTest

public final class Recorder {
    private let protectedStubs = AllocatedUnfairLock(uncheckedState: [Stub]())
    private var onEmpty: (() -> Void)?

    public init() {}

    public var stubs: [Stub] {
        protectedStubs.withLock { $0 }
    }

    public func record(_ stub: Stub) {
        protectedStubs.withLock { stubs in
            stubs.append(stub)
        }
    }

    public func next() -> Stub? {
        protectedStubs.withLock { stubs in
            stubs.isEmpty ? nil : stubs.removeFirst()
        }
    }

    public func checkVerification() {
        protectedStubs.withLock { stubs in
            if stubs.isEmpty {
                onEmpty?()
            }
        }
    }

    func reset() {
        onEmpty = nil
        protectedStubs.withLock { stubs in
            stubs.removeAll()
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
        guard onEmpty == nil else {
            XCTFail("Attempt to verify the mock multiple times.", file: file, line: line)
            return
        }
        onEmpty = {
            expectation.fulfill()
        }
        XCTWaiter().wait(for: [expectation], timeout: timeout)
        verify(file: file, line: line)
    }
}
