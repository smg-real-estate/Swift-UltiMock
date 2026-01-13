[![CI](https://github.com/smg-real-estate/Swift-UltiMock/actions/workflows/ci.yml/badge.svg)](https://github.com/smg-real-estate/Swift-UltiMock/actions/workflows/ci.yml)

# UltiMock

A fast mock-generation tool for Swift.

## Overview

**UltiMock** generates mocks based on protocols.
It was greatly inspired by [SwiftyMocky](https://github.com/MakeAWishFoundation/SwiftyMocky).

Originally based on [Sourcery](https://github.com/krzysztofzablocki/Sourcery), it now uses [SwiftSyntax](https://github.com/apple/swift-syntax) for parsing source code and generates the mocks directly in Swift without any template languages. 

This makes it ⚡️ fast and suitable for running as a Swift Package build plugin.

It also uses [SourceKitten](https://github.com/jpsim/SourceKitten) for generating Swift interfaces 
for Swift and Objective-C frameworks, which allows generating mocks for SDK protocols. 

Works with **XCTest** and **Swift Testing**.

## Key features

* Generating mocks from command-line and Swift Package build plugin
* Supports mocking of:
    - methods and properties
    - **generics** and **associated types**
    - **async** and **throwing** (including **typed throws**)
    - Swift Package dependencies
    - Swift and Objective-C framework interfaces
* Simple and concise interface: just `expect` and `verify`
* Resetting expectations
* Respects expectations order

## Getting started

1. Annotate the protocols you need to mock:
```swift
// UltiMock:AutoMockable
extension MyProtocol {}
```

2. Create `mock.json` configuration file in your test target directory.

```json
{
    "sources": ["."],
    "packageDependencies": ["MyLibrary"],
    "sdkModules" : ["CoreLocation.CLLocationManager"],
    "imports": ["CoreLocation"],
    "testableImports": ["MyApp"],
    "enableSourceryAnnotation": true
}
```

### Configuration options

| Option | Description |
| --- | --- |
| `sources` | A list of directories or files to scan for annotated protocols. Paths are relative to the `mock.json` file. |
| `packageDependencies` | A list of Swift Package dependencies to scan for annotated protocols. These are also automatically added to the imports. |
| `sdkModules` | A list of SDK modules to generate interfaces for. This allows mocking of system types like `CLLocationManager`. |
| `imports` | A list of modules to import in the generated mock file. |
| `testableImports` | A list of modules to import as `@testable` in the generated mock file. |
| `enableSourceryAnnotation` | If `true`, the tool will also look for `// sourcery:AutoMockable` annotations, providing compatibility with Sourcery-based projects. |
| `output` | (Optional) Path to the output file. Defaults to `Mock.generated.swift`. |

3. Add `UltiMock` package plugin to your `Package.swift`:
```swift
    dependencies: [
        .package(name: "UltiMock", url: "https://github.com/smg-real-estate/Swift-UltiMock", from: "0.6.2"),
    ],
    targets: [
        .testTarget(
            name: "MyAppTests",
            plugins: [
                .plugin(name: "MockGenerationPlugin", package: "UltiMock")
            ]
        )
    ]
```
To reduce compiling times and avoid conflicts with macro packages you can use a binary version instead:
```swift
    dependencies: [
        .package(name: "UltiMock", url: "https://github.com/smg-real-estate/Swift-UltiMock-Binary", from: "0.6.2"),
    ],
```

4. Use the generated mocks in your tests:
```swift
let storageMock = TextStorageMock()

// ---
storageMock.expect(.loadText(from: .value("filename"))) { "Lorem ipsum" // Stub return value in perform closure }

XCTAssertEqual(sut.text, "Lorem ipsum")

// This will fail if any expectations left unfulfilled
storageMock.verify()

```

## Expectation parameters

### Equatable parameters
For `Equatable` parameters you can use `value()` constructor: 
```swift
mock.expect(.loadText(from: .value("filename"))) { "Lorem ipsum" // Stub return value in perform closure }
```
The mock will automatically check if the passed value is equal to the expected one.

### Literals
For many `Equatable` types expressible by a literal you can use the literal value as an expectation parameter directly:
```swift
mock.expect(.loadText(from: "filename")) { "Lorem ipsum" }
mock.expect(.saveItems(["A", "B", "C"]))  
mock.expect(.saveItems(["A" : 1, "B" : 2]))  
```

### Reference-type parameters
For checking the identity of a reference type you may use `identical(to:)` parameter constructor:
```swift
// Making sure we're presenting the same view controller instance
mock.expect(.present(.identical(to: viewController)))
```

### Optionals
For checking if an optional value is `nil` or non-`nil` you may use a `nil` literal, `isNil` or `isNotNil` parameter constructors:
```swift
mock.expect(.present(.identical(to: viewController, completion: nil)))
// or
mock.expect(.present(.identical(to: viewController, completion: .isNil)))

mock.expect(.present(.identical(to: viewController, completion: .isNotNil))) { _, completion in
    completion()
    // Verifying the completion behavior
}
```

### Custom matchers
For non-`Equatable` types or in some other cases you may use `matching()` parameter constructor: 
```swift
// Matching a tuple value
mock.expect(.doSomething(withTuple: .matching { value /*(String, String)*/ in
    value.0 == "A" && value.1 == "B"
}))
```

### Wild-card matchers
When it's not possible to reliably match a parameter, such as when the parameter is a closure, 
or when the parameter does not matter, you can use a wild-card `any` parameter constructor:
```swift
mock.expect(.requestPermission(completion: .any))
``` 

When the parameter is generic you can explicitly specify its type:
```swift
mock.expect(.encode(.any(String.self)))
``` 

## Property expectations
**UltiMock** supports both getter and setter property expectations.

A getter expectation is similar to a method expectation without parentheses:
```swift
mock.expect(.count) { 3 }
``` 

A setter expectation has a dedicated constructor:
```swift
mock.expect(set: .count, to: 3)
``` 

## Subscript expectations
Just like the properties, **UltiMock** supports both getter and setter subscript expectations.

A getter expectation is similar to a method expectation but uses a `subscript` accessor property 
and an actual subscript syntax:
```swift
mock.expect(.subscript[3]) { _ in "3" }
// same as:
mock.expect(.subscript[.value(3)]) { _ in "3" }
``` 

A setter expectation has a dedicated constructor:
```swift
mock.expect(set: .subscript[3], to: "3")
// same as:
mock.expect(set: .subscript[.value(3)], to: .value("3")) { key, newValue in }
``` 

## Expectation perform closure
You may use a perform closure for stubbing a return value or for other needs:
```swift
mock.expect(.present(.identical(to: viewController, completion: .isNotNil))) { _, completion in
    completion()
    // Verifying the completion behavior
}
```

Typed throws are also supported:
```swift
mock.expect(.doSomething()) { () throws(MyError) in
    throw .someError
}
```

Note: The perform closure is optional for methods without a return value.

## Resetting expectations
You can reset mock's expectations by calling `resetExpectations()` method.
