//
//  TreeRowView.swift
//  SomeTreeView
//
//  Created by Sergey Makeev on 25.09.2025.
//

import SwiftUI

/// One row in the tree list. Pure UI; no knowledge of data source.
struct TreeRowView<ID: Hashable>: View {
    let row: VisibleRow<ID>
    let indentPerLevel: CGFloat
    let isExpanded: Bool
    let isSelected: Bool
    let onToggleExpand: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Indentation spacer
            Color.clear
                .frame(width: CGFloat(row.level) * indentPerLevel)

            // Chevron (only if expandable OR has children)
            if row.isExpandable || row.hasChildren {
                Button(action: onToggleExpand) {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 16, height: 16)
                        .contentShape(Rectangle())
                        .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
                }
                .buttonStyle(.plain)
            } else {
                // Reserve chevron space for alignment
                Color.clear.frame(width: 16, height: 16)
            }

            // Title
            Text(row.title)
                .lineLimit(1)
                .truncationMode(.tail)
                .contentShape(Rectangle())
                .foregroundColor(row.node.color)
                .foregroundColor(.yellow)
                .layoutPriority(1)
        }
        //.frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.trailing, 8)
        .background(
            isSelected
            ? AnyView(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.15)))
            : AnyView(Color.clear)
        )
        .onTapGesture {
            onSelect()
        }
        .animation(.default, value: isExpanded)
    }
}
