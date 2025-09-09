//
//  ResultCursor.swift
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

/// An `AsyncSequence` of rows.
public struct ResultCursor: AsyncSequence, Sendable {
    
    let connection: Connection
    let portalName: String
    let extendedProtcol: Bool
    let metatdata: [ColumnMetadata]?
    let rowDecoder: RowDecoder?
    let initialResponse: Response?
    let commandStatus: CommandStatus?
    
    /// Either the number of rows returned or the number of rows affected by the associated statement.
    /// This will not be available until after the result set has been consumed.
    /// The specific interpretation of this value depends on the SQL command performed:
    ///
    /// - `INSERT`: the number of rows inserted
    /// - `UPDATE`: the number of rows updated
    /// - `DELETE`: the number of rows deleted
    /// - `SELECT` or `CREATE TABLE AS`: the number of rows retrieved
    /// - `MOVE`: the number of rows by which the SQL cursor's position changed
    /// - `FETCH`: the number of rows retrieved from the SQL cursor
    /// - `COPY`: the number of rows copied
    ///
    /// If this `Cursor` has one or more rows, this property is `nil` until the final row has been
    /// retrieved (in other words, until `next()` returns `nil`).
    public var rowCount: Int? {
        get async {
            if let commandStatus {
                return commandStatus.rowCount
            } else {
                return await connection.commandStatus?.rowCount
            }
        }
    }
    
    init(connection: Connection, portalName: String, extendedProtocol: Bool = true, metadata: [ColumnMetadata]? = nil, initialResponse: Response?) {
        self.connection = connection
        self.portalName = portalName
        self.extendedProtcol = extendedProtocol
        self.metatdata = metadata
        if let metadata = metadata {
            self.rowDecoder = RowDecoder(columns: metadata)
        } else {
            self.rowDecoder = nil
        }
        self.initialResponse = initialResponse
        if case let response as CommandCompleteResponse = initialResponse {
            self.commandStatus = response.status
        } else {
            self.commandStatus = nil
        }
    }
    
    /// Creates the asynchronous iterator that produces elements of this
    /// asynchronous sequence.
    ///
    /// - Returns: An instance of the `AsyncIterator` type used to produce
    /// messages in the asynchronous sequence.
    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(
            connection: connection,
            portalName: portalName,
            extendedProtocol: extendedProtcol,
            commandComplete: commandStatus != nil,
            rowDecoder: rowDecoder,
            initialResponse: initialResponse
        )
    }
    
    /// An asynchronous iterator that produces the rows of this asynchronous sequence.
    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = Row
        
        var connection: Connection
        var portalName: String
        var extendedProtocol: Bool
        // Zero-row portals will be cleaned up before the cursor is created
        var commandComplete: Bool
        var rowDecoder: RowDecoder?
        var initialResponse: Response?
        
        mutating func nextResponse() async throws -> Response {
            if let nextResponse =  initialResponse {
                self.initialResponse = nil
                return nextResponse
            } else {
                return await connection.receiveResponse()
            }
        }

        mutating public func next() async throws -> Row? {
            
            guard await connection.connected else {
                throw PostgresError.connectionClosed
            }
            
            while true {
                let response = try await nextResponse()
                
                switch response {
                case let dataRow as DataRowResponse:
                    
                    let row = Row(columns: dataRow.columns, columnNameRowDecoder: rowDecoder)
                    return row
                    
                case is EmptyQueryResponse:
                    
                    try await connection.setCommandStatus(to: .empty)
                    try await connection.cleanupPortal(name: portalName)
                    return nil
                    
                case let command as CommandCompleteResponse:
                    
                    let commandStatus = command.status
                    try await connection.setCommandStatus(to: commandStatus)
                    if extendedProtocol, !commandComplete {
                        try await connection.cleanupPortal(name: portalName)
                    }
                    return nil
                    
                default:
                    throw PostgresError.serverError(
                        description: "Unexpected response: \(response)")
                }
            }
        }
    }
}
