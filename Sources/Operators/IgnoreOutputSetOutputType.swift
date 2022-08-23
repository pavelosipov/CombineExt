//
//  IgnoreOutputSetOutputType.swift
//  CombineExt
//
//  Created by Jasdev Singh on 02/09/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import OpenCombine

public extension Publisher {
    /// An `ignoreOutput` overload that allows for setting a new output type.
    ///
    /// - parameter setOutputType: The new output type for downstream.
    ///
    /// - returns: A publisher that ignores upstream value events and sets its output generic to `NewOutput`.
    func ignoreOutput<NewOutput>(setOutputType newOutputType: NewOutput.Type) -> Publishers.Map<Publishers.IgnoreOutput<Self>, NewOutput> {
        ignoreOutput().map { _ -> NewOutput in }
    }
}
