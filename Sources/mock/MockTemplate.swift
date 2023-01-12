import SourceryRuntime
import XFoundation

struct MockTemplate {
    let types: Types
    let type: [String: Type]
    let functions: [SourceryMethod]
    let imports: [String]

    func render() -> String {
        blocks.joined(separator: "\n")
    }

    @ArrayBuilder<String>
    var blocks: [String] {
        Set(["XCTest", "UltiMock"] + imports)
            .sorted()
            .map {
                "import \($0)"
            }

        "\n// Generated by UltiMock. DO NOT EDIT!"

        for type in types.types.filter({ $0.annotations["AutoMockable"] != nil && !$0.isExtension }) {
            let skipped = type.annotations.array(of: String.self, for: "skip")
            let methods = type.allMethods.filter { !$0.isStatic && !$0.definedInExtension && !skipped.contains($0.unbacktickedCallName) }
            let properties = type.allVariables.filter { !$0.isStatic && !$0.definedInExtension && !skipped.contains($0.unbacktickedName) }

            let mockTypeName = "\(type.name)Mock"

            if let type = type as? SourceryRuntime.`Protocol` {
                """

                public final class \(mockTypeName)\(type.genericParameters): \(type.name), Mock {
                """
                for associatedType in type.associatedTypes.values.map(\.name).sorted(by: <) {
                    "    public typealias \(associatedType) = \(associatedType)"
                }
            } else {
                """

                public final class \(mockTypeName): \(type.name), Mock {
                """
            }
            """

                enum Methods {
            """
            methods.map(\.definition).indented(2)

            properties.flatMap(\.definitions).indented(2)

            let mocksClass = type is SourceryRuntime.Class

            """
                }

                public struct MethodExpectation<Signature> {
                    public let expectation: Recorder.Expectation

                    init(method: MockMethod, parameters: [AnyParameter]) {
                        self.expectation = .init(
                            method: method,
                            parameters: parameters
                        )
                    }
            """

            methods.map {
                "\n" + $0.expectationConstructor(mockTypeName, forwarding: mocksClass)
                    .indented(2)
            }

            """
                }
            """

            if !properties.isEmpty {
                """
                    public struct PropertyExpectation<Signature> {
                        private let method: MockMethod

                        init(method: MockMethod) {
                            self.method = method
                        }

                        public var getterExpectation: Recorder.Expectation {
                            .init(
                                method: method,
                                parameters: []
                            )
                        }

                        public func setterExpectation(_ newValue: AnyParameter) -> Recorder.Expectation {
                            .init(
                                method: method,
                                parameters: [newValue]
                            )
                        }
                    }
                """
            }
            """

                public let recorder = Recorder()

                private let file: StaticString
                private let line: UInt

            """

            if type is SourceryRuntime.`Protocol` {
                """
                    public init(file: StaticString = #filePath, line: UInt = #line) {
                        self.file = file
                        self.line = line
                    }
                """
            }

            let requiredInitialzers = type.implements.values
                .flatMap(\.methods)
                .filter(\.isInitializer)

            for method in requiredInitialzers {
                """

                    @available(*, unavailable)
                    \("required ")\(method.name) {
                        fatalError()
                    }
                """
            }

            for method in type.methods.filter(\.isInitializer) {
                """

                    public \(method.name.dropLast())\(method.parameters.isEmpty ? "" : ", ")file: StaticString = #filePath, line: UInt = #line) {
                        self.file = file
                        self.line = line
                        self.autoForwardingEnabled = true
                        super.init(\(method.forwardedLabeledParameters))
                        self.autoForwardingEnabled = false
                    }
                """
            }

            if mocksClass {
                """

                    public var autoForwardingEnabled: Bool

                    public var isEnabled: Bool {
                        !autoForwardingEnabled
                    }
                """
            }

            """
                private func _record<P>(_ expectation: Recorder.Expectation, _ file: StaticString, _ line: UInt, _ perform: P) {
                    guard isEnabled else {
                        handleFatalFailure("Setting expectation on disabled mock is not allowed", file: file, line: line)
                    }
                    recorder.record(.init(expectation, perform, file, line))
                }

                private func _perform(_ method: MockMethod, _ parameters: [Any?] = []) -> Any {
                    let invocation = Invocation(
                        method: method,
                        parameters: parameters
                    )
                    guard let stub = recorder.next() else {
                        handleFatalFailure("Expected no calls but received `\\(invocation)`", file: file, line: line)
                    }

                    guard stub.matches(invocation) else {
                        handleFatalFailure(
                            "Unexpected call: expected `\\(stub.expectation)`, but received `\\(invocation)`",
                            file: stub.file,
                            line: stub.line
                        )
                    }

                    return stub.perform
                }
            """

            methods.map {
                "\n" + $0.implementation(mockTypeName, override: mocksClass)
                    .indented(1)
                    .joined(separator: "\n")
            }

            properties.map {
                "\n" + $0.implementation(override: mocksClass)
                    .indented(1)
                    .joined(separator: "\n")
            }

            methods.unique(by: \.rawSignature)
                .map { "\n" + $0.mockExpect(mockTypeName, forwarding: mocksClass) }

            properties.unique(by: \.getterSignature)
                .map { "\n" + $0.mockExpectGetter(forwarding: mocksClass) }

            properties.unique(by: \.setterSignature)
                .map { "\n" + $0.mockExpectSetter(forwarding: mocksClass) }
            """
            }
            """
            properties.map {
                "\n" + $0.expectationExtensions(mockTypeName, forwarding: mocksClass)
                    .joined(separator: "\n\n")
            }
        }
        "\n"
    }
}

extension Dictionary {
    func array<T>(of type: T.Type = T.self, for key: Key) -> [T] {
        if let array = self[key] as? [T] {
            return array
        }
        if let singleValue = self[key] as? T {
            return [singleValue]
        }
        return []
    }
}
