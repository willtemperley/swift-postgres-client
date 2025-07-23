//
//  Portal.swift
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

import Foundation

/// A portal in PostgreSQL is a server-side object that represents a prepared statement along with its
/// parameter values and execution state. It's part of PostgreSQL's extended query protocol and serves
/// as an intermediate step between preparing a statement and executing it.
/// 
/// https://www.postgresql.org/docs/current/protocol-overview.html
///
public struct Portal: Sendable {
    
    let name: String
    let metadata: [ColumnMetadata]?
    let statement: Statement
    unowned let connection: Connection
    
    /// Executes the associated prepared statement with already bound parameters.
    ///
    /// - Returns: an `AsyncSequence` of rows. This is a single use iterator.
    public func query() async throws -> ResultCursor {
        return try await connection.query(portalName: name, statement: statement, metadata: metadata)
    }
    
    /// Executes the associated prepared statement with already bound parameters.
    ///
    /// - Returns: A `CommandStatus` indicating the operation type and number of rows affected.
    @discardableResult
    public func execute() async throws -> CommandStatus {
        return try await connection.execute(portalName: name, statement: statement)
    }
    
    /// Executes a query that returns a single value (e.g. COUNT, SUM, etc.).
    public func singleValue() async throws -> PostgresValue? {
        
        let cursor = try await query()
        var iterator = cursor.makeAsyncIterator()
        let row = try await iterator.next()
        if let row {
            let next = try await iterator.next()
            if next != nil {
                try await connection.recoverIfNeeded()
            }
            return row.columns.first?.postgresValue
        }
        return nil
    }

    /// Is this portal closed. Note this uses a server query.
    public var closed: Bool {
        get async throws {
            return try await connection.listOpenPortals().contains(where: { $0 == name })
        }
    }
}
