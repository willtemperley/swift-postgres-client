// QueryCursor.swift
// PostgresClientKit
//
// Created by Will Temperley on 12/07/2025. All rights reserved.
// Copyright 2025 Will Temperley.
//
// Copying or reproduction of this file via any medium requires prior express
// written permission from the copyright holder.
// -----------------------------------------------------------------------------
///
/// Implementation notes, links and internal documentation go here.
///
// -----------------------------------------------------------------------------

fileprivate enum CursorLifecycleState {
    case open
    case drained
    case closed
    case cleanedUp
}

final class CursorState {
    var rowCount: Int? = nil
    fileprivate var lifecycleState: CursorLifecycleState = .closed
    var rowDecoder: RowDecoder?
}

public struct QueryCursor: AsyncSequence {
    
    let connection: Connection
    let cursorState: CursorState = .init()
    
    var rowCount: Int? {
        cursorState.rowCount
    }
    
    init(connection: Connection) {
        self.connection = connection
    }
    
    public func makeAsyncIterator() -> AsyncIterator {
        return AsyncIterator(connection: connection, state: cursorState)
    }
    
    public struct AsyncIterator: AsyncIteratorProtocol {
        public typealias Element = Row
        
        var connection: Connection
        var state: CursorState
        
        mutating public func next() async throws -> Row? {
            
            guard await connection.connected else {
                throw PostgresError.connectionClosed
            }
            
            while true {
                let response = await connection.receiveResponse()
                
                switch response {
                case let dataRow as DataRowResponse:
                    let row = Row(columns: dataRow.columns, columnNameRowDecoder: state.rowDecoder)
                    return row
                    
                case is EmptyQueryResponse:
                    state.rowCount = 0
                    state.lifecycleState = .drained
                    try await cleanupPortalIfNeeded()
                    return nil
                    
                case let command as CommandCompleteResponse:
                    let tokens = command.commandTag.split(separator: " ")
                    
                    // TODO: guards required
                    switch tokens[0] {
                        
                    case "INSERT":
                        state.rowCount = Int(tokens[2])
                        
                    case "DELETE", "UPDATE", "SELECT", "MOVE", "FETCH", "COPY":
                        state.rowCount = Int(tokens[1])
                        
                    default:
                        break
                    }
                    state.lifecycleState = .drained
                    try await cleanupPortalIfNeeded()
                    return nil
                    
                default:
                    throw PostgresError.serverError(
                        description: "Unexpected response: \(response)")
                }
            }
        }
        
        func cleanupPortalIfNeeded() async throws {
            guard state.lifecycleState == .drained else { return }
            try await connection.cleanupPortal()
            state.lifecycleState = .cleanedUp
        }
        
    }
    
    func prepareStatement(query: String) async throws -> Statement {
        
        let statement = Statement(text: query)
        let parseRequest = ParseRequest(statement: statement)
        try await connection.sendRequest(parseRequest)
        
        let flushRequest = FlushRequest()
        try await connection.sendRequest(flushRequest)
        
        let response = try await connection.receiveResponse(type: ParseCompleteResponse.self)
        print(response)
        return statement
    }
    
    func executeStatement(statement: Statement,
                          parameterValues: [PostgresValueConvertible?] = [],
                          columnMetadata: Bool = false
    ) async throws {
        // TODO: pagination; batched execution
        
        let bindRequest = BindRequest(statement: statement, parameterValues: parameterValues)
        try await connection.sendRequest(bindRequest)
        
        let flushRequest = FlushRequest()
        try await connection.sendRequest(flushRequest)
        
        try await connection.receiveResponse(type: BindCompleteResponse.self)
        
        if columnMetadata {
            let metadata = try await retrieveColumnMetadata()
            if let metadata {
                let rowDecoder = RowDecoder(columns: metadata)
                cursorState.rowDecoder = rowDecoder
            }
        }
        
        let executeRequest = ExecuteRequest(statement: statement)
        try await connection.sendRequest(executeRequest)
        
        try await connection.sendRequest(flushRequest)
    }
    
    // used for decoding structs using column names
    func retrieveColumnMetadata() async throws -> [ColumnMetadata]? {
        
        var columns: [ColumnMetadata]? = nil
        
        let describePortalRequest = DescribePortalRequest()
        try await connection.sendRequest(describePortalRequest)
        
        let flushRequest = FlushRequest()
        try  await connection.sendRequest(flushRequest)
        
        let response = await connection.receiveResponse()
        
        switch response {
            
        case is NoDataResponse:
            columns = nil
            
        case let rowDescriptionResponse as RowDescriptionResponse:
            columns = rowDescriptionResponse.columns
            
        default:
            throw PostgresError.serverError(
                description: "unexpected response type '\(response.responseType)'")
        }
        
        return columns
    }
    
}
