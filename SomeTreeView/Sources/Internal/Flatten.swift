//
//  Flatten.swift
//  SomeTreeView
//
//  Created by Sergey Makeev on 25.09.2025.
//

import Foundation
import SwiftUI

/// A visible row in the flattened tree representation.
struct VisibleRow<ID: Hashable>: Identifiable {
    let id: ID
    let level: Int
    let title: String
    let isExpandable: Bool
    let hasChildren: Bool
    let color: Color
    let node: TreeNode<ID>
}

/// Flattens a tree according to expanded IDs.
func flatten<ID: Hashable>(
    roots: [TreeNode<ID>],
    expanded: Set<ID>
) -> [VisibleRow<ID>] {
    var result: [VisibleRow<ID>] = []

    func dfs(_ nodes: [TreeNode<ID>], level: Int) {
        for n in nodes {
            let row = VisibleRow(
                id: n.id,
                level: level,
                title: n.title,
                isExpandable: n.isExpandable,
                hasChildren: !n.children.isEmpty,
                color: n.color,
                node: n
            )
            result.append(row)
            if expanded.contains(n.id) {
                dfs(n.children, level: level + 1)
            }
        }
    }

    dfs(roots, level: 0)
    return result
}
