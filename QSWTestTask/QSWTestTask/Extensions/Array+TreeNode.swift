//
//  Array+TreeNode.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 28.09.2025.
//

import Foundation
import SomeTreeView

extension Array where Element == TreeNode<UUID> {
    /// Recursively find a node by its ID in the tree.
    func findNode(by id: UUID?) -> TreeNode<UUID>? {
        guard let id else { return nil }
        for node in self {
            if node.id == id {
                return node
            }
            if let found = node.children.findNode(by: id) {
                return found
            }
        }
        return nil
    }
}
