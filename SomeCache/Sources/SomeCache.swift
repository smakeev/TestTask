//
//  SomeCache.swift
//  SomeCache
//
//  Created by Sergey Makeev on 28.09.2025.
//
import Foundation
import SwiftUI
import OSLog

/// Shared logger for the `SomeCache` module.
public enum SomeCacheLogger {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SomeCache", category: "SomeCache")

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

/// State of a cached node.
public enum CacheState {
    case unchanged
    case new
    case modified
    case deleted
}

/// Reference type representing a node in the cache.
public class CacheNode<Value: Sendable> {
    public var id: UUID
    public var value: Value
    public weak var parent: CacheNode<Value>?
    public var expectedParentId: UUID?
    public var children: [CacheNode<Value>]

    /// Operational state for Apply.
    public var state: CacheState

    /// Permanent deletion flag.
    public var isDeleted: Bool

    public init(
        id: UUID,
        value: Value,
        parent: CacheNode<Value>? = nil,
        state: CacheState = .unchanged,
        isDeleted: Bool = false,
        expectedParentId: UUID? = nil
    ) {
        self.id = id
        self.value = value
        self.parent = parent
        self.children = []
        self.state = state
        self.isDeleted = isDeleted
        self.expectedParentId = expectedParentId
    }

    public func addChild(_ child: CacheNode<Value>) {
        children.append(child)
        child.parent = self
        child.expectedParentId = nil
    }

    /// for future to add move
    public func detachFromParent() {
        parent?.children.removeAll { $0 === self }
        parent = nil
    }
}

/// Actor managing a cache of nodes.
public actor SomeCache<Value: Sendable> {
    /// Elements with perent not  added to cache are treeted as roots
    public private(set) var roots: [CacheNode<Value>] = []
    private var index: [UUID: CacheNode<Value>] = [:]

    /// Track modified, new, or deleted nodes for Apply.
    private var dirty: Set<CacheNode<Value>> = []

    public init() {}

    public var hasPendingChanges: Bool { !dirty.isEmpty }

    // MARK: - CRUD.

    /// Insert a node (from DB).
    public func insertNode(id: UUID, value: Value, parentId: UUID?) {
        if let existing = index[id] {
            existing.value = value
            existing.state = .unchanged
            existing.isDeleted = false
            return
        }

        let node = CacheNode(id: id, value: value, state: .unchanged, isDeleted: false, expectedParentId: parentId)
        index[id] = node

        if let parentId, let parent = index[parentId] {
            parent.addChild(node) // addChild will set parent for us.
        } else {
            roots.append(node)
        }

        // If some roots were waiting for this node as their parent — adopt them now.
        adoptOrphansRecursively(startingAt: id)
        cleanupRoots()
    }

    /// Create a new node (local only).
    public func createNode(value: Value, parentId: UUID?) -> CacheNode<Value> {
        let node = CacheNode(id: UUID(), value: value, state: .new, isDeleted: false, expectedParentId: parentId)
        // This is a temp. UUID. DB will change it to the actual. New UUID need to be provided to the cache.
        index[node.id] = node

        if let parentId, let parent = index[parentId] {
            parent.addChild(node)
        } else {
            roots.append(node)
        }

        // If this new node will itself be a future parent, adopt any waiting orphans now.
        adoptOrphansRecursively(startingAt: node.id)
        cleanupRoots()
        dirty.insert(node)
        return node
    }

    /// Update the ID of an existing node.
    /// Used after Apply when DB returns a persistent ID.
    public func updateId(oldId: UUID, newId: UUID) {
        guard let node = index.removeValue(forKey: oldId) else { return }
        node.id = newId
        index[newId] = node
        // Re-adopt orphans that were waiting for this node under old temporary id.
        adoptOrphansRecursively(startingAt: newId)
        dirty.insert(node)
    }

    /// Mark node as modified.
    public func modifyNode(id: UUID, newValue: Value) {
        guard let node = index[id] else { return }
        node.value = newValue
        if node.state == .unchanged {
            node.state = .modified
        }
        dirty.insert(node)
    }

    /// Mark node and its descendants as deleted.
    public func deleteNode(id: UUID) {
        guard let node = index[id] else { return }
        if node.state == .new {
            removeNodeCompletely(node)
            cleanupRoots()
            return
        }
        markDeletedRecursive(node)
        cleanupRoots()
    }

    /// Clear all cache data.
    public func clear() {
        roots.removeAll()
        index.removeAll()
        dirty.removeAll()
    }

    /// Add a prepared node into cache (used by converters).
    public func addRoot(_ node: CacheNode<Value>) {
        index[node.id] = node
        roots.append(node)
        cleanupRoots()
    }

    /// Register node in index (used by converters).
    public func registerNode(_ node: CacheNode<Value>) {
        index[node.id] = node
    }

    /// Find a node by ID.
    public func findNode(id: UUID) -> CacheNode<Value>? {
        index[id]
    }

    /// After successful Apply, reset all tracked states.
    public func resetStatesToUnchanged() {
        for node in dirty {
            node.state = .unchanged
        }
        dirty.removeAll()
    }

    /// Return all nodes.
    public func allNodes() -> [CacheNode<Value>] {
        Array(index.values)
    }

    public func allDeleted() -> [CacheNode<Value>] {
        index.values.filter { $0.state == .deleted || $0.isDeleted }
    }

    public func allModified() -> [CacheNode<Value>] {
        Array(dirty)
    }

    public func rootIDs() -> [UUID] {
        // Snapshot of current roots' IDs
        roots.map { $0.id }
    }

    // MARK: - Helpers

    private func cleanupRoots() {
        roots.removeAll { $0.parent != nil }
    }

    /// Adopt orphan roots whose expectedParentId equals `parentId`.
    /// Recursively repeats for newly adopted children, to handle multi-level orphan chains.
    private func adoptOrphansRecursively(startingAt parentId: UUID) {
        guard let parent = index[parentId] else { return }

        // Take all orphan roots that expect this parent
        var adopted: [CacheNode<Value>] = []
        for i in (0..<roots.count).reversed() {
            let candidate = roots[i]
            if candidate.expectedParentId == parentId {
                parent.addChild(candidate)
                roots.remove(at: i)
                adopted.append(candidate)
            }
        }
        // Recursively adopt orphans for each newly adopted child
        for child in adopted {
            adoptOrphansRecursively(startingAt: child.id)
        }
    }

    private func markDeletedRecursive(_ node: CacheNode<Value>) {
        dirty.insert(node)
        node.state = .deleted
        node.isDeleted = true
        for child in node.children {
            if child.state == .new {
                removeNodeCompletely(child)
            } else {
                markDeletedRecursive(child)
            }
        }
    }

    private func removeNodeCompletely(_ node: CacheNode<Value>) {
        dirty.remove(node)
        index.removeValue(forKey: node.id)

        if let parent = node.parent {
            parent.children.removeAll { $0 === node }
        } else {
            roots.removeAll { $0 === node }
        }

        for child in node.children {
            removeNodeCompletely(child)
        }
        node.children.removeAll()
    }
}

extension CacheNode: Hashable {
    public static func == (lhs: CacheNode<Value>, rhs: CacheNode<Value>) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public extension CacheNode {
    var displayColor: Color {
        if isDeleted { return .red }
        switch state {
        case .new: return .green
        case .modified: return .blue
        case .unchanged: return .black
        case .deleted: return .red
        }
    }
}

extension SomeCache where Value: Codable & Sendable {
    public func export() async -> [CodableCacheNode<Value>] {
        roots.map { CodableCacheNode(from: $0) }
    }

