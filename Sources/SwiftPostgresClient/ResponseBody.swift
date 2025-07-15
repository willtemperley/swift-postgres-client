//
//  ResponseBody.swift
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

import Foundation

struct ResponseBody: Sendable {
    let responseType: Character
    private let data: Data
    private var offset = 0

    init(responseType: Character, data: Data) {
        self.responseType = responseType
        self.data = data
    }
    
    func peekUInt8() throws -> UInt8 {
        guard offset < data.count else {
            throw PostgresError.protocolError("Unexpected end of data while reading UInt8")
        }
        return data[offset]
    }
    
    mutating func readUInt8() throws -> UInt8 {
        guard offset < data.count else {
            throw PostgresError.protocolError("Unexpected end of data while reading UInt8")
        }
        let value = data[offset]
        offset += 1
        return value
    }

    mutating func readUInt16() throws -> UInt16 {
        guard offset + 2 <= data.count else { throw PostgresError.protocolError("Not enough data") }
        let value = data[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        offset += 2
        return value
    }

    mutating func readUInt32() throws -> UInt32 {
        guard offset + 4 <= data.count else {
            throw PostgresError.protocolError("Not enough data")
        }

        let slice = data[offset..<offset+4]
        offset += 4
        return UInt32(bigEndian: slice.withUnsafeBytes {
            $0.loadUnaligned(as: UInt32.self)
        })
    }

    mutating func readUTF8String(byteCount: Int) throws -> String {
        guard offset + byteCount <= data.count else { throw PostgresError.protocolError("Not enough data") }
        let stringData = data[offset..<offset + byteCount]
        offset += byteCount
        guard let string = String(data: stringData, encoding: .utf8) else {
            throw PostgresError.protocolError("Invalid UTF-8")
        }
        return string
    }
    
    mutating func readASCIICharacter() throws -> Character {
        let byte = try readUInt8()

        guard byte <= 0x7F else {
            throw PostgresError.protocolError("Non-ASCII byte encountered: \(byte)")
        }
        return Character(UnicodeScalar(byte))
    }

    mutating func readRemainingUTF8String() throws -> String {
        let stringData = data[offset...]
        offset = data.endIndex

        guard let string = String(data: stringData, encoding: .utf8) else {
            throw PostgresError.protocolError("Invalid UTF-8 data")
        }

        return string
    }

    mutating func readNullTerminatedString() throws -> String {
        guard let nullIndex = data[offset...].firstIndex(of: 0) else {
            throw PostgresError.protocolError("Expected null terminator")
        }

        let stringData = data[offset..<nullIndex]
        offset = nullIndex + 1

        guard let str = String(data: stringData, encoding: .utf8) else {
            throw PostgresError.protocolError("Invalid UTF-8 in null-terminated string")
        }

        return str
    }
    
    mutating func readRemainingData() -> Data {
        let remaining = data[offset...]
        offset = data.count
        return Data(remaining)
    }

    func verifyFullyConsumed() throws {
        guard offset == data.count else {
            throw PostgresError.protocolError("Unconsumed bytes in response")
        }
    }
}
