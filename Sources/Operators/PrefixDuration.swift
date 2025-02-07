//
//  PrefixDuration.swift
//  CombineExt
//
//  Created by David Ohayon and Jasdev Singh on 24/04/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

#if !(os(iOS) && (arch(i386) || arch(arm)))
import OpenCombine
import Foundation

public extension Publisher {
    /// Republishes elements for a specified duration.
    ///
    /// - parameters:
    ///   - duration: The time interval during which to accept value or completion events.
    ///   - tolerance: The tolerance the underlying timer.
    ///   - scheduler: The scheduler for the underlying timer.
    ///   - options: The scheduler options for the underlying timer.
    ///
    /// - returns: A publisher that republishes up to the specified duration.
    func prefix<S: OpenCombine.Scheduler>(
        duration: S.SchedulerTimeType.Stride,
        tolerance: S.SchedulerTimeType.Stride? = nil,
        on scheduler: S,
        options: S.SchedulerOptions? = nil
    ) -> AnyPublisher<Output, Failure> {
        prefix(
            untilOutputFrom: Publishers.Timer(
                every: duration,
                tolerance: tolerance,
                scheduler: scheduler,
                options: options
            )
            .autoconnect()
        )
        .eraseToAnyPublisher()
    }
}
#endif
