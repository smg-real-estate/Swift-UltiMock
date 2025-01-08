import Foundation

@resultBuilder
enum ArrayBuilder<T> {
    public static func buildBlock(_ components: T...) -> [T] {
        components
    }

    public static func buildBlock(_ components: [T]...) -> [T] {
        components.flatMap { $0 }
    }

    public static func buildExpression(_ component: T) -> [T] {
        [component]
    }

    public static func buildOptional(_ components: [T]?) -> [T] {
        components ?? []
    }

    public static func buildEither(first component: [T]) -> [T] {
        component
    }

    public static func buildEither(second component: [T]) -> [T] {
        component
    }

    public static func buildArray(_ components: [[T]]) -> [T] {
        components.flatMap { $0 }
    }

    public static func buildBlock(_ components: some Sequence<T>) -> [T] {
        Array(components)
    }

    public static func buildEither(first component: some Sequence<T>) -> [T] {
        Array(component)
    }

    public static func buildEither(second component: some Sequence<T>) -> [T] {
        Array(component)
    }

    public static func buildExpression(_ component: some Sequence<T>) -> [T] {
        Array(component)
    }
}
