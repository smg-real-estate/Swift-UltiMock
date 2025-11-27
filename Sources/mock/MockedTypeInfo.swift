import Foundation
import SyntaxParser

struct MockedTypeInfo {
    let typeInfo: Syntax.TypeInfo
    let mockTypeName: String
    let typeAliases: [String: String]
    let namespacedTypes: [String: String]
    let associatedTypes: [Syntax.AssociatedType]
    let refinedAssociatedTypes: [String: String]
    let methods: [MockedMethod]
    let properties: [MockedProperty]
    let subscripts: [MockedSubscript]
    
    init(_ type: Syntax.TypeInfo) {
        self.typeInfo = type
        let mockTypeName = "\(type.name)Mock"
        self.mockTypeName = mockTypeName
        
        let skipped = Set(type.annotations["skip", default: []])

        let typeAliases: [String: String] = type.annotations["typealias", default: []]
            .reduce(into: [:]) { partialResult, statement in
                let parts = statement.split(separator: "=", maxSplits: 1).map { String($0).trimmed }
                guard
                    let rawKey = parts.first?.unquoted,
                    let rawValue = parts.last?.unquoted,
                    !rawKey.isEmpty,
                    !rawValue.isEmpty
                else {
                    return
                }

                partialResult[rawKey] = rawValue
            }

        self.namespacedTypes = (type.kind == .protocol) ? type.associatedTypes
            .reduce(into: [:]) { partialResult, associatedType in
                partialResult[associatedType.name] = "\(mockTypeName).\(associatedType.name)"
            } : [:]

        let refinedAssociatedTypes: [String : String] = typeInfo.genericRequirements
            .filter { $0.relationshipSyntax == "==" }
            .reduce(into: [:]) { partialResult, requirement in
                let left = requirement.leftType.name
                let right = requirement.rightType.typeName.name

                if !left.contains(".") {
                    partialResult[left] = right
                }
                if !right.contains(".") {
                    partialResult[right] = left
                }
            }

        self.associatedTypes = typeInfo.associatedTypes
            .filter {
                typeAliases.values.contains($0.name)
                || refinedAssociatedTypes[$0.name] == nil
                && typeAliases[$0.name] == nil
            }
            .sorted(by: \.name, <)

        self.refinedAssociatedTypes = refinedAssociatedTypes
        self.typeAliases = typeAliases

        // Filter and map methods
        self.methods = type.allMethods.compactMap { method -> MockedMethod? in
            let mockedMethod = MockedMethod(method, mockTypeName: mockTypeName)
            guard !method.isStatic
                && !method.isClass
                && !mockedMethod.definedInExtension
                && !mockedMethod.isPrivate
                && !skipped.contains(method.unbacktickedCallName)
                && method.callName != "deinit"
            else { return nil }
            return mockedMethod
        }
        
        // Filter and map properties
        self.properties = type.allVariables.compactMap { property -> MockedProperty? in
            let mockedProperty = MockedProperty(property)
            guard !property.isStatic
                && !mockedProperty.definedInExtension
                && !skipped.contains(property.unbacktickedName)
            else { return nil }
            return mockedProperty
        }
        
        // Filter and map subscripts (with uniquing)
        self.subscripts = type.allSubscripts
            .map { MockedSubscript($0, mockTypeName: mockTypeName) }
            .unique(by: \.getterSignature) { old, new in old.isReadOnly ? new : old }
    }

    @StringBuilder
    var mockTypeDefinition: String {
        if typeInfo.kind == .protocol {
            let sendable = typeInfo.based["Sendable"].map { ", @unchecked \($0)" } ?? ""

                """
                \(mockClassAccessLevel) class \(mockTypeName)\(genericParameters(associatedTypes)): \(typeInfo.name)\(sendable), Mock {
                """
            for associatedType in associatedTypes {
                "    \(mockAccessLevel) typealias \(associatedType.name) = \(associatedType.name)"
            }
            for (left, right) in refinedAssociatedTypes.merging(typeAliases, uniquingKeysWith: { _, new in new }) {
                "    \(mockAccessLevel) typealias \(left) = \(right)"
            }
        } else {
                """
                \(mockClassAccessLevel) class \(mockTypeName): \(typeInfo.name), Mock {
                """
        }
    }

