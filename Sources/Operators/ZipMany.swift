//
//  ZipMany.swift
//  CombineExt
//
//  Created by Jasdev Singh on 16/03/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import OpenCombine

public extension Publisher {
    /// Zips `self` with an array of publishers with the same output and failure types.
    ///
    /// Since there can be any number of `others`, arrays of `Output` values are emitted after zipping.
    ///
    /// - parameter others: The other publishers to zip with.
    ///
    /// - returns: A type-erased publisher with value events from each of the inner publishers zipped together in an array.
    func zip<Others: Collection>(with others: Others)
        -> AnyPublisher<[Output], Failure>
        where Others.Element: Publisher, Others.Element.Output == Output, Others.Element.Failure == Failure {
        ([self.eraseToAnyPublisher()] + others.map { $0.eraseToAnyPublisher() }).zip()
    }

    /// A variadic overload on `Publisher.zip(with:)`.
    func zip<Other: Publisher>(with others: Other...)
        -> AnyPublisher<[Output], Failure> where Other.Output == Output, Other.Failure == Failure {
        zip(with: others)
    }
}

// MARK: - Collection Helpers
public extension Collection where Element: Publisher {
    /// Zip an array of publishers with the same output and failure types.
    ///
    /// Since there can be any number of elements, arrays of `Output` values are emitted after zipping.
    ///
    /// - returns: A type-erased publisher with value events from each of the inner publishers zipped together in an array.
    func zip() -> AnyPublisher<[Element.Output], Element.Failure> {
        var wrapped = map { $0.map { [$0] }.eraseToAnyPublisher() }
        while wrapped.count > 1 {
            wrapped = makeZippedQuads(input: wrapped)
        }
        return wrapped.first?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
    }
}

// MARK: - Private helper
/// Zip an array of input publishers in four-somes.
///
/// - parameter input: An array of publishers
private func makeZippedQuads<Output, Failure: Swift.Error>(
    input: [AnyPublisher<[Output], Failure>]
) -> [AnyPublisher<[Output], Failure>] {
    sequence(
        state: input.makeIterator(),
        next: { it in it.next().map { ($0, it.next(), it.next(), it.next()) } }
    )
    .map { quad in
        // Only one publisher
        guard let second = quad.1 else { return quad.0 }

        // Two publishers
        guard let third = quad.2 else {
            return quad.0
                .zip(second)
                .map { $0.0 + $0.1 }
                .eraseToAnyPublisher()
        }

        // Three publishers
        guard let fourth = quad.3 else {
            return quad.0
                .zip(second, third)
                .map { $0.0 + $0.1 + $0.2 }
                .eraseToAnyPublisher()
        }

        // Four publishers
        return quad.0
            .zip(second, third, fourth)
            .map { $0.0 + $0.1 + $0.2 + $0.3 }
            .eraseToAnyPublisher()
    }
}
