//
//  DataBaseInitializer.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 28.09.2025.
//

import Foundation
import SomeDB
import Persistence

/// Initializes or resets the in-memory DB used by the app.
/// This file is intended to be generated in the future, so the structure is explicit and stable.
enum DatabaseInitializer {

    // MARK: - File name for the bundled JSON
    private static let jsonFileName = "DBInitial"

    // MARK: - Public API

    /// Create a brand-new database initialized from DBInitial.json
    static func makeInitialDatabase(using pm: PersistenceManager) async -> SomeDB<String> {
        // 1) Try to load a previously persisted snapshot.
        if let persisted = await pm.loadDB() {
            return SomeDB(initialRoots: persisted)
        }
        // 2) Fallback to bundled JSON and persist it for the next launch.
        do {
            let roots = try loadInitialData()
            await pm.saveDBSnapshot(roots)
            return SomeDB(initialRoots: roots)
        } catch {
            assertionFailure("❌ Failed to load DBInitial.json: \(error)")
            // fallback to empty DB
            return SomeDB(initialRoots: [])
        }
    }

    /// Reset an existing DB instance back to the JSON-defined state.
    static func resetDatabase(_ db: SomeDB<String>, using pm: PersistenceManager) async {
        do {
            let roots = try loadInitialData()
            await db.reinitialize(with: roots)
            await pm.saveDBSnapshot(roots)
        } catch {
            assertionFailure("❌ Failed to reset DB from DBInitial.json: \(error)")
            await db.reinitialize(with: [])
            await pm.reset()
        }
    }

    // MARK: - Internal Helpers

    /// Loads and decodes DBInitial.json into `[DBRow<String>]`
    private static func loadInitialData() throws -> [DBRow<String>] {
        guard let url = Bundle.main.url(forResource: jsonFileName, withExtension: "json") else {
            throw NSError(domain: "DatabaseInitializer", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "DBInitial.json not found in bundle"])
        }

        let data = try Data(contentsOf: url)

        // Decode a single root object or array depending on JSON structure
        if let root = try? JSONDecoder().decode(DBRow<String>.self, from: data) {
            return [root]
        } else if let roots = try? JSONDecoder().decode([DBRow<String>].self, from: data) {
            return roots
        } else {
            throw NSError(domain: "DatabaseInitializer", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to decode DBInitial.json"])
        }
    }
}

// MARK: - Codable support for DB structure
extension DBRow: @retroactive Codable where Value: Codable {
    private enum CodingKeys: String, CodingKey {
        case id
        case parentId
        case value
        case isDeleted
        case children
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
        let value = try container.decode(Value.self, forKey: .value)
        let isDeleted = try container.decode(Bool.self, forKey: .isDeleted)
        let children = try container.decodeIfPresent([DBRow<Value>].self, forKey: .children) ?? []

        self = .node(NodeData(
            id: id,
            parentId: parentId,
            value: value,
            isDeleted: isDeleted,
            children: children
        ))
    }
}
