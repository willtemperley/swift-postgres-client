//
//  Connection+metadata.swift
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

/// Methods to query connection status, using server state instead of attempting to track status client-side.
extension Connection {
    
    func listPreparedStatements() async throws -> [String] {
        
        let text = "SELECT name FROM pg_prepared_statements"
        
        let cursor = try await query(text)
        
        var data: [String] = .init()
        for try await row in cursor {
            data.append(try row.columns[0].string())
        }
        try await receiveResponse(type: ReadyForQueryResponse.self)
        return data
    }
    
    func listOpenPortals() async throws -> [String] {
        
        let text = "SELECT name FROM pg_cursor"
        
        let cursor = try await query(text)
        
        var data: [String] = .init()
        for try await row in cursor {
            data.append(try row.columns[0].string())
        }
        try await receiveResponse(type: ReadyForQueryResponse.self)
        return data
    }

    func statementClosed(_ name: String) async -> Bool {
        !openStatements.contains(name)
    }
    
}
