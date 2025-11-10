//
//  SomeCache+TreeView.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 29.09.2025.
//

import Foundation
import SomeTreeView
import SomeCache

public extension SomeCache {
    /// Export the current cache snapshot into TreeNode<UUID> structures
    /// that are compatible with `SomeTreeView`.
    func toTreeNodes() -> [TreeNode<UUID>] {
        roots.map { convertToTreeNode($0) }
    }

    /// Recursively convert a CacheNode into a TreeNode.
    private func convertToTreeNode(_ node: CacheNode<Value>) -> TreeNode<UUID> {
        // Title text – just use `String(describing:)` for generic Value.
        let title = String(describing: node.value)

        return TreeNode(
            id: node.id,
            title: title,
            // For TreeView we don't care about state, but mark deleted visually
            color: node.displayColor,
            children: node.children.map { convertToTreeNode($0) }
        )
    }
}
