//
//  ThrowingIteratorProtocol.swift
//  UltiMock
//
//  Created by Mykola Tarbaiev on 21.11.25.
//


public protocol ThrowingIteratorProtocol<Element> {
    associatedtype Element

    mutating func next() throws -> Element?
}

public protocol ThrowingSequence<Element> {
    associatedtype Element
    associatedtype ThrowingIterator: ThrowingIteratorProtocol<Element>

    func makeThrowingIterator() -> ThrowingIterator
}

struct ResultSequence<Base: ThrowingSequence>: Sequence {
    fileprivate let base: Base

    func makeIterator() -> Iterator {
        Iterator(throwingIterator: base.makeThrowingIterator())
    }

    struct Iterator: IteratorProtocol {
        private(set) var throwingIterator: Base.ThrowingIterator

        mutating func next() -> Result<Base.Element, Error>? {
            do {
                return try throwingIterator.next()
                    .map { .success($0) }
            } catch {
                return .failure(error)
            }
        }
    }
}

extension ThrowingSequence {
    func asSequence() -> ResultSequence<Self> {
        ResultSequence(base: self)
    }

    func map(transform: @escaping (Element) throws -> Element) -> ThrowingMapSequence<Self, Element> {
        ThrowingMapSequence(base: self, transform: transform)
    }

    func map<T>(transform: @escaping (Element) -> T) throws -> [T] {
        var iterator = makeThrowingIterator()
        var results: [T] = []
        while let element = try iterator.next() {
            results.append(transform(element))
        }
        return results
    }

    func flatMap<T>(transform: @escaping (Element) -> [T]) throws -> [T] {
        try map(transform: transform)
            .flatMap { $0 }
    }
}

struct ResultUnwrappingSequence<Base: Sequence<Result<Element, Error>>, Element>: ThrowingSequence  {
    fileprivate let base: Base

    func makeThrowingIterator() -> ThrowingIterator {
        ThrowingIterator(baseIterator: base.makeIterator())
    }

    struct ThrowingIterator: ThrowingIteratorProtocol {
        fileprivate var baseIterator: Base.Iterator

        mutating func next() throws -> Element? {
            guard let result = baseIterator.next() else {
                return nil
            }
            return try result.get()
        }
    }
}

struct ThrowingMapSequence<Base: ThrowingSequence, Element>: ThrowingSequence {
    fileprivate let base: Base
    fileprivate let transform: (Base.Element) throws -> Element

    struct ThrowingIterator: ThrowingIteratorProtocol {
        private var baseIterator: Base.ThrowingIterator
        private let transform: (Base.Element) throws -> Element

        init(baseIterator: Base.ThrowingIterator, transform: @escaping (Base.Element) throws -> Element) {
            self.baseIterator = baseIterator
            self.transform = transform
        }

        mutating func next() throws -> Element? {
            guard let element = try baseIterator.next() else {
                return nil
            }
            return try transform(element)
        }
    }

    func makeThrowingIterator() -> ThrowingIterator {
        ThrowingIterator(
            baseIterator: base.makeThrowingIterator(),
            transform: transform
        )
    }
}

extension Sequence {
    func map(transform: @escaping (Element) throws -> Element) -> some ThrowingSequence<Element> {
        ResultUnwrappingSequence(base: map { element in
            Result<Element, Error> {
                try transform(element)
            }
        })
    }

    func compactMap<T>(transform: @escaping (Element) throws -> T?) -> some ThrowingSequence<T> {
        ResultUnwrappingSequence(base: compactMap { element in
            do {
                return try transform(element).map { .success($0) }
            } catch {
                return .failure(error)
            }
        })
    }
}

extension LazySequence {
    func map(transform: @escaping (Element) throws -> Element) -> some ThrowingSequence<Element> {
        ResultUnwrappingSequence(base: map { element in
            Result<Element, Error> {
                try transform(element)
            }
        })
    }

    func compactMap<T>(transform: @escaping (Element) throws -> T?) -> some ThrowingSequence<T> {
        ResultUnwrappingSequence(base: compactMap { element in
            do {
                return try transform(element).map { .success($0) }
            } catch {
                return .failure(error)
            }
        })
    }
}

extension LazyMapSequence {
    func map(transform: @escaping (Element) throws -> Element) -> some ThrowingSequence<Element> {
        ResultUnwrappingSequence(base: map { element in
            Result<Element, Error> {
                try transform(element)
            }
        })
    }

    func compactMap<T>(transform: @escaping (Element) throws -> T?) -> some ThrowingSequence<T> {
        ResultUnwrappingSequence(base: compactMap { element in
            do {
                return try transform(element).map { .success($0) }
            } catch {
                return .failure(error)
            }
        })
    }
}
