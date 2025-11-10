//
//  SomeDB.swift
//  SomeBD
//
//  Created by Sergey Makeev on 28.09.2025.
//
import Foundation
import OSLog

/// Shared logger for the `SomeDB` module.
public enum SomeDBLogger {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "SomeDBLogger", category: "SomeDBLogger")

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

// MARK: - DB Tree Model based on indirect enum

/// Tree row stored in the database.
/// Modeled as an `indirect enum` to allow recursive tree structure.
public indirect enum DBRow<Value: Sendable>: Sendable, Equatable where Value: Equatable {
    case node(NodeData<Value>)

    public struct NodeData<T: Sendable & Equatable>: Sendable, Equatable {
        public var id: UUID
        public var parentId: UUID?
        public var value: T
        public var isDeleted: Bool
        public var children: [DBRow<T>]
        
        public init(id: UUID, parentId: UUID?, value: T, isDeleted: Bool, children: [DBRow<T>]) {
            self.id = id
            self.parentId = parentId
            self.value = value
            self.isDeleted = isDeleted
            self.children = children
        }
    }

    // Convenience accessors
    public var id: UUID {
        switch self { case .node(let d): return d.id }
    }
    public var parentId: UUID? {
        switch self { case .node(let d): return d.parentId }
    }
    public var value: Value {
        get { switch self { case .node(let d): return d.value } }
        set { switch self { case .node(var d): d.value = newValue; self = .node(d) } }
    }
    public var isDeleted: Bool {
        get { switch self { case .node(let d): return d.isDeleted } }
        set { switch self { case .node(var d): d.isDeleted = newValue; self = .node(d) } }
    }
    public var children: [DBRow<Value>] {
        get { switch self { case .node(let d): return d.children } }
        set { switch self { case .node(var d): d.children = newValue; self = .node(d) } }
    }
}

// MARK: - Helpers

/// A path is an index chain from the roots into nested children.
private typealias Path = [Int]

// MARK: - Database Actor

