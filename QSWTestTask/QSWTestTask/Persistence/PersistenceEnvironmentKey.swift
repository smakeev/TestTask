//
//  PersistenceEnvironmentKey.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 18.10.2025.
//

import SwiftUI
import Persistence

private struct PersistenceKey: EnvironmentKey {
    static let defaultValue = PersistenceManager()
}

extension EnvironmentValues {
    var persistence: PersistenceManager {
        get { self[PersistenceKey.self] }
        set { self[PersistenceKey.self] = newValue }
    }
}