    func genericParameters(_ associatedTypes: [Syntax.AssociatedType]) -> String {
        if associatedTypes.isEmpty {
            return ""
        }
        let conformanceConstraints = conformanceConstraints
        let parameters = associatedTypes
            .map {
                let conformances = [
                    $0.typeName?.name,
                    conformanceConstraints[$0.name]
                ]
                    .compactMap(\.self)
                    .joined(separator: " & ")

                return "\($0.name)\(conformances.isEmpty ? "" : ": \(conformances)")"
            }
        return "<\(parameters.joined(separator: ", "))>"
    }

    var conformanceConstraints: [String: String] {
        typeInfo.genericRequirements
            .filter {
                $0.relationshipSyntax == ":"
            }
            .reduce(into: [:]) { partialResult, requirement in
                partialResult[requirement.leftType.name] = requirement.rightType.typeName.name
            }
    }

    var mockAccessLevel: String {
        typeInfo.accessLevel.rawValue.replacingOccurrences(of: "open", with: "public")
            .trimmingCharacters(in: .whitespaces)
    }

    var mockClassAccessLevel: String {
        typeInfo.accessLevel.rawValue.contains("public") ? "open" : typeInfo.accessLevel.rawValue
    }

    @StringBuilder
    var expectationKeys: String {
        """
            
        enum Methods {
        """
        methods.map(\.definition).indented()
        properties.flatMap(\.definitions).indented()
        subscripts.flatMap(\.definitions).indented()
        """
            }
        """
    }

    func propertyGetterExpectFunction(
        accessLevel: String,
        supportsForwarding: Bool,
        variant: PropertyGetterVariant
    ) -> String {
        let signature = "()\(variant.specifierClause) -> Return"
        let performType: String
        let defaultClause: String
        if supportsForwarding {
            performType = "(_ forwardToOriginal: \(signature))\(variant.specifierClause) -> Return"
            defaultClause = " = { \(variant.defaultForwardInvocation) }"
        } else {
            performType = signature
            defaultClause = ""
        }

        return """
            \(accessLevel) func expect<Return>(
                _ expectation: PropertyExpectation<\(signature)>,
                fileID: String = #fileID,
                filePath: StaticString = #filePath,
                line: UInt = #line,
                column: Int = #column,
                perform: @escaping \(performType)\(defaultClause)
            ) {
                _record(
                    expectation.getterExpectation,
                    fileID,
                    filePath, 
                    line,
                    column,
                    perform
                )
            }
        """
    }

    func propertySetterExpectFunction(
        accessLevel: String,
        supportsForwarding: Bool
    ) -> String {
        let signature = "(_ newValue: Value) -> Void"
        let performType: String
        let defaultClause: String
        if supportsForwarding {
            performType = "(_ forwardToOriginal: \(signature), _ newValue: Value) -> Void"
            defaultClause = " = { $0($1) }"
        } else {
            performType = signature
            defaultClause = " = { _ in }"
        }

        return """
            \(accessLevel) func expect<Value>(
                set expectation: PropertyExpectation<\(signature)>,
                to newValue: Parameter<Value>,
                fileID: String = #fileID,
                filePath: StaticString = #filePath,
                line: UInt = #line,
                column: Int = #column,
                perform: @escaping \(performType)\(defaultClause)
            ) {
                _record(
                    expectation.setterExpectation(newValue.anyParameter),
                    fileID,
                    filePath, 
                    line,
                    column,
                    perform
                )
            }
        """
    }

    @StringBuilder
    func propertyExpectationExpectMethods(
        mockAccessLevel: String,
        supportsForwarding: Bool,
        hasWritableProperties: Bool
    ) -> String {
        let getterVariants: [PropertyGetterVariant] = [
            .init(isAsync: false, isThrowing: false),
            .init(isAsync: false, isThrowing: true),
            .init(isAsync: true, isThrowing: false),
            .init(isAsync: true, isThrowing: true)
        ]

        getterVariants.map { variant in
            propertyGetterExpectFunction(
                accessLevel: mockAccessLevel,
                supportsForwarding: supportsForwarding,
                variant: variant
            )
        }

        if hasWritableProperties {
            propertySetterExpectFunction(
                accessLevel: mockAccessLevel,
                supportsForwarding: supportsForwarding
            )
        }
    }

