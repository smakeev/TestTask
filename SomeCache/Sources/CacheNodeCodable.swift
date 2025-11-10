//
//  CacheNodeCodable.swift
//  SomeCache
//
//  Created by Sergey Makeev on 18.10.2025.
//

import Foundation

/// Codable representation of CacheNode for persistence.
public struct CodableCacheNode<Value: Codable>: Codable, Sendable {
    let id: UUID
    let value: Value
    let state: String
    let isDeleted: Bool
    let expectedParentId: UUID?
    let children: [CodableCacheNode<Value>]

    public init(from node: CacheNode<Value>) {
        self.id = node.id
        self.value = node.value
        self.state = "\(node.state)"
        self.isDeleted = node.isDeleted
        self.expectedParentId = node.expectedParentId
        self.children = node.children.map { CodableCacheNode(from: $0) }
    }

    public func toNode(parent: CacheNode<Value>? = nil) -> CacheNode<Value> {
        let node = CacheNode(
            id: id,
            value: value,
            parent: parent,
            state: Self.stateFromString(state),
            isDeleted: isDeleted,
            expectedParentId: expectedParentId
        )
        node.children = children.map { $0.toNode(parent: node) }
        return node
    }

    private static func stateFromString(_ s: String) -> CacheState {
        switch s {
        case "new": return .new
        case "modified": return .modified
        case "deleted": return .deleted
        default: return .unchanged
        }
    }
}
