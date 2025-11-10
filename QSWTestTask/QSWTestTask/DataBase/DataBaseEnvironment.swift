//
//  DataBaseEnvironment.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 28.09.2025.
//

import SwiftUI
import SomeDB

private struct DatabaseKey: EnvironmentKey {
    static let defaultValue: SomeDB<String> = SomeDB(initialRoots: [])
}

extension EnvironmentValues {
    var db: SomeDB<String> {
        get { self[DatabaseKey.self] }
        set { self[DatabaseKey.self] = newValue }
    }
}
