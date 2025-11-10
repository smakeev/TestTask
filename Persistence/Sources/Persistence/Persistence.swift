import Foundation
import OSLog
import Foundation
import SomeDB
import SomeCache


/// Shared logger for the `Persistence` module.
public enum PersistenceLogger {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Persistence", category: "Persistence")

    public static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    public static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }

    public static func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }
}

public actor PersistenceManager {
    private let dbPath: URL
    private let cachePath: URL
    private let fm = FileManager.default

    public init(baseName: String = "PersistenceData") {
        let baseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = baseDir.appendingPathComponent("QSWTestTask", isDirectory: true)
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
        dbPath = folder.appendingPathComponent("\(baseName)_db.json")
        cachePath = folder.appendingPathComponent("\(baseName)_cache.json")
    }

    // MARK: - Focused save helpers (DB-only / Cache-only)

    // MARK: - Save Database
    public func saveDatabase(_ db: SomeDB<String>) async {
        let exported = await db.export()  // Returns [DBRow<String>]
        do {
            let data = try JSONEncoder().encode(exported)
            try data.write(to: dbPath, options: .atomic)
            PersistenceLogger.info("💾 Database saved to \(dbPath.lastPathComponent)")
        } catch {
            PersistenceLogger.error("⚠️ Failed to save database: \(error)")
        }
    }

    // MARK: - Save Cache
    public func saveCache(_ cache: SomeCache<String>) async {
        let exported = await cache.export() // [CacheNode<String>]
        do {
            let data = try JSONEncoder().encode(exported)
            try data.write(to: cachePath, options: .atomic)
            PersistenceLogger.info("💾 Cache saved to \(cachePath.lastPathComponent)")
        } catch {
            PersistenceLogger.error("⚠️ Failed to save cache: \(error)")
        }
    }

    /// Save only the DB snapshot (array of DBRow) to disk.
    public func saveDBSnapshot(_ roots: [DBRow<String>]) {
        do {
            let data = try JSONEncoder().encode(roots)
            try data.write(to: dbPath)
            PersistenceLogger.info("DB snapshot saved")
        } catch {
            PersistenceLogger.error("Failed to save DB snapshot: \(error)")
        }
    }

    /// Save only the Cache snapshot (array of CacheNode) to disk.
    public func saveCacheSnapshot(_ nodes: [CacheNode<String>]) {
        do {
            let codable = nodes.map { CodableCacheNode(from: $0) }
            let data = try JSONEncoder().encode(codable)
            try data.write(to: cachePath)
            PersistenceLogger.info("Cache snapshot saved")
        } catch {
            PersistenceLogger.error("Failed to save Cache snapshot: \(error)")
        }
    }

    // MARK: - Save

    public func save(db: SomeDB<String>, cache: SomeCache<String>) async {
        let dbData = await db.export()
        let cacheData = await cache.export()
        do {
            try JSONEncoder().encode(dbData).write(to: dbPath)
            try JSONEncoder().encode(cacheData).write(to: cachePath)
            PersistenceLogger.info("💾 Persistence saved successfully")
        } catch {
            PersistenceLogger.error("❌ Persistence save failed: \(error)")
        }
    }

    // MARK: - Load

    public func loadDB() async -> [DBRow<String>]? {
        guard fm.fileExists(atPath: dbPath.path) else { return nil }
        do {
            let data = try Data(contentsOf: dbPath)
            return try JSONDecoder().decode([DBRow<String>].self, from: data)
        } catch {
            PersistenceLogger.error("⚠️ Failed to load DB from persistence: \(error)")
            return nil
        }
    }

    // MARK: - Load Cache
    public func loadCache() async -> SomeCache<String>? {
        guard fm.fileExists(atPath: cachePath.path) else { return nil }
        do {
            let data = try Data(contentsOf: cachePath)
            let nodes = try JSONDecoder().decode([CodableCacheNode<String>].self, from: data).map { $0.toNode() }
            let cache = SomeCache<String>()
            await cache.restore(from: nodes)
            PersistenceLogger.info("📦 Cache restored successfully from persistence")
            return cache
        } catch {
            PersistenceLogger.error("⚠️ Failed to load cache: \(error)")
            return nil
        }
    }

    // MARK: - Reset

    public func reset() {
        try? fm.removeItem(at: dbPath)
        try? fm.removeItem(at: cachePath)
        PersistenceLogger.info("🧹 Persistence reset complete")
    }

}
