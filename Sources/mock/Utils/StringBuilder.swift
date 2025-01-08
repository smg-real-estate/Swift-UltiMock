import Foundation

@resultBuilder
enum StringBuilder {
    static func buildBlock(_ components: [String]...) -> [String] {
        components.flatMap { $0 }
    }

    static func buildExpression(_ component: [String]) -> [String] {
        component
    }

    static func buildExpression(_ component: String) -> [String] {
        [component]
    }

    static func buildOptional(_ component: [String]?) -> [String] {
        component ?? []
    }

    static func buildEither(first component: [String]) -> [String] {
        component
    }

    static func buildEither(second component: [String]) -> [String] {
        component
    }

    static func buildArray(_ components: [[String]]) -> [String] {
        components.flatMap { $0 }
    }

    static func buildFinalResult(_ components: [String]) -> String {
        components.joined(separator: "\n")
    }
}
