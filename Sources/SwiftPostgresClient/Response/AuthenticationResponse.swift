// AuthenticationResponse.swift
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

enum AuthenticationResponse: Response {
    
    var responseType: Character { "R" }

    case ok
    case cleartextPassword
    case md5Password(salt: Data)
    case sasl(mechanisms: [String])
    case saslContinue(message: String)
    case saslFinal(message: String)
    case unsupported(type: UInt32)

    init(responseBody: ResponseBody) throws {
        precondition(responseBody.responseType == "R")

        var body = responseBody
        let type = try body.readUInt32()

        switch type {
        case 0:
            self = .ok

        case 3:
            self = .cleartextPassword

        case 5:
            let salt = body.readRemainingData()
            guard salt.count == 4 else {
                throw PostgresError.protocolError("Invalid MD5 password salt length")
            }
            self = .md5Password(salt: salt)

        case 10:
            var mechanisms: [String] = []
            while true {
                let str = try body.readNullTerminatedString()
                if str.isEmpty { break }
                mechanisms.append(str)
            }
            self = .sasl(mechanisms: mechanisms)

        case 11:
            let message = try body.readRemainingUTF8String()
            self = .saslContinue(message: message)

        case 12:
            let message = try body.readRemainingUTF8String()
            self = .saslFinal(message: message)

        default:
            self = .unsupported(type: type)
        }

        try body.verifyFullyConsumed()
    }

    var description: String {
        switch self {
        case .ok: return "AuthenticationOK"
        case .cleartextPassword: return "AuthenticationCleartextPassword"
        case .md5Password: return "AuthenticationMD5Password"
        case .sasl(let mechs): return "AuthenticationSASL(mechanisms: \(mechs))"
        case .saslContinue: return "AuthenticationSASLContinue"
        case .saslFinal: return "AuthenticationSASLFinal"
        case .unsupported(let type): return "UnsupportedAuthentication(type: \(type))"
        }
    }
}
