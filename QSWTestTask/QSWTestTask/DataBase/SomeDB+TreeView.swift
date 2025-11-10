//
//  SomeDB+TreeView.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 28.09.2025.
//

import Foundation
import SomeDB
import SomeTreeView
import SwiftUI

extension SomeDB where Value == String {
    /// Convert the DB forest into an array of TreeNode<UUID> for SomeTreeView.
    /// This is a snapshot of the current state inside the actor.
    public func toTreeNodes() async -> [TreeNode<UUID>] {
         exportRoots()
    }

    /// Internal helper that walks the roots (actor-isolated).
    private func exportRoots() -> [TreeNode<UUID>] {
        roots.map { exportNode($0) }
    }

    /// Recursively convert DBRow<Value> into TreeNode<UUID>.
    private func exportNode(_ row: DBRow<Value>) -> TreeNode<UUID> {
        switch row {
        case .node(let d):
            let children = d.children.map { exportNode($0) }
            return TreeNode(
                id: d.id,
                title: d.value,
                color: d.isDeleted ? .red : .black,
                children: children
            )
        }
    }
}
