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

/// Transaction convenience methods
extension Connection {
    
    public func beginTransaction() async throws {
        try await execute("BEGIN;")
    }
    
    public func commitTransaction() async throws {
        try await execute("COMMIT;")
    }
    
    func rollback() async throws {
        try await execute("ROLLBACK;")
    }

    /// Runs a block within a transaction. Commits on success, rolls back on error.
    func withTransaction<T>(_ operation: @Sendable () async throws -> T) async throws -> T where T: Sendable {
        try await beginTransaction()
        do {
            let result = try await operation()
            try await commitTransaction()
            return result
        } catch {
            try await sendRequest(SyncRequest())
            try await receiveResponse(type: ReadyForQueryResponse.self)
            if transactionStatus == .failedTransaction {
                try await rollback()
            }
            throw error
        }
    }
}
