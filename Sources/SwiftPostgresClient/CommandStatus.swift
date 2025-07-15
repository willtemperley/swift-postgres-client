//
//  CommandStatus.swift
//  SwiftPostgresClient
//
//  Copyright 2025 Will Temperley and the SwiftPostgresClient contributors.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

public enum CommandStatus: Sendable {
    case insert(oid: Int, rowCount: Int)
    case delete(rowCount: Int)
    case update(rowCount: Int)
    case select(rowCount: Int)
    case move(rowCount: Int)
    case fetch(rowCount: Int)
    case copy(sourceCount: Int?, destCount: Int?)
    case empty
    case unknown(tag: String)

    public var rowCount: Int? {
        switch self {
        case .insert(_, let count),
             .delete(let count),
             .update(let count),
             .select(let count),
             .move(let count),
             .fetch(let count):
            return count
        case .copy(let source, let dest):
            return dest ?? source
        case .unknown:
            return nil
        case .empty:
            return nil
        }
    }

    public var commandName: String {
        switch self {
        case .insert: return "INSERT"
        case .delete: return "DELETE"
        case .update: return "UPDATE"
        case .select: return "SELECT"
        case .move:   return "MOVE"
        case .fetch:  return "FETCH"
        case .copy:   return "COPY"
        case .empty:   return "<empty>"
        case .unknown(let tag): return tag.components(separatedBy: " ").first ?? "<unknown>"
        }
    }
}

extension CommandStatus {
    public init(from commandTag: String) {
        let parts = commandTag.split(separator: " ")

        guard let command = parts.first else {
            self = .unknown(tag: commandTag)
            return
        }

        switch command {
        case "INSERT":
            if parts.count == 3,
               let oid = Int(parts[1]),
               let count = Int(parts[2]) {
                self = .insert(oid: oid, rowCount: count)
            } else {
                self = .unknown(tag: commandTag)
            }

        case "DELETE", "UPDATE", "SELECT", "MOVE", "FETCH":
            if parts.count == 2,
               let count = Int(parts[1]) {
                switch command {
                case "DELETE": self = .delete(rowCount: count)
                case "UPDATE": self = .update(rowCount: count)
                case "SELECT": self = .select(rowCount: count)
                case "MOVE":   self = .move(rowCount: count)
                case "FETCH":  self = .fetch(rowCount: count)
                default:       self = .unknown(tag: commandTag)
                }
            } else {
                self = .unknown(tag: commandTag)
            }

        case "COPY":
            let nums = parts.dropFirst().compactMap { Int($0) }
            self = .copy(
                sourceCount: nums.count > 0 ? nums[0] : nil,
                destCount:   nums.count > 1 ? nums[1] : nil
            )

        default:
            self = .unknown(tag: commandTag)
        }
    }
}