    public func importNodes(_ codableNodes: [CodableCacheNode<Value>]) async {
        clear()
        for node in codableNodes {
            addRoot(node.toNode())
        }
    }
}

public extension SomeCache {
    /// Replace current cache content with the given forest of nodes.
    /// Assumes `nodes` form a consistent tree; re-links `parent` and rebuilds the index.
    func restore(from nodes: [CacheNode<Value>]) {
        SomeCacheLogger.info("restore started")
        SomeCacheLogger.debug("1️⃣ clearing cache")
        roots = []
        index = [:]
        dirty.removeAll()

        SomeCacheLogger.debug("2️⃣ copying nodes")
        roots = nodes

        SomeCacheLogger.debug("3️⃣ rebuilding index and reparenting")
        for root in nodes {
            root.parent = nil
            registerSubtree(root)
        }

        SomeCacheLogger.debug("4️⃣ marking dirty")
        for node in index.values {
            switch node.state {
            case .new, .modified, .deleted:
                dirty.insert(node)
            case .unchanged:
                break
            }
        }

        SomeCacheLogger.debug("5️⃣ cleaning up roots")
        cleanupRoots()
        SomeCacheLogger.info("restore finished")
    }

    // MARK: - Private helpers

    /// Recursively index a subtree and fix `parent` links.
    private func registerSubtree(_ node: CacheNode<Value>) {
        index[node.id] = node
        for child in node.children {
            child.parent = node
            registerSubtree(child)
        }
    }
}
