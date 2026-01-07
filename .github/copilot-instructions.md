# GitHub Copilot Instructions

## Code Style Guidelines

### Comments
- **Avoid redundant comments** that simply restate what the code clearly shows
- Do NOT add comments like:
  - `// Create a variable` before `let variable = value`
  - `// Loop through items` before `for item in items`
  - `// Call the function` before `functionName()`
  - Numbered step comments (1., 2., 3.) that just describe the next line
- DO add comments for:
  - Complex algorithms or business logic that isn't immediately obvious
  - Non-obvious workarounds or edge cases
  - Public API documentation (parameter descriptions, return values, errors)
  - TODO items for incomplete implementations

### MARK Comments
- Use MARK comments sparingly, only when they add meaningful organization to large files
- Avoid MARK comments that simply group a single function or obvious sections
- Good example: `// MARK: - URLSessionDelegate` when implementing multiple delegate methods
- Bad example: `// MARK: - Configuration` when there's only one config function

### Function Documentation
- Use doc comments for public APIs and complex functions
- Include parameter descriptions and return values when they're not obvious from the signature
- Keep documentation concise and focused on what isn't clear from the code itself

## Swift Best Practices
- Prefer Swift's expressive syntax over verbose comments
- Use meaningful variable and function names that make the code self-documenting
- Keep functions focused and single-purpose
- Use guard statements for early returns and validation
- Leverage type safety and Swift's type system
- **Always** use private **extensions** for private helper methods
- Write production grade code from the get-go, avoid placeholder/simple code.
- Follow the Dependency Inversion Principle: apply protocol-oriented programming or use closures for dependencies.
- Prefer method references for DI over wrapping closures
  - Example: `let sut = Greeter(greet: greeterMock.greet)` (avoid `{ [greeterMock] name in try greeterMock.greet(name) }`)
- Mark injected closures `@Sendable` when they cross concurrency boundaries
- Use protocols/classes only for high-cohesion APIs
- Prefer single method structs injected via closures over "kitchen sink" protocols/classes with many unrelated methods

## Testing Guidelines
- Use **Swift Testing** framework instead of XCTest for all new tests
- Prefer `@Test` attribute over XCTest classes
- Use `#expect` and `#require` macros instead of XCTAssert* functions
- Leverage parameterized tests with `@Test(arguments:)` for testing multiple inputs
- Use `@Suite` to organize related tests logically
- Use descriptive test names that clearly state: 
  - what is being tested
  - under what conditions
  - what the expected outcome is
- Use `throws` on test functions instead of wrapping in do-catch with XCTFail
- One lazy SUT, suite-level mocks; do not rebuild/reassign `sut` inside tests
  - Example:
    - `let greeterMock = GreeterMock()`
    - `lazy var sut = Greeter(greet: greeterMock.greet)`
- Use `final class` instead of `struct` to avoid mutability errors only when using lazy vars, otherwise prefer `struct`
- Marking suite properties private is not necessary; avoid excessive `private` usage in tests
- Use `#expect(throws:)` instead of do-catch for error testing
- Leverage async tests naturally with async/await syntax
- **One test suite per file** - each file should contain only one `@Suite`
- Separate test concerns into different files (e.g., DTO tests, endpoint tests, service tests)
- Name test files to match their suite focus (e.g., `FooEndpointTests.swift`, `FooDTOTests.swift`)
- **Always validate** the results including thrown errors; `_ = try? sut.method()` is unacceptable
- Avoid multiple `#expect` calls on the same result object, use inline expected results
  - Instead of:
    ```swift
    let result = try sut.method()
    #expect(result.property1 == expected1)
    #expect(result.property2 == expected2)
    ```
  - Do:
    ```swift
    let result = try sut.method()
    #expect(result == ExpectedType(property1: expected1, property2: expected2))
    ```
- Avoid multiple `#expect` calls for arrays and dictionaries; compare the entire collection at once
  - Instead of:
    ```swift
    let result = try sut.method()
    #expect(result.count == 3)
    #expect(result[0] == expected0)
    #expect(result[1] == expected1)
    #expect(result[2] == expected2)
    ```
  - Do:
    ```swift
    let result = try sut.method()
    #expect(result == [expected0, expected1, expected2])
    ```
- Don't use `contains()` for asserting array contents; compare full arrays instead
  - Instead of:
    ```swift
    let result = try sut.method()
    #expect(result.contains(expectedValue))
    ```
  - Do:
    ```swift
    let result = try sut.method()
    #expect(result == [expectedValue1, expectedValue2, ...])
    ```

### Test case naming conventions 
Use descriptive test names that clearly state: 
  - what is being tested
  - under what conditions
  - what the expected outcome is

The pattern is:
```
@Test
func `functionName expectedResult condition`()
```

Examples:
  - Good: `@Test func `greet throws on invalid name`()`
  - Bad: `@Test func testDevice()`

### Swift Testing vs XCTest Migration
- Replace `XCTestCase` classes with `@Suite` structs
- Replace `XCTAssertEqual(a, b)` with `#expect(a == b)`
- Replace `XCTAssertTrue(condition)` with `#expect(condition)`
- Replace `XCTAssertFalse(condition)` with `#expect(!condition)`
- Replace `XCTAssertNil(value)` with `#expect(value == nil)`
- Replace `XCTAssertNotNil(value)` with `#expect(value != nil)`
- Replace `XCTAssertThrowsError` with `#expect(throws:)`
- Replace `XCTAssertThrowsError(try f()) { error in … }` with `let error = #require(throws: MyError.self) { try f() }`
- Replace `XCTUnwrap(value)` with `try #require(value)`

## Important documentation:
- Search package dependency API and documentations in the `.build/checkouts/`

## Running Tests
- Unit tests: `swift test`
- End-to-end: `cd PluginTests && xcodebuild test -scheme PluginTests-Package -destination "platform=macOS,arch=arm64"`