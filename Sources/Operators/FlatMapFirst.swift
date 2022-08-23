//
//  FlatMapFirst.swift
//  CombineExt
//
//  Created by Martin Troup on 22/03/2022.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import OpenCombine
import Foundation

public extension Publisher {
    /// The operator is a special case of `flatMap` operator.
    ///
    /// Like `flatMapLatest`, it only allows one inner publisher at a time. Unlike `flatMapLatest`, it will not cancel an ongoing inner publisher.
    /// Instead it ignores events from the source until the inner publisher is done. It creates another inner publisher only when the previous one is done.
    ///
    /// - Returns: A publisher emitting the values of a single inner publisher at a time (until the inner publisher finishes).
    func flatMapFirst<P: Publisher>(
        _ transform: @escaping (Output) -> P
    ) -> Publishers.FlatMap<Publishers.HandleEvents<P>, Publishers.Filter<Self>>
    where Self.Failure == P.Failure {
        var isRunning = false
        let lock = NSRecursiveLock()

        func set(isRunning newValue: Bool) {
            defer { lock.unlock() }
            lock.lock()

            isRunning = newValue
        }

        return filter { _ in !isRunning }
            .flatMap { output in
                transform(output)
                    .handleEvents(
                        receiveSubscription: { _ in
                            set(isRunning: true)
                        },
                        receiveCompletion: { _ in
                            set(isRunning: false)
                        },
                        receiveCancel: {
                            set(isRunning: false)
                        }
                    )
            }
    }
}
