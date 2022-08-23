//
//  ToggleTests.swift
//  CombineExt
//
//  Created by Keita Watanabe on 06/06/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !os(watchOS)
import OpenCombine
import CombineExt
import XCTest

final class ToggleTests: XCTestCase {
    func testSomeInitialization() {
        var results = [Bool]()
        _ = [true, false, true, false, true].publisher
            .toggle()
            .sink { results.append($0) }

        XCTAssertEqual([false, true, false, true, false], results)
    }
}
#endif
