import Foundation

@resultBuilder
enum ArrayBuilder<T> {
    static func buildBlock(_ components: T...) -> [T] {
        components
    }

    static func buildBlock(_ components: [T]...) -> [T] {
        components.flatMap(\.self)
    }

    static func buildExpression(_ component: T) -> [T] {
        [component]
    }

    static func buildOptional(_ components: [T]?) -> [T] {
        components ?? []
    }

    static func buildEither(first component: [T]) -> [T] {
        component
    }

    static func buildEither(second component: [T]) -> [T] {
        component
    }

    static func buildArray(_ components: [[T]]) -> [T] {
        components.flatMap(\.self)
    }

    static func buildBlock(_ components: some Sequence<T>) -> [T] {
        Array(components)
    }

    static func buildEither(first component: some Sequence<T>) -> [T] {
        Array(component)
    }

    static func buildEither(second component: some Sequence<T>) -> [T] {
        Array(component)
    }

    static func buildExpression(_ component: some Sequence<T>) -> [T] {
        Array(component)
    }
}
