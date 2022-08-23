//
//  Merge.swift
//  CombineX
//
//  Copyright © 2019 CombineX. All rights reserved.
//

import OpenCombine

extension Publisher {
    /// Subscribes to an additional publisher and publishes a tuple upon receiving output from either publisher.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still
    /// obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t
    /// `.unlimited`, it drops values from upstream publishers. It implements this by using a buffer size
    /// of 1 for each upstream, and holds the most recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finsh. If an upstream publisher never
    /// publishes a value, this publisher never finishes.
    ///
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    ///
    /// - Parameters:
    ///   - other: Another publisher to combine with this one.
    /// - Returns: A publisher that receives and combines elements from this and another publisher.
    public func combineLatest<P: Publisher>(_ other: P) -> Publishers.CombineLatest<Self, P> where Failure == P.Failure {
        return .init(self, other)
    }

    /// Subscribes to an additional publisher and invokes a closure upon receiving output from either publisher.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still
    /// obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t
    /// `.unlimited`, it drops values from upstream publishers. It implements this by using a buffer size
    /// of 1 for each upstream, and holds the most recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finsh. If an upstream publisher never
    /// publishes a value, this publisher never finishes.
    ///
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    ///
    /// - Parameters:
    ///   - other: Another publisher to combine with this one.
    ///   - transform: A closure that receives the most recent value from each publisher and returns a new value to publish.
    /// - Returns: A publisher that receives and combines elements from this and another publisher.
    public func combineLatest<P: Publisher, T>(_ other: P, _ transform: @escaping (Output, P.Output) -> T) -> Publishers.Map<Publishers.CombineLatest<Self, P>, T> where Failure == P.Failure {
        return self.combineLatest(other).map(transform)
    }
}

extension Publishers.CombineLatest: Equatable where A: Equatable, B: Equatable {}

extension Publishers {

    /// A publisher that receives and combines the latest elements from two publishers.
    public struct CombineLatest<A, B>: Publisher where A: Publisher, B: Publisher, A.Failure == B.Failure {

        public typealias Output = (A.Output, B.Output)

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public init(_ a: A, _ b: B) {
            self.a = a
            self.b = b
        }

        public func receive<S: Subscriber>(subscriber: S) where B.Failure == S.Failure, S.Input == (A.Output, B.Output) {
            let s = Inner(pub: self, sub: subscriber)
            subscriber.receive(subscription: s)
        }
    }
}

private struct CombineLatestState: OptionSet {
    let rawValue: Int

    static let aCompleted = CombineLatestState(rawValue: 1 << 0)
    static let bCompleted = CombineLatestState(rawValue: 1 << 1)

    static let initial: CombineLatestState = []
    static let completed: CombineLatestState = [.aCompleted, .bCompleted]

    var isACompleted: Bool {
        return self.contains(.aCompleted)
    }

    var isBCompleted: Bool {
        return self.contains(.bCompleted)
    }

    var isCompleted: Bool {
        return self == .completed
    }
}

extension Publishers.CombineLatest {

