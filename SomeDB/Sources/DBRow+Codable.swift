//
//  DBRow+Codable.swift
//  SomeDB
//
//  Created by Sergey Makeev on 18.10.2025.
//

import Foundation

extension DBRow: Codable where Value: Codable {
    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case parentId
        case value
        case isDeleted
        case children
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .node(let data):
            try container.encode("node", forKey: .type)
            try container.encode(data.id, forKey: .id)
            try container.encode(data.parentId, forKey: .parentId)
            try container.encode(data.value, forKey: .value)
            try container.encode(data.isDeleted, forKey: .isDeleted)
            try container.encode(data.children, forKey: .children)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "node":
            let id = try container.decode(UUID.self, forKey: .id)
            let parentId = try container.decodeIfPresent(UUID.self, forKey: .parentId)
            let value = try container.decode(Value.self, forKey: .value)
            let isDeleted = try container.decode(Bool.self, forKey: .isDeleted)
            let children = try container.decode([DBRow<Value>].self, forKey: .children)
            self = .node(NodeData(
                id: id,
                parentId: parentId,
                value: value,
                isDeleted: isDeleted,
                children: children
            ))
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown DBRow type")
        }
    }
}
