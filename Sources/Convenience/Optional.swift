//
//  Optional.swift
//  CombineExt
//
//  Created by Jasdev Singh on 11/05/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import OpenCombine

public extension Optional {
    /// A publisher that publishes an optional value to each subscriber exactly once, if the optional has a value.
    @available(OSX, obsoleted: 11.0, message: "Optional.publisher is now part of Combine.")
    @available(iOS, obsoleted: 14.0, message: "Optional.publisher is now part of Combine.")
    @available(tvOS, obsoleted: 14.0, message: "Optional.publisher is now part of Combine.")
    @available(watchOS, obsoleted: 7.0, message: "Optional.publisher is now part of Combine.")
    var publisher: Optional.OCombine.Publisher {
        Optional.OCombine.Publisher(self)
    }
}