    @StringBuilder
    var expectations: String {
        let mocksClass = typeInfo.kind == .class
        """
         \(mockAccessLevel) struct MethodExpectation<Signature> {
            \(mockAccessLevel) let expectation: Recorder.Expectation
            
            init(method: MockMethod, parameters: [AnyParameter]) {
                self.expectation = .init(
                    method: method,
                    parameters: parameters
                )
            }
        """

        methods.map {
            "\n" + $0.expectationConstructor(forwarding: mocksClass)
                .indented(2)
        }

        """
        }
        """

        if !properties.isEmpty {
                """
                
                    \(mockAccessLevel) struct PropertyExpectation<Signature> {
                        private let method: MockMethod
                
                        init(method: MockMethod) {
                            self.method = method
                        }
                
                        \(mockAccessLevel) var getterExpectation: Recorder.Expectation {
                            .init(
                                method: method,
                                parameters: []
                            )
                        }
                
                        \(mockAccessLevel) func setterExpectation(_ newValue: AnyParameter) -> Recorder.Expectation {
                            .init(
                                method: method,
                                parameters: [newValue]
                            )
                        }
                    }
                """
            propertyExpectationExpectMethods(
                mockAccessLevel: mockAccessLevel,
                supportsForwarding: mocksClass,
                hasWritableProperties: properties.contains(where: { !$0.isReadOnly })
            )
        }

        if !subscripts.isEmpty {
                """
                
                    \(mockAccessLevel) struct SubscriptExpectation<Signature> {
                        private let method: MockMethod
                        private let parameters: [AnyParameter]
                
                        init(method: MockMethod, parameters: [AnyParameter]) {
                            self.method = method
                            self.parameters = parameters
                        }
                
                        \(mockAccessLevel) var getterExpectation: Recorder.Expectation {
                            .init(
                                method: method,
                                parameters: parameters
                            )
                        }
                
                        \(mockAccessLevel) func setterExpectation(_ newValue: AnyParameter) -> Recorder.Expectation {
                            .init(
                                method: method,
                                parameters: parameters + [newValue]
                            )
                        }
                
                        \(mockAccessLevel) static var `subscript`: \(mockTypeName).SubscriptExpectations { .init() }
                    }
                
                    \(mockAccessLevel) struct SubscriptExpectations {
                """
            subscripts.map {
                "\n" + $0.expectationConstructor()
                    .indented(2)
            }
                """
                    }
                """
        }
    }

