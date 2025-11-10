# TestTask — Hierarchical Data Editor (iOS Developer Test Assignment)

> **Test assignment for an iOS Developer position.**  
> A SwiftUI-based demo app that demonstrates hierarchical data editing, caching, and persistence synchronization using Swift Concurrency and actor isolation.

---

## 📋 Assignment Description

The goal of the task was to create an iOS application that:
- Loads a **hierarchical database (tree)** from a JSON file.  
- Allows **adding, editing, and deleting nodes** interactively.  
- Keeps all changes in an **in-memory cache** until explicitly applied.  
- Commits changes to the persistent database only when “Apply” is pressed.  
- Supports **“Reset”** to restore the database to its original JSON-defined state.  
- Persists both the database and the cache between app launches.

This repository contains a **fully working implementation** that meets all of the above requirements.

---

## 🏗️ Architecture Overview

The app is structured as multiple Swift Packages:

| Module | Description |
|--------|--------------|
| **SomeDB** | Actor-based hierarchical database (`SomeDB<Value>`). Manages persistent tree structures and supports transactions, commit, and reinitialization. |
| **SomeCache** | In-memory layer mirroring the database. Tracks pending changes (added / modified / deleted) before they are applied. Provides full state tracking. |
| **Persistence** | Handles persistence for both DB and cache, saving them to disk as JSON snapshots. Provides async-safe load, save, and reset operations. |
| **SomeTreeView** | SwiftUI component for displaying hierarchical trees. Supports expansion, selection, and color-coded state highlighting. |
| **QSWTestTaskApp** | Main app integrating all modules and user actions (Add/Edit/Delete/Apply/Reset). |

---

## ⚙️ Key Features

### 🧠 Database Layer (`SomeDB`)
- Thread-safe, actor-isolated data model.  
- Provides transactions (`startTransaction`, `commitTransaction`).  
- Can reinitialize from bundled JSON.  
- Fully detached from UI logic.

### 🗂️ Cache Layer (`SomeCache`)
- In-memory reflection of the DB for pending changes.  
- Tracks node states:  
  - 🟩 **Green** — newly added nodes  
  - 🟦 **Blue** — modified nodes  
  - 🟥 **Red** — deleted nodes (remain visible until applied)  
- Keeps consistent hierarchy and relationships.  
- Persists automatically after each mutation.  
- Restores all nodes and their states at app launch.

### 💾 Persistence Layer
- Two independent JSON files:
  - `DatabaseSnapshot.json`
  - `CacheSnapshot.json`
- Uses async-safe file operations with `JSONEncoder`/`JSONDecoder`.  
- Automatically restores state on launch.  
- Provides full `reset()` to clean both persistent stores.

### 🌳 TreeView Component
- Fully SwiftUI-based hierarchical list view.  
- Displays each node with proper color based on its cache state.  
- Supports selection, expansion, and dynamic updates with animation.  
- Used for both cache and database visualization.

---

## 🧰 Generation Script

A **generation script** is included to produce the initial JSON database file (`DBInitial.json`).

- Located in the `Persistence` package.  
- Generates **10 nodes by default** (small demo set).  
- The repository currently includes a **pre-generated 1,000,000-node dataset** for performance testing.

**Default file path:**
QSWTestTask/Resources/DBInitial.json
To regenerate manually:
```bash
python3 genetrate_db_json.py
```
Add number of nodes up to 1 million. 

This will generate a file that can be used to overwrite the existing file with a new generated dataset.

🧩 App Flow

DBInitial.json ─▶ DatabaseInitializer
       │
       ▼
   SomeDB (actor)
       │
       ▼
   PersistenceManager ◀────▶ SomeCache (actor)
       │
       ▼
    Disk JSON snapshots

    At launch, both the database and cache are restored automatically via PersistenceManager.

    🧪 Demo UI (TreeView)

    Section                                Description
Cache (left/bottom)     Displays pending modifications not yet applied to the DB.
Database (right/top)    Displays the persisted structure after the last “Apply”.
Color coding            🟩 Green — newly added nodes; 🟦 Blue — modified nodes; 🟥 Red — deleted nodes (still shown for better testing abilities).
Buttons                 + — Add node, A — Edit node, - — Mark node as deleted, Apply — Commit changes, Reset — Restore from JSON.

All editing actions operate only on the cache.
Only “Apply” synchronizes cache → database.
During Apply or Reset, the entire UI is temporarily disabled to prevent concurrent edits.

🚀 How to Run
	1.	Open the project in Xcode 16+.
	2.	Select the QSWTestTaskApp target and run.
	3.	On launch:
	•	The app loads the 1M-node version of DBInitial.json (already committed).
	•	If persistence files exist, the database and cache are restored automatically.
	4.	Interact with the app:
	•	Add, edit, and delete nodes in the cache tree.
	•	Press Apply to synchronize with the DB.
	•	Press Reset to restore the initial structure.

  🧱 Highlights
	•	Modular Swift Package design.
	•	Full async/await flow and actor isolation.
	•	Safe concurrent persistence for DB and cache.
	•	Real-time visual feedback for cache states.
	•	TreeView supports deep hierarchies (tested up to 1M nodes).