    private final class Inner<S>: Subscription,
        CustomStringConvertible,
        CustomDebugStringConvertible
    where
        S: Subscriber,
        B.Failure == S.Failure,
        S.Input == (A.Output, B.Output) {

        typealias Pub = Publishers.CombineLatest<A, B>
        typealias Sub = S

        let lock = Lock()
        let sub: Sub

        enum Source: Int {
            case a = 1
            case b = 2
        }

        var state: CombineLatestState = .initial

        var childA: Child<A.Output>?
        var childB: Child<B.Output>?

        var outputA: A.Output?
        var outputB: B.Output?

        var demand: Subscribers.Demand = .none

        init(pub: Pub, sub: Sub) {
            self.sub = sub

            let childA = Child<A.Output>(parent: self, source: .a)
            pub.a.subscribe(childA)
            self.childA = childA

            let childB = Child<B.Output>(parent: self, source: .b)
            pub.b.subscribe(childB)
            self.childB = childB
        }

        deinit {
            lock.cleanupLock()
        }

        func request(_ demand: Subscribers.Demand) {
            guard demand > 0 else {
                return
            }
            self.lock.lock()
            if self.state == .completed {
                self.lock.unlock()
                return
            }

            self.demand += demand

            let childA = self.childA
            let childB = self.childB
            self.lock.unlock()

            childA?.request(demand)
            childB?.request(demand)
        }

        func cancel() {
            self.lock.lock()
            self.state = .completed
            let (childA, childB) = self.release()
            self.lock.unlock()

            childA?.cancel()
            childB?.cancel()
        }

        private func release() -> (Child<A.Output>?, Child<B.Output>?) {
            defer {
                self.outputA = nil
                self.outputB = nil

                self.childA = nil
                self.childB = nil
            }
            return (self.childA, self.childB)
        }

        func childReceive(_ value: Any, from source: Source) -> Subscribers.Demand {
            self.lock.lock()
            let action = CombineLatestState(rawValue: source.rawValue)
            if self.state.contains(action) {
                self.lock.unlock()
                return .none
            }

            switch source {
            case .a:
                self.outputA = value as? A.Output
            case .b:
                self.outputB = value as? B.Output
            }

            if self.demand == 0 {
                self.lock.unlock()
                return .none
            }

            switch (self.outputA, self.outputB) {
            case (.some(let a), .some(let b)):
                self.demand -= 1
                self.lock.unlock()
                let more = self.sub.receive((a, b))
                // FIXME: Apple's Combine doesn't strictly support sync backpressure.
                self.lock.lock()
                self.demand += more
                self.lock.unlock()
                return .none
            default:
                self.lock.unlock()
                return .none
            }
        }

        func childReceive(completion: Subscribers.Completion<A.Failure>, from source: Source) {
            let action = CombineLatestState(rawValue: source.rawValue)

            self.lock.lock()
            if self.state.contains(action) {
                self.lock.unlock()
                return
            }

            switch completion {
            case .failure:
                self.state = .completed
                let (childA, childB) = self.release()
                self.lock.unlock()

                childA?.cancel()
                childB?.cancel()
                self.sub.receive(completion: completion)
            case .finished:
                self.state.insert(action)
                if self.state.isCompleted {
                    let (childA, childB) = self.release()
                    self.lock.unlock()

                    childA?.cancel()
                    childB?.cancel()
                    self.sub.receive(completion: completion)
                } else {
                    self.lock.unlock()
                }
            }
        }

        var description: String {
            return "CombineLatest"
        }

        var debugDescription: String {
            return "CombineLatest"
        }

        final class Child<Output>: Subscriber {

            typealias Parent = Inner
            typealias Input = Output
            typealias Failure = A.Failure

            let subscription = LockedAtomic<Subscription?>(nil)
            let parent: Parent
            let source: Source

            init(parent: Parent, source: Source) {
                self.parent = parent
                self.source = source
            }

            func receive(subscription: Subscription) {
                guard self.subscription.setIfNil(subscription) else {
                    subscription.cancel()
                    return
                }
            }

            func receive(_ input: Input) -> Subscribers.Demand {
                guard self.subscription.load() != nil else {
                    return .none
                }
                return self.parent.childReceive(input, from: self.source)
            }

            func receive(completion: Subscribers.Completion<Failure>) {
                guard let subscription = self.subscription.exchange(nil) else {
                    return
                }

                subscription.cancel()
                self.parent.childReceive(completion: completion, from: self.source)
            }

            func cancel() {
                self.subscription.exchange(nil)?.cancel()
            }

            func request(_ demand: Subscribers.Demand) {
                self.subscription.load()?.request(demand)
            }
        }
    }
}

extension Publisher {
    /// Subscribes to two additional publishers and publishes a tuple upon receiving output from any of the
    /// publishers.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still
    /// obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t
    /// `.unlimited`, it drops values from upstream publishers. It implements this by using a buffer size
    /// of 1 for each upstream, and holds the most recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never
    /// publishes a value, this publisher never finishes.
    ///
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with this one.
    ///   - publisher2: A third publisher to combine with this one.
    /// - Returns: A publisher that receives and combines elements from this publisher and two other publishers.
    public func combineLatest<P, Q>(_ publisher1: P, _ publisher2: Q) -> Publishers.CombineLatest3<Self, P, Q> where P: Publisher, Q: Publisher, Failure == P.Failure, P.Failure == Q.Failure {
        return .init(self, publisher1, publisher2)
    }

    /// Subscribes to two additional publishers and invokes a closure upon receiving output from any of the publishers.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still
    /// obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t
    /// `.unlimited`, it drops values from upstream publishers. It implements this by using a buffer size
    /// of 1 for each upstream, and holds the most recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never
    /// publishes a value, this publisher never finishes.
    ///
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with this one.
    ///   - publisher2: A third publisher to combine with this one.
    ///   - transform: A closure that receives the most recent value from each publisher and returns a
    ///   new value to publish.
    /// - Returns: A publisher that receives and combines elements from this publisher and two other publishers.
    public func combineLatest<P, Q, T>(_ publisher1: P, _ publisher2: Q, _ transform: @escaping (Output, P.Output, Q.Output) -> T) -> Publishers.Map<Publishers.CombineLatest3<Self, P, Q>, T> where P: Publisher, Q: Publisher, Failure == P.Failure, P.Failure == Q.Failure {
        return self.combineLatest(publisher1, publisher2).map(transform)
    }

