//
//  IgnoreOutputSetOutputTypeTests.swift
//  CombineExtTests
//
//  Created by Jasdev Singh on 02/09/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !os(watchOS)
import XCTest
import OpenCombine
import CombineExt

final class IgnoreOutputSetOutputTypeTests: XCTestCase {
    func testIgnoreOutputSetOutputType() {
        let publisher = Just("someString")
            .ignoreOutput(setOutputType: Int.self)
            .eraseToAnyPublisher()

        XCTAssertTrue(type(of: publisher) == AnyPublisher<Int, Never>.self)
    }
}
#endif

