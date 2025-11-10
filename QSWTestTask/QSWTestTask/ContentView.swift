//
//  ContentView.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 25.09.2025.
//

import SwiftUI
import SomeTreeView
import SomeDB
import SomeCache
import Persistence

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    private var db: SomeDB<String> {
        guard let db = state.db else {
            preconditionFailure("Database not initialized before ContentView usage")
        }
        return db
    }
    private var cache: SomeCache<String> { state.cache }
    private var persistence: PersistenceManager { state.persistence }

    @ObservedObject var state: AppState

    @State private var isApplying = false
    @State private var selectedDB: UUID? = nil
    @State private var expandedDB: Set<UUID> = []
    @State private var dbNodes: [TreeNode<UUID>] = []

    @State private var selectedCache: UUID? = nil
    @State private var expandedCache: Set<UUID> = []
    @State private var cacheNodes: [TreeNode<UUID>] = []
    @State private var isCacheSelectionDeleted: Bool = false
    @State private var showAlert = false
    @State private var newNodeValue = ""
    @State private var editMode: EditMode = .add
    @State private var isDbSelectionDeleted = true
    @State private var hasCacheChanges = false

    private func refreshHasChanges() {
        Task {
            let v = await cache.hasPendingChanges
            await MainActor.run { hasCacheChanges = v }
        }
    }

    private enum EditMode {
        case add
        case edit
    }
    var body: some View {
        if dbNodes.isEmpty {
            ProgressView("Loading…")
                .task {
                    async let dbNodesFuture = db.toTreeNodes()
                    async let cacheNodesFuture = cache.toTreeNodes()
                    dbNodes = await dbNodesFuture
                    cacheNodes = await cacheNodesFuture
                }
        } else {
            Group {
                if isLandscape {
                    HStack(spacing: 16) {
                        cacheSection
                        arrowButton(rotation: .degrees(180))
                        dbSection
                    }
                    .padding()
                } else {
                    VStack(spacing: 16) {
                        dbSection
                        arrowButton(rotation: .degrees(90))
                        cacheSection
                    }
                    .padding()
                }
            }
            .disabled(isApplying)
            .overlay {
                if isApplying {
                    ZStack {
                        Color.black.opacity(0.1).ignoresSafeArea()
                        ProgressView("Applying changes…")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .task {
                refreshHasChanges()
            }
            .animation(.easeInOut, value: isLandscape)
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                withAnimation(.easeInOut) {
                    isLandscape = UIDevice.current.orientation.isLandscape
                }
            }
        }
    }
    // MARK: - Sections
    private func handleAlertPrimaryAction() {
        Task {
            guard !newNodeValue.isEmpty else { return }
            if editMode == .add {
                await addNewCacheNode(value: newNodeValue)
                await MainActor.run { isCacheSelectionDeleted = false }
            } else if editMode == .edit, let id = selectedCache {
                await editCacheNode(id: id, newValue: newNodeValue)
            }
        }
    }

    private var cacheControls: some View {
        HStack {
            Button("+") {
                newNodeValue = ""
                editMode = .add
                showAlert = true
            }
            .help("Add child node")

            Button("-") {
                Task {
                    guard let id = selectedCache else { return }
                    await cache.deleteNode(id: id)
                    // 2) For each other cache root: ask DB if it is a descendant of the deleted node
                    let roots = await cache.rootIDs()
                    for rid in roots where rid != id {
                        if await db.isAncestor(id, of: rid) {
                            // This root actually belongs under the deleted node in DB → mark it deleted in cache too
                            await cache.deleteNode(id: rid)
                        }
                    }
                    cacheNodes = await cache.toTreeNodes()
                    await MainActor.run { isCacheSelectionDeleted = true }
                    refreshHasChanges()
                    await persistence.saveCache(cache)
                }
            }
            .help("Mark node as deleted")

            Button("A") {
                Task {
                    guard let id = selectedCache,
                          let node = await cache.findNode(id: id)
                    else { return }
                    newNodeValue = node.value
                    await MainActor.run {
                        editMode = .edit
                        showAlert = true
                    }
                }
            }
            .help("Edit selected node")
        }
        .disabled(selectedCache == nil || isCacheSelectionDeleted)
        .padding(.bottom, 8)
    }

    private var cacheTree: some View {
        TreeView(
            roots: cacheNodes,
            selectedID: $selectedCache,
            expandedIDs: $expandedCache
        )
        .frame(minWidth: 200, minHeight: 200)
    }

    private var cacheActions: some View {
        HStack {
            Button("Apply") {
                Task { await doApply() }
            }
            .disabled(!hasCacheChanges)
            .help("Apply all cached changes to the database")

            Button("Reset") {
                isApplying = true
                Task {
                    await DatabaseInitializer.resetDatabase(db, using: persistence)
                    await cache.clear()
                    await persistence.saveCacheSnapshot([])
                    let newCacheNodes = await cache.toTreeNodes()
                    let newDbNodes = await db.toTreeNodes()
                    await MainActor.run {
                        cacheNodes = newCacheNodes
                        dbNodes = newDbNodes
                        hasCacheChanges = false
                        isApplying = false
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    private var cacheSection: some View {
        VStack {
            cacheControls
            cacheTree
            cacheActions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .alert(alertTitle, isPresented: $showAlert) {
            TextField(alertPlaceholder, text: $newNodeValue)
            Button(primaryButtonTitle) { handleAlertPrimaryAction() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: selectedCache) { _, newValue in
            Task {
                if let id = newValue, let node = await cache.findNode(id: id) {
                    await MainActor.run { isCacheSelectionDeleted = node.isDeleted }
                } else {
                    await MainActor.run { isCacheSelectionDeleted = false }
                }
            }
        }
        .onChange(of: selectedDB) { _, newValue in
            Task {
                let deleted = newValue == nil ? true : await db.isDeleted(id: newValue!)
                await MainActor.run { isDbSelectionDeleted = deleted }
            }
        }
    }

    private var dbSection: some View {
        VStack {
            TreeView(
                roots: dbNodes,
                selectedID: $selectedDB,
                expandedIDs: $expandedDB
            )
            .frame(minWidth: 200, minHeight: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func arrowButton(rotation: Angle) -> some View {
        Button(action: { doTransfer() }) {
            Image(systemName: "arrow.right")
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .rotationEffect(rotation)
        }
        .frame(width: 50, height: 50)
        .disabled(selectedDB == nil || isDbSelectionDeleted)
    }

    private func doTransfer() {
        if let id = selectedDB {
            Task {
                await cache.transferFromDB(db, id: id)
                cacheNodes = await cache.toTreeNodes()
                refreshHasChanges()
                await persistence.saveCache(cache)
            }
        }
    }

    private func addNewCacheNode(value: String) async {
        if let parentId = selectedCache {
            _ = await cache.createNode(value: value, parentId: parentId)
        } else {
            // Not supported now.
            _ = await cache.createNode(value: value, parentId: nil)
        }
        cacheNodes = await cache.toTreeNodes()
        refreshHasChanges()
        await persistence.saveCache(cache)
    }

    private func editCacheNode(id: UUID, newValue: String) async {
        guard let node = await cache.findNode(id: id) else { return }
        if node.value != newValue {
            await cache.modifyNode(id: id, newValue: newValue)
            let newNodes = await cache.toTreeNodes()
            await MainActor.run {
                withAnimation { cacheNodes = newNodes }
                isCacheSelectionDeleted = false
            }
            refreshHasChanges()
            await persistence.saveCache(cache)
        }
    }

    private func doApply() async {
        await MainActor.run { isApplying = true }
        defer { Task { await MainActor.run { isApplying = false } } }
        print("🟢 Starting Apply transaction")

        // 1️⃣ start the transaction
        await db.startTransaction()

        // 2️⃣ fetch all modeified
        let modifiedNodes = await cache.allModified()

        // 3️⃣ Walk through each modified node
        for node in modifiedNodes {
            switch node.state {
            case .new:
                // Creating new node in BD
                if let parent = node.parent {
                    if let newId = await db.createChild(under: parent.id, value: node.value) {
                        await cache.updateId(oldId: node.id, newId: newId)
                    }
                } else {
                    // We will always have parent by the task description, but to have code more universal
                    let _ = SomeDB<String>.makeRoot(value: node.value)
                    let newId = await db.createRoot(value: node.value)
                    await cache.updateId(oldId: node.id, newId: newId)
                }

            case .modified:
                let _ = await db.updateValue(id: node.id, to: node.value)

            case .deleted:
                _ = await db.delete(id: node.id)

            case .unchanged:
                // We should not be here, but to make switch working.
                break
            }
        }

        // 4️⃣ Finish the transaction
        await db.commitTransaction()

        // 5️⃣ Save to persistence
        await persistence.saveDatabase(db)
        print("💾 Database persisted successfully")

        // 6️⃣ No changes any more and save new cache
        await cache.resetStatesToUnchanged()
        await persistence.saveCache(cache)

        // 7️⃣ Reset view (DB + Cache)
        async let newDbNodes = db.toTreeNodes()
        async let newCacheNodes = cache.toTreeNodes()
        let (dbReloaded, cacheReloaded) = await (newDbNodes, newCacheNodes)

        await MainActor.run {
            withAnimation {
                dbNodes = dbReloaded
                cacheNodes = cacheReloaded
            }
            hasCacheChanges = false
        }

        // 8️⃣ Deselect deleted node if needed
        if let id = selectedDB, !dbReloaded.contains(where: { $0.id == id }) {
              selectedDB = nil
              isDbSelectionDeleted = true
        }
        print("✅ Apply finished successfully")
    }

    // MARK: - Alert info data helpers
    private var alertTitle: String {
        editMode == .add ? "New Node" : "Edit Node"
    }
    private var alertPlaceholder: String {
        editMode == .add ? "Enter node name" : "Value"
    }
    private var primaryButtonTitle: String {
        editMode == .add ? "Add" : "Save"
    }
    private var alertMessage: String {
        editMode == .add ? "Enter name for new element" : "Change node value"
    }

    // MARK: - Orientation
    @State private var isLandscape = UIDevice.current.orientation.isLandscape
}

#Preview {
    ContentView(state: AppState())
}