    /// Subscribes to three additional publishers and publishes a tuple upon receiving output from any of the publishers.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still
    /// obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t
    /// `.unlimited`, it drops values from upstream publishers. It implements this by using a buffer size
    /// of 1 for each upstream, and holds the most recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never
    /// publishes a value, this publisher never finishes.
    ///
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with this one.
    ///   - publisher2: A third publisher to combine with this one.
    ///   - publisher3: A fourth publisher to combine with this one.
    /// - Returns: A publisher that receives and combines elements from this publisher and three other publishers.
    public func combineLatest<P, Q, R>(_ publisher1: P, _ publisher2: Q, _ publisher3: R) -> Publishers.CombineLatest4<Self, P, Q, R> where P: Publisher, Q: Publisher, R: Publisher, Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure {
        return .init(self, publisher1, publisher2, publisher3)
    }

    /// Subscribes to three additional publishers and invokes a closure upon receiving output from any of the publishers.
    ///
    /// The combined publisher passes through any requests to *all* upstream publishers. However, it still
    /// obeys the demand-fulfilling rule of only sending the request amount downstream. If the demand isn’t
    /// `.unlimited`, it drops values from upstream publishers. It implements this by using a buffer size
    /// of 1 for each upstream, and holds the most recent value in each buffer.
    ///
    /// All upstream publishers need to finish for this publisher to finish. If an upstream publisher never
    /// publishes a value, this publisher never finishes.
    ///
    /// If any of the combined publishers terminates with a failure, this publisher also fails.
    ///
    /// - Parameters:
    ///   - publisher1: A second publisher to combine with this one.
    ///   - publisher2: A third publisher to combine with this one.
    ///   - publisher3: A fourth publisher to combine with this one.
    ///   - transform: A closure that receives the most recent value from each publisher and returns a
    ///   new value to publish.
    /// - Returns: A publisher that receives and combines elements from this publisher and three other publishers.
    public func combineLatest<P, Q, R, T>(_ publisher1: P, _ publisher2: Q, _ publisher3: R, _ transform: @escaping (Output, P.Output, Q.Output, R.Output) -> T) -> Publishers.Map<Publishers.CombineLatest4<Self, P, Q, R>, T> where P: Publisher, Q: Publisher, R: Publisher, Failure == P.Failure, P.Failure == Q.Failure, Q.Failure == R.Failure {
        return self.combineLatest(publisher1, publisher2, publisher3).map(transform)
    }
}

/// Returns a Boolean value that indicates whether two publishers are equivalent.
///
/// - Parameters:
///   - lhs: A combineLatest publisher to compare for equality.
///   - rhs: Another combineLatest publisher to compare for equality.
/// - Returns: `true` if the corresponding upstream publishers of each combineLatest publisher are
/// equal, `false` otherwise.
extension Publishers.CombineLatest3: Equatable where A: Equatable, B: Equatable, C: Equatable {}

/// Returns a Boolean value that indicates whether two publishers are equivalent.
///
/// - Parameters:
///   - lhs: A combineLatest publisher to compare for equality.
///   - rhs: Another combineLatest publisher to compare for equality.
/// - Returns: `true` if the corresponding upstream publishers of each combineLatest publisher are
/// equal, `false` otherwise.
extension Publishers.CombineLatest4: Equatable where A: Equatable, B: Equatable, C: Equatable, D: Equatable {}

extension Publishers {

    /// A publisher that receives and combines the latest elements from three publishers.
    public struct CombineLatest3<A, B, C>: Publisher where A: Publisher, B: Publisher, C: Publisher, A.Failure == B.Failure, B.Failure == C.Failure {

        public typealias Output = (A.Output, B.Output, C.Output)

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public init(_ a: A, _ b: B, _ c: C) {
            self.a = a
            self.b = b
            self.c = c
        }

        public func receive<S: Subscriber>(subscriber: S) where C.Failure == S.Failure, S.Input == (A.Output, B.Output, C.Output) {
            self.a
                .combineLatest(self.b)
                .combineLatest(self.c)
                .map {
                    ($0.0, $0.1, $1)
                }
                .receive(subscriber: subscriber)
        }
    }

    /// A publisher that receives and combines the latest elements from four publishers.
    public struct CombineLatest4<A, B, C, D>: Publisher where A: Publisher, B: Publisher, C: Publisher, D: Publisher, A.Failure == B.Failure, B.Failure == C.Failure, C.Failure == D.Failure {

        public typealias Output = (A.Output, B.Output, C.Output, D.Output)

        public typealias Failure = A.Failure

        public let a: A

        public let b: B

        public let c: C

        public let d: D

        public init(_ a: A, _ b: B, _ c: C, _ d: D) {
            self.a = a
            self.b = b
            self.c = c
            self.d = d
        }

        public func receive<S: Subscriber>(subscriber: S) where D.Failure == S.Failure, S.Input == (A.Output, B.Output, C.Output, D.Output) {
            self.a
                .combineLatest(self.b)
                .combineLatest(self.c)
                .combineLatest(self.d)
                .map {
                    ($0.0.0, $0.0.1, $0.1, $1)
                }
                .receive(subscriber: subscriber)
        }
    }
}
