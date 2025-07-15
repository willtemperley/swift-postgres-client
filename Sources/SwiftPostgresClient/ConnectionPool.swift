//
//  ConnectionPool.swift
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

struct ConnectionLease {
    let connection: Connection
    private let pool: ConnectionPool

    init(connection: Connection, pool: ConnectionPool) {
        self.connection = connection
        self.pool = pool
    }

    func done() {
        Task { await pool.return(connection) }
    }

//    deinit {
//        Task { await pool.return(connection) }
//    }
}


actor ConnectionPool {
    private var available: [Connection] = []
    
    private var waiters: [CheckedContinuation<ConnectionLease, any Error>] = []

    private let maxConnections: Int
    private let factory: () async throws -> Connection

    init(maxConnections: Int, factory: @escaping @Sendable () async throws -> Connection) {
        self.maxConnections = maxConnections
        self.factory = factory

        Task.detached {
            for _ in 0..<maxConnections {
                do {
                    let conn = try await factory()
                    await self.return(conn)
                } catch {
                    print("Failed to create connection: \(error)")
                }
            }
        }
    }

    func lease() async throws -> ConnectionLease {
        // Fast path: take from available pool
        if let conn = available.popLast() {
            return ConnectionLease(connection: conn, pool: self)
        }

        // Slow path: suspend until a connection is returned
        return try await withCheckedThrowingContinuation { cont in
            waiters.append(cont)
        }
    }

    fileprivate func `return`(_ connection: Connection) {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: ConnectionLease(connection: connection, pool: self))
        } else {
            available.append(connection)
        }
    }

    func close() {
        // Optional: flush or invalidate pool
        waiters.forEach { $0.resume(throwing: CancellationError()) }
        waiters.removeAll()
        available.removeAll()
    }
}


