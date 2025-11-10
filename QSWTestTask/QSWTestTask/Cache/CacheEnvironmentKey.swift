//
//  CacheEnvironmentKey.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 29.09.2025.
//

import SwiftUI
import SomeCache

private struct CacheKey: EnvironmentKey {
    static let defaultValue: SomeCache<String> = SomeCache<String>()
}

public extension EnvironmentValues {
    var cache: SomeCache<String> {
        get { self[CacheKey.self] }
        set { self[CacheKey.self] = newValue }
    }
}
