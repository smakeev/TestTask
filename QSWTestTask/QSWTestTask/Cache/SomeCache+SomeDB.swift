//
//  SomeCache+SomeDB.swift
//  QSWTestTask
//
//  Created by Sergey Makeev on 29.09.2025.
//

import Foundation
import SomeDB
import SomeCache


public extension SomeCache where Value == String {
    /// Transfer a single non-deleted DB node into the cache.
    func transferFromDB(_ db: SomeDB<String>, id: UUID) async {
        guard let dbNode = await db.getNonDeleted(by: id) else { return }
        insertNode(id: dbNode.id, value: dbNode.value, parentId: dbNode.parentId)
    }
}
