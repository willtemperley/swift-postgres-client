//
//  Connection+portal.swift
//  SwiftPostgresClient
//
//  Copyright 2025 Will Temperley and the SwiftPostgresClient contributors
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

extension Connection {
    
    func createPortal(
        statement: Statement,
        parameterValues: [PostgresValueConvertible?] = [],
        columnMetadata: Bool = false
    ) async throws -> Portal {
        
        if state == .closed {
            throw PostgresError.connectionClosed
        }
        
        let portalName = UUID().uuidString
        let bindRequest = BindRequest(name: portalName, statement: statement, parameterValues: parameterValues)
        try await sendRequest(bindRequest, flush: true)
        
        try await receiveResponse(type: BindCompleteResponse.self)
        
        var metadata: [ColumnMetadata]?
        if columnMetadata {
            metadata = try await retrieveColumnMetadata(portalName: portalName)
        }
        
        return Portal(name: portalName, metadata: metadata, statement: statement, connection: self)
    }
    
    func query(
        portalName: String,
        statement: Statement,
        metadata: [ColumnMetadata]?
    ) async throws -> ResultCursor {
        
        state = .querySent
        
        let executeRequest = ExecuteRequest(portalName: portalName, statement: statement)
        try await sendRequest(executeRequest, flush: true)
        
        // The first response of the query is evaluated eagerly to check its type.
        let response = await receiveResponse()
        
        // A zero-result query immediately gives a CommandCompleteResponse
        if response is CommandCompleteResponse {
            try await cleanupPortal(name: portalName)
        }

        return ResultCursor(connection: self, portalName: portalName, metadata: metadata, initialResponse: response)
    }
    
    func execute(
        portalName: String,
        statement: Statement
    ) async throws -> CommandStatus {
        
        state = .querySent
        
        let executeRequest = ExecuteRequest(portalName: portalName, statement: statement)
        try await sendRequest(executeRequest, flush: true)

        let response = try await receiveResponse(type: CommandCompleteResponse.self)
        try await cleanupPortal(name: portalName)
        return response.status
    }
    
    func cleanupPortal(name: String) async throws {
        // Close the portal
        try await sendRequest(ClosePortalRequest(name: name), flush: true)
        try await receiveResponse(type: CloseCompleteResponse.self)
        
        // Finalize the transaction (unless already in BEGIN/COMMIT)
        try await sendRequest(SyncRequest(), flush: true)
        
        // transaction status always set on ReadyForQueryResponse
        try await receiveResponse(type: ReadyForQueryResponse.self)
    }
}
