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
        let portalName = UUID().uuidString
        let bindRequest = BindRequest(name: portalName, statement: statement, parameterValues: parameterValues)
        try await sendRequest(bindRequest)
        
        let flushRequest = FlushRequest()
        try await sendRequest(flushRequest)
        
        try await receiveResponse(type: BindCompleteResponse.self)
        
        var metadata: [ColumnMetadata]?
        if columnMetadata {
            metadata = try await retrieveColumnMetadata(portalName: portalName)
        }
        portalStatus[portalName] = .open
        
        return Portal(name: portalName, metadata: metadata, statement: statement, connection: self)
    }
    
    func cleanupPortal(name: String) async throws {
        // Close the portal
        try await sendRequest(ClosePortalRequest(name: name))
        try await sendRequest(FlushRequest())
        try await receiveResponse(type: CloseCompleteResponse.self)
        
        let status = portalStatus.removeValue(forKey: name)
        if status == nil {
            throw PostgresError.protocolError("Missing portal status for \(name)")
        }
        
        // Finalize the transaction (unless already in BEGIN/COMMIT)
        try await sendRequest(SyncRequest())
        
        // transaction status always set on ReadyForQueryResponse
        try await receiveResponse(type: ReadyForQueryResponse.self)
    }

}
