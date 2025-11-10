//
//  TreeViewDemoApp.swift
//  SomeTreeView
//
//  Created by Sergey Makeev on 25.09.2025.
//

import SwiftUI
import SomeTreeView

@main
struct TreeViewDemoApp: App {
    var body: some Scene {
        WindowGroup {
            DemoScreen()
        }
    }
}

struct DemoScreen: View {
    @State private var selected: Int? = nil
    @State private var expanded: Set<Int> = [1, 3]

    private let data: [TreeNode<Int>] = [
        TreeNode(id: 1, title: "Root 1", children: [
            TreeNode(id: 2, title: "Child 1.1"),
            TreeNode(id: 3, title: "Child 1.2", children: [
                TreeNode(id: 4, title: "Child 1.2.1"),
                TreeNode(id: 5, title: "Child 1.2.2", isDeleted: true, children: [
                    TreeNode(id: 6, title: "Child 1.2.2.1")
                ])
            ])
        ])
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                TreeView(
                    roots: data,
                    selectedID: $selected,
                    expandedIDs: $expanded
                ) { id in
                    print("Selected:", id)
                }
                // .frame(minWidth: 600, minHeight: 300)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text("Selected: \(selected.map(String.init) ?? "none")")
                .padding(.top, 8)
        }
        .padding()
    }
}
