//
//  TreeView.swift
//  SomeTreeView
//
//  Created by Sergey Makeev on 25.09.2025.
//

import SwiftUI
import OSLog

/// Public tree view component:
/// - works with preloaded trees (no UI-triggered fetching),
/// - supports single selection,
/// - supports expand/collapse via chevrons,
/// - scrolls vertically and horizontally,
/// - keeps a binding for selected and expanded nodes so the owner is always in sync.
public struct TreeView<ID: Hashable>: View {
    // Input tree roots (already materialized by the owner).
    public var roots: [TreeNode<ID>]

    /// Currently selected node ID (single select).
    @Binding public var selectedID: ID?

    /// Set of expanded node IDs managed by the owner or by the view.
    @Binding public var expandedIDs: Set<ID>

    /// Called when a row is selected (after `selectedID` is updated).
    public var onSelected: ((ID) -> Void)?

    /// Visual tuning
    public var indentPerLevel: CGFloat = 20

    public init(
        roots: [TreeNode<ID>],
        selectedID: Binding<ID?>,
        expandedIDs: Binding<Set<ID>>,
        indentPerLevel: CGFloat = 20,
        onSelected: ((ID) -> Void)? = nil
    ) {
        self.roots = roots
        self._selectedID = selectedID
        self._expandedIDs = expandedIDs
        self.indentPerLevel = indentPerLevel
        self.onSelected = onSelected
    }

    public var body: some View {
        // Build the list of visible rows based on expanded state.
        let rows = flatten(roots: roots, expanded: expandedIDs)

        // Both directions scrolling to support deep nesting.
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(rows) { row in
                    let expanded = expandedIDs.contains(row.id)
                    let selected = row.id == selectedID

                    TreeRowView(
                        row: row,
                        indentPerLevel: indentPerLevel,
                        isExpanded: expanded,
                        isSelected: selected,
                        onToggleExpand: {
                            toggle(row.id, shouldExpand: !expanded)
                        },
                        onSelect: {
                            selectedID = row.id
                            onSelected?(row.id)
                        }
                    )
                    .id(row.id) // helps ScrollViewReader if owner uses it
                }
            }
            .frame(minWidth: 400, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: expandedIDs)
    }

    private func toggle(_ id: ID, shouldExpand: Bool) {
        if shouldExpand {
            expandedIDs.insert(id)
        } else {
            // Collapse the node and all its expanded descendants
            collapseRecursively(startingAt: id)
        }
    }

    private func collapseRecursively(startingAt id: ID) {
        // Remove `id` itself
        expandedIDs.remove(id)

        // Also remove descendants that are currently visible and expanded.
        // We can compute a small helper tree of the current roots to walk down.
        let rows = flatten(roots: roots, expanded: expandedIDs)
        // Build a map parent->children visible chain to know descendants.
        var index: [ID: Int] = [:]
        for (i, r) in rows.enumerated() { index[r.id] = i }

        guard let startIndex = index[id] else { return }
        let startLevel = rows[startIndex].level
        var j = startIndex + 1
        while j < rows.count {
            let row = rows[j]
            if row.level <= startLevel { break }
            expandedIDs.remove(row.id)
            j += 1
        }
    }
}
