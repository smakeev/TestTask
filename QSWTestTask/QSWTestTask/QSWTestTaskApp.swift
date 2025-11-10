//
//  QSWTestTaskApp.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 25.09.2025.
//

import Combine
import SwiftUI
import SomeCache
import SomeDB
import Persistence

@MainActor
final class AppState: ObservableObject {
    @Published var db: SomeDB<String>? = nil
    @Published var cache = SomeCache<String>()
    let persistence = PersistenceManager()

    func initialize() async {
        await withCheckedContinuation { continuation in
            Task {
                let db = await DatabaseInitializer.makeInitialDatabase(using: self.persistence)
                let cache: SomeCache<String>
                if let loaded = await self.persistence.loadCache() {
                    cache = loaded
                } else {
                    cache = SomeCache<String>()
                }

                await MainActor.run {
                    self.db = db
                    self.cache = cache
                    continuation.resume()
                }
            }
        }
    }
}

@main
struct QSWTestTaskApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            if state.db != nil {
                ContentView(state: state)
            } else {
                ProgressView("Initializing database…")
                    .task {
                        await state.initialize()
                    }
            }
        }
    }
}
