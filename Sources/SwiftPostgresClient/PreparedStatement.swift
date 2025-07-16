//
//  PreparedStatement.swift
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

/// A [prepared statement](https://www.postgresql.org/docs/current/sql-prepare.html).
/// This is a named statement on the PostgreSQL server, lasting for the duration  of the database session.
/// See [protocol overview] (https://www.postgresql.org/docs/current/protocol-overview.html)
///
public struct PreparedStatement: Sendable {
    let name: String
    let statement: Statement
    unowned let connection: Connection
    
    /// Binds the parameters to the prepared statement. This has no effect on the statement itself,  instead
    /// returning a `Portal` which represents the execution state of a query.
    /// - Parameters:
    ///   - parameterValues: The required parameter values.
    ///   - columnMetadata: 
    /// - Returns: a `Portal` ready to execute the associated prepared statement.
    public func bind(parameterValues: [PostgresValueConvertible], columnMetadata: Bool = false) async throws -> Portal {
        
        let portalName = UUID().uuidString
        let bindRequest = BindRequest(name: portalName, statement: statement, parameterValues: parameterValues)
        try await connection.sendRequest(bindRequest)
        
        let flushRequest = FlushRequest()
        try await connection.sendRequest(flushRequest)
        
        try await connection.receiveResponse(type: BindCompleteResponse.self)
        
        var rowDecoder: RowDecoder?
        if columnMetadata {
            let metadata = try await connection.retrieveColumnMetadata()
            if let metadata {
                rowDecoder = RowDecoder(columns: metadata)
            }
        }
        
        return Portal(name: portalName, rowDecoder: rowDecoder, statement: statement, connection: connection)
    }
}
