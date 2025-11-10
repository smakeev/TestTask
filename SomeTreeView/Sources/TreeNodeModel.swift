//
//  TreeNode.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 25.09.2025.
//
import Foundation
import SwiftUI

/// Lightweight UI-facing model the view works with.
/// app can map DB/Cached entities into this model before rendering.
public struct TreeNode<ID: Hashable>: Identifiable, Equatable {
    public let id: ID
    public var title: String
    public var isExpandable: Bool
    public var children: [TreeNode<ID>]
    public var color: Color = .black

    public init(id: ID, title: String, color: Color = .black, isExpandable: Bool? = nil, children: [TreeNode<ID>] = []) {
        self.id = id
        self.title = title
        // If `isExpandable` is not provided, infer from children presence.
        if let explicit = isExpandable {
            self.isExpandable = explicit
        } else {
            self.isExpandable = !children.isEmpty
        }
        self.children = children
        self.color = color
    }
}
