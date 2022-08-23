//
//  OptionalTests.swift
//  CombineExt
//
//  Created by Jasdev Singh on 11/05/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !os(watchOS)
import OpenCombine
import CombineExt
import XCTest

final class OptionalTests: XCTestCase {
    private var subscription: AnyCancellable!

    func testSomeInitialization() {
        var results = [Int]()
        var completion: Subscribers.Completion<Never>?

        subscription = Optional(1)
            .ocombine
            .publisher
            .sink(receiveCompletion: { completion = $0 },
                  receiveValue: { results.append($0) })

        XCTAssertEqual([1], results)
        XCTAssertEqual(.finished, completion)
    }

    func testNoneInitialization() {
        var results = [Int]()
        var completion: Subscribers.Completion<Never>?

        subscription = Optional<Int>.none
            .ocombine
            .publisher
            .sink(receiveCompletion: { completion = $0 },
                  receiveValue: { results.append($0) })

        XCTAssertTrue(results.isEmpty)
        XCTAssertEqual(.finished, completion)
    }
}
#endif
