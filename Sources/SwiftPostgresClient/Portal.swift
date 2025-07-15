// Portal.swift
// SwiftPostgresClient
//
// Created by Will Temperley on 15/07/2025. All rights reserved.
// Copyright 2025 Will Temperley.
// 
// Copying or reproduction of this file via any medium requires prior express
// written permission from the copyright holder.
// -----------------------------------------------------------------------------
///
/// Implementation notes, links and internal documentation go here.
///
// -----------------------------------------------------------------------------

import Foundation

struct PreparedStatement: Sendable {
    let name: String
    let statement: Statement
    unowned let connection: Connection
    
    func bind(parameterValues: [PostgresValueConvertible], columnMetadata: Bool = false) async throws -> Portal {
        
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

struct Portal {
    
    let name: String
    let rowDecoder: RowDecoder?
    let statement: Statement
    unowned let connection: Connection
    
    // TODO: Max rows
    func execute() async throws -> ResultCursor {
        
        let executeRequest = ExecuteRequest(portalName: name, statement: statement)
        try await connection.sendRequest(executeRequest)
        
        let flushRequest = FlushRequest()
        try await connection.sendRequest(flushRequest)
        
        return ResultCursor(connection: connection, portalName: name, rowDecoder: rowDecoder)
    }
}

