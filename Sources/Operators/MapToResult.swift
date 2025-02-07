//
//  MapToResult.swift
//  CombineExt
//
//  Created by Yurii Zadoianchuk on 05/03/2021.
//  Copyright © 2021 Combine Community. All rights reserved.
//

import OpenCombine

public extension Publisher {
    /// Transform a publisher with concrete Output and Failure types
    /// to a new publisher that wraps Output and Failure in Result,
    /// and has Never for Failure type
    /// - Returns: A type-erased publiser of type <Result<Output, Failure>, Never>
    func mapToResult() -> AnyPublisher<Result<Output, Failure>, Never> {
        map(Result.success)
            .catch { Just(.failure($0)) }
            .eraseToAnyPublisher()
    }
}