/// In-memory tree database with transactional deletion semantics.
///
/// - Generic over `Value`.
/// - Actor provides concurrency safety.
/// - Records are modeled as an indirect enum (`DBRow<Value>`).
/// - Supports reinitialization at any time.
/// - "Delete" is logical (`isDeleted`). During a transaction, cascade to children is deferred until commit.
public actor SomeDB<Value: Sendable & Equatable> {

    // MARK: Storage

    public private(set) var roots: [DBRow<Value>] = []
    private var index: [UUID: Path] = [:]
    private var inTransaction: Bool = false

    // MARK: Init

    public init(initialRoots: [DBRow<Value>] = []) {
        self.roots = initialRoots
        self.inTransaction = false
        self.index = Self.buildIndex(for: initialRoots)
    }

    // MARK: Public API

    /// Reinitialize the database with a brand new forest.
    public func reinitialize(with newRoots: [DBRow<Value>]) {
        self.roots = newRoots
        self.inTransaction = false
        self.index = Self.buildIndex(for: newRoots)
    }

    /// Start a transaction. During a transaction, deletion marks only the node itself.
    public func startTransaction() {
        self.inTransaction = true
    }

    /// Commit a transaction. Cascades deletions through all descendants of nodes marked as deleted.
    public func commitTransaction() {
        guard inTransaction else { return }

        func traverse(_ path: Path) {
            guard let node = getNode(at: path) else { return }
            switch node {
            case .node(let d):
                // if current node is deleted, d ocascade for all it's children
                if d.isDeleted {
                    cascadeDeletionIfNeeded(at: path)
                }

                for (i, _) in d.children.enumerated() {
                    traverse(path + [i])
                }
            }
        }
        SomeDBLogger.info("🚀 commitTransaction started")
        for rIndex in roots.indices {
            traverse([rIndex])
        }
        inTransaction = false
        SomeDBLogger.info("✅ commitTransaction finished")
    }

    /// Get a node by id if effectively not deleted.
    public func getNonDeleted(by id: UUID) -> DBRow<Value>? {
        guard let path = index[id],
              let node = getNode(at: path)
        else { return nil }
        return isEffectivelyDeleted(path) ? nil : node
    }

    /// Update a node's value by id. Returns true if updated.
    @discardableResult
    public func updateValue(id: UUID, to newValue: Value) -> Bool {
        guard let path = index[id],
              !isEffectivelyDeleted(path)
        else { return false }
        if var node = getNode(at: path) {
            node.value = newValue
            setNode(at: path, to: node)
            return true
        }
        return false
    }

    // This will not be used in this task.
    public func createRoot(value: Value) -> UUID {
        let newId = UUID()
        let root = DBRow<Value>.node(.init(id: newId,
                                           parentId: nil,
                                           value: value,
                                           isDeleted: false,
                                           children: []))
        roots.append(root)
        index[newId] = [roots.count - 1]
        return newId
    }

    /// Create a child under a parent node. Returns the child's id if created.
    @discardableResult
    public func createChild(under parentId: UUID, value: Value) -> UUID? {
        guard let path = index[parentId],
              !isEffectivelyDeleted(path)
        else { return nil }
        let newId = UUID()
        let child = DBRow<Value>.node(.init(id: newId, parentId: parentId, value: value, isDeleted: false, children: []))
        if var parent = getNode(at: path) {
            var children = parent.children
            children.append(child)
            parent.children = children
            setNode(at: path, to: parent)
            index[newId] = path + [children.count - 1]
            return newId
        }
        return nil
    }

    public func isDeleted(id: UUID) -> Bool {
        guard let path = index[id] else { return false }
        return isEffectivelyDeleted(path)
    }

    /// Logically delete a node by id. Cascades immediately if not in a transaction.
    @discardableResult
    public func delete(id: UUID) -> Bool {
        guard let path = index[id] else { return false }
        if var node = getNode(at: path) {
            if node.isDeleted { return true }
            node.isDeleted = true
            setNode(at: path, to: node)
            if !inTransaction {
                cascadeDeletionIfNeeded(at: path)
            }
            return true
        }
        return false
    }

    public func isAncestor(_ ancestorId: UUID, of descendantId: UUID) -> Bool {
        // Use the internal index of paths: ancestor path must be a prefix of descendant path
        guard let a = index[ancestorId], let d = index[descendantId] else { return false }
        guard d.count > a.count else { return false }
        return Array(d.prefix(a.count)) == a
    }

    // MARK: - Index builder (nonisolated)

    nonisolated private static func buildIndex(for roots: [DBRow<Value>]) -> [UUID: Path] {
        var newIndex: [UUID: Path] = [:]
        for (i, root) in roots.enumerated() {
            register(node: root, at: [i], into: &newIndex)
        }
        return newIndex
    }

    nonisolated private static func register(node: DBRow<Value>, at path: Path, into index: inout [UUID: Path]) {
        index[node.id] = path
        switch node {
        case .node(let d):
            for (i, child) in d.children.enumerated() {
                register(node: child, at: path + [i], into: &index)
            }
        }
    }

    // MARK: - Tree mutation helpers

    private func getNode(at path: Path) -> DBRow<Value>? {
        guard !path.isEmpty else { return nil }
        var current: DBRow<Value>? = nil
        for (depth, idx) in path.enumerated() {
            if depth == 0 {
                guard roots.indices.contains(idx) else { return nil }
                current = roots[idx]
            } else {
                guard let cur = current,
                      case .node(let d) = cur,
                      d.children.indices.contains(idx)
                else { return nil }
                current = d.children[idx]
            }
        }
        return current
    }

    private func setNode(at path: Path, to newNode: DBRow<Value>) {
        func setIn(_ list: inout [DBRow<Value>], depth: Int) {
            let idx = path[depth]
            if depth == path.count - 1 {
                list[idx] = newNode
                return
            }
            switch list[idx] {
            case .node(var d):
                var childList = d.children
                setIn(&childList, depth: depth + 1)
                d.children = childList
                list[idx] = .node(d)
            }
        }
        var rootsCopy = roots
        setIn(&rootsCopy, depth: 0)
        roots = rootsCopy
    }

    private func isEffectivelyDeleted(_ path: Path) -> Bool {
        var curPath: Path = []
        for (depth, idx) in path.enumerated() {
            curPath.append(idx)
            guard let node = getNode(at: curPath) else { return true }
            switch node {
            case .node(let d):
                if d.isDeleted { return true }
                if depth == path.count - 1 { return false }
            }
        }
        return true
    }

    private func cascadeDeletionIfNeeded(at path: Path) {
        guard let node = getNode(at: path) else { return }
        switch node {
        case .node(let d):
            SomeDBLogger.info("🔍 cascadeDeletionIfNeeded on: \(d.value), isDeleted: \(d.isDeleted)")
            if !d.isDeleted { return }
            var mutated = d
            mutated.children = cascadeChildren(markDeleted: d.children)
            setNode(at: path, to: .node(mutated))
        }
    }

    private func cascadeChildren(markDeleted list: [DBRow<Value>]) -> [DBRow<Value>] {
        list.map { row in
            switch row {
            case .node(var d):
                d.isDeleted = true
                d.children = cascadeChildren(markDeleted: d.children)
                return .node(d)
            }
        }
    }

    // MARK: - Factory helpers

    public static func makeRoot(value: Value, id: UUID = UUID()) -> DBRow<Value> {
        .node(.init(id: id, parentId: nil, value: value, isDeleted: false, children: []))
    }

    public static func makeChild(parentId: UUID, value: Value, id: UUID = UUID()) -> DBRow<Value> {
        .node(.init(id: id, parentId: parentId, value: value, isDeleted: false, children: []))
    }

    public static func withChildren(id: UUID, parentId: UUID?, value: Value, isDeleted: Bool = false, children: [DBRow<Value>]) -> DBRow<Value> {
        .node(.init(id: id, parentId: parentId, value: value, isDeleted: isDeleted, children: children))
    }
}

extension SomeDB where Value == String {
    public func export() async -> [DBRow<String>] {
        return roots
    }
}
