//
//  Toggle.swift
//  CombineExt
//
//  Created by Keita Watanabe on 06/06/2020.
//  Copyright © 2020 Combine Community. All rights reserved.
//

import OpenCombine

public extension Publisher where Output == Bool {
    /// Toggles boolean values emitted by a publisher.
    ///
    /// - returns: A toggled value.
    func toggle() -> Publishers.Map<Self, Bool> {
        map(!)
    }
}
