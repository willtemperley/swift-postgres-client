//
//  NetworkConnection.swift
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

import Network
import Foundation

/// A wrapper for a network connection
struct NetworkConnection: Sendable {
    
    let connection: NWConnection
    
    func write(from data: Data) async throws {
        
        guard connection.state != .cancelled else {
            throw PostgresError.connectionClosed
        }
        
        try await withCheckedThrowingContinuation {  (continuation: CheckedContinuation<Void, Error>)  in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
        }
    }
    
    func read(maxLength: Int = 8192) async throws -> Data {
        guard connection.state != .cancelled else {
            throw PostgresError.connectionClosed
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            connection.receive(minimumIncompleteLength: 1, maximumLength: maxLength) { data, _, isComplete, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: PostgresError.connectionClosed)
                }
            }
        }
    }
    
    func readData(count: Int) async throws -> Data {
        guard count > 0 else { return Data() }

        var buffer = Data()
        buffer.reserveCapacity(count)

        while buffer.count < count {
            let chunk = try await read(maxLength: count - buffer.count)

            if chunk.isEmpty {
                throw PostgresError.protocolError("Unexpected EOF while reading \(count) bytes")
            }

            buffer.append(chunk)
        }

        return buffer
    }

    func readASCIICharacter() async throws -> Character {
        let data = try await read(maxLength: 1)
        
        guard let byte = data.first else {
            throw PostgresError.protocolError("No data received for response type")
        }

        let scalar = Unicode.Scalar(byte)
        guard scalar.isASCII else {
            throw PostgresError.protocolError("Invalid ASCII byte: \(byte)")
        }

        return Character(scalar)
    }
    
    func readUInt32() async throws -> UInt32 {
        let data = try await read(maxLength: 4)
        
        guard data.count == 4 else {
            throw PostgresError.protocolError("Expected 4 bytes for UInt32, got \(data.count)")
        }
        
        return data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
    }
    
    
    var connected: Bool {
        connection.state == .ready
    }
    
    func cancel() {
        connection.cancel()
    }
}
