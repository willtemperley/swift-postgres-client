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
public struct Portal {
    
    let name: String
    let rowDecoder: RowDecoder?
    let statement: Statement
    unowned let connection: Connection
    
    /// Executes the associated prepared statement with already bound parameters.
    ///
    /// - Returns: an `AsyncSequence` of rows. This is a single use iterator.
    func query() async throws -> ResultCursor {
        
        return try await connection.query(portalName: name, statement: statement, rowDecoder: rowDecoder)
    }
    
    @discardableResult
    func execute() async throws -> CommandStatus {
        
        let executeRequest = ExecuteRequest(portalName: name, statement: statement)
        try await connection.sendRequest(executeRequest)
        let flushRequest = FlushRequest()
        try await connection.sendRequest(flushRequest)

        let response = try await connection.receiveResponse(type: CommandCompleteResponse.self)
        try await connection.cleanupPortal(name: name)
        return response.status
    }
}

