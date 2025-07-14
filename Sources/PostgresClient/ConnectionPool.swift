// ConnectionPool.swift
// SwiftPostgresClient
//
// Created by Will Temperley on 14/07/2025. All rights reserved.
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


