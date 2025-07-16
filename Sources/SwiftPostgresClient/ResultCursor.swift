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
    let rowDecoder: RowDecoder?
    
    /// Either the number of rows returned or the number of rows affected by the associated statement.
    /// This will not be available until after the result set has been consumed.
    var rowCount: Int? {
        get async {
            await connection.commandStatus?.rowCount
        }
    }
    
    init(connection: Connection, portalName: String, rowDecoder: RowDecoder? = nil) {
        self.connection = connection
        self.portalName = portalName
        self.rowDecoder = rowDecoder
    }
    
    /// Creates the asynchronous iterator that produces elements of this
    /// asynchronous sequence.
    ///
    /// - Returns: An instance of the `AsyncIterator` type used to produce
    /// messages in the asynchronous sequence.
    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(connection: connection, portalName: portalName, rowDecoder: rowDecoder)
    }
    
    /// An asynchronous iterator that produces the rows of this asynchronous sequence.
    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = Row
        
        var connection: Connection
        var portalName: String
        var rowDecoder: RowDecoder?
        
        mutating public func next() async throws -> Row? {
            
            guard await connection.connected else {
                throw PostgresError.connectionClosed
            }
            
            while true {
                let response = await connection.receiveResponse()
                
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
                    try await connection.cleanupPortal(name: portalName)
                    return nil
                    
                default:
                    throw PostgresError.serverError(
                        description: "Unexpected response: \(response)")
                }
            }
        }
    }
}