    @StringBuilder
    func definition(objcClassNames: Set<String>) -> String {
        ""
        mockTypeDefinition
        expectationKeys.indented()
        expectations.indented()


            """
            
                public let recorder = Recorder()
            
                private let fileID: String
                private let filePath: StaticString
                private let line: UInt
                private let column: Int
            
            """

        if typeInfo.kind == .protocol {
                """
                    public init(
                        fileID: String = #fileID,
                        filePath: StaticString = #filePath,
                        line: UInt = #line,
                        column: Int = #column
                    ) {
                        self.fileID = fileID
                        self.filePath = filePath
                        self.line = line
                        self.column = column
                    }
                """
        }

        let requiredInitializers = typeInfo.implements.values
            .flatMap(\.methods)
            .filter(\.isInitializer)
        + typeInfo.allMethods
            .filter(\.isInitializer)
            .filter(\.isRequired)

        for method in requiredInitializers {
                """
                
                    @available(*, unavailable)
                    \(mockAccessLevel) \("required") \(method.name) {
                        fatalError()
                    }
                """
        }

        let initializers = typeInfo.allMethods.filter(\.isInitializer).unique(by: \.name)
        for method in initializers {
            let mockedMethod = MockedMethod(method, mockTypeName: mockTypeName)
                """
                
                    public \(method.name.dropLast())\(method.parameters.isEmpty ? "" : ", ")
                        fileID: String = #fileID,
                        filePath: StaticString = #filePath,
                        line: UInt = #line,
                        column: Int = #column
                    ) {
                        self.fileID = fileID
                        self.filePath = filePath
                        self.line = line
                        self.column = column
                        self.autoForwardingEnabled = true
                        super.init(\(mockedMethod.forwardedLabeledParameters))
                        self.autoForwardingEnabled = false
                    }
                """
        }

        // Defining default initializer
        if initializers.isEmpty, typeInfo.kind == .class {
                """
                
                    \(mockAccessLevel) init(
                        fileID: String = #fileID,
                        filePath: StaticString = #filePath,
                        line: UInt = #line,
                        column: Int = #column
                    ) {
                        self.fileID = fileID
                        self.filePath = filePath
                        self.line = line
                        self.column = column
                        self.autoForwardingEnabled = true
                        super.init()
                        self.autoForwardingEnabled = false
                    }
                """
        }

        let mocksClass = typeInfo.kind == .class

        if mocksClass {
                """
                
                    public var autoForwardingEnabled: Bool
                
                    public var isEnabled: Bool {
                        !autoForwardingEnabled
                    }
                """
        }

            """
            
                private func _record<P>(
                    _ expectation: Recorder.Expectation, 
                    _ fileID: String,
                    _ filePath: StaticString,
                    _ line: UInt,
                    _ column: Int,
                    _ perform: P
                ) {
                    guard isEnabled else {
                        handleFatalFailure(
                            "Setting expectation on disabled mock is not allowed",
                            fileID: fileID,
                            filePath: filePath,
                            line: line,
                            column: column
                        )            
                    }
                    recorder.record(
                        .init(
                            expectation, 
                            perform,
                            fileID,
                            filePath, 
                            line,
                            column
                        )
                    )
                }
            
                private func _perform(_ method: MockMethod, _ parameters: [Any?] = []) -> Any {
                    let invocation = Invocation(
                        method: method,
                        parameters: parameters
                    )
                    guard let stub = recorder.next() else {
                        handleFatalFailure(
                            "Expected no calls but received `\\(invocation)`", 
                            fileID: fileID,
                            filePath: filePath,
                            line: line,
                            column: column
                        )
                    }
            
                    guard stub.matches(invocation) else {
                        handleFatalFailure(
                            "Unexpected call: expected `\\(stub.expectation)`, but received `\\(invocation)`",
                            fileID: stub.fileID,
                            filePath: stub.filePath,
                            line: stub.line,
                            column: stub.column
                        )
                    }
            
                    defer { recorder.checkVerification() }
                    return stub.perform
                }
            """

        let isObjc = objcClassNames.contains(typeInfo.name)

        methods
            .filter { method in
                !isObjc || !method.method.isAsync
            }
            .map {
                "\n" + $0.implementation(override: mocksClass)
                    .indented(1)
            }

        properties.map {
            "\n" + $0.implementation(override: mocksClass)
                .indented(1)
        }

        subscripts.map {
            "\n" + $0.implementation
                .indented(1)
        }

        methods.unique(by: \.rawSignature)
            .map { "\n" + $0.mockExpect(forwarding: mocksClass) }

        subscripts.map { "\n" + $0.mockExpectGetter }

        subscripts.map { "\n" + $0.mockExpectSetter }
            """
            }
            """
        properties.flatMap {
            MockedProperty($0.property, mockTypeName: mockTypeName, namespacedTypes: namespacedTypes)
                .expectationExtensions(mockClassAccessLevel)
        }
        .map { "\n" + $0 }
    }
}

struct PropertyGetterVariant {
    let isAsync: Bool
    let isThrowing: Bool

    var specifierClause: String {
        switch (isAsync, isThrowing) {
        case (false, false):
            ""
        case (false, true):
            " throws"
        case (true, false):
            " async"
        case (true, true):
            " async throws"
        }
    }

    var defaultForwardInvocation: String {
        switch (isAsync, isThrowing) {
        case (false, false):
            "$0()"
        case (false, true):
            "try $0()"
        case (true, false):
            "await $0()"
        case (true, true):
            "try await $0()"
        }
    }
}

