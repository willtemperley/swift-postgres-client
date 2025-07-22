//
//  Connection+transaction.swift
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

/// Execution of queries without using extended query protocol.
extension Connection {
    
    func execute(_ sql: String) async throws {
        if state != .ready {
            throw PostgresError.invalidState("Expected ready state, got \(state)")
        }
        let queryRequest = QueryRequest(query: sql)
        try await sendRequest(queryRequest)
        try await receiveResponse(type: CommandCompleteResponse.self)
        try await receiveResponse(type: ReadyForQueryResponse.self)
    }
    
    func query(_ sql: String) async throws -> ResultCursor {
        if state != .ready {
            throw PostgresError.invalidState("Expected ready state, got \(state)")
        }
        let queryRequest = QueryRequest(query: sql)
        try await sendRequest(queryRequest)
        try await receiveResponse(type: RowDescriptionResponse.self)
        let response = await receiveResponse()
        return ResultCursor(connection: self, portalName: "", extendedProtocol: false, initialResponse: response)
    }
}
