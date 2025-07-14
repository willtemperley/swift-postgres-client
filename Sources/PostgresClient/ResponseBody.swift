// ResponseBody.swift
// PostgresClientKit
//
// Created by Will Temperley on 13/07/2025. All rights reserved.
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

    func verifyFullyConsumed() throws {
        guard offset == data.count else {
            throw PostgresError.protocolError("Unconsumed bytes in response")
        }
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

}
