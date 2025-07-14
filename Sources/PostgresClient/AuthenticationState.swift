// AuthenticationState.swift
// PostgresClientKit
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

enum AuthenticationState {
    case start
    case awaitingCleartextPassword(String)
    case awaitingMd5Password(String, [UInt8])
    case awaitingSaslInitial([String])
    case awaitingSaslContinue(SCRAMSHA256Authenticator)
    case awaitingSaslFinal(SCRAMSHA256Authenticator)
    case awaitingOK
    case done
}

extension Connection {
    
    func computeMd5Password(user: String, password: String, salt: Data) -> String {
        
        // Compute concat('md5', md5(concat(md5(concat(password, username)), random-salt))).
        var passwordUser = password.data
        passwordUser.append(user.data)
        let passwordUserHash = Crypto.md5(data: passwordUser).hexEncodedString()
        
        var salted = passwordUserHash.data
        salted.append(contentsOf: salt)
        let saltedHash = Crypto.md5(data: salted).hexEncodedString()
        return "md5" + saltedHash
    }
    
    func selectScramMechanism(mechanisms: [String], policy: ChannelBindingPolicy, certificateHash: Data) throws -> (String, SCRAMSHA256Authenticator.ChannelBinding)  {
        
        guard mechanisms.contains("SCRAM-SHA-256") else {
            throw PostgresError.unsupportedAuthenticationType(
                authenticationType: "SCRAM-SHA-256")
        }
        
        let channelBinding: SCRAMSHA256Authenticator.ChannelBinding
        
        let supportsPlus = mechanisms.contains("SCRAM-SHA-256-PLUS")
        let supportsPlain = mechanisms.contains("SCRAM-SHA-256")
        
        let mechanism: String
        
        switch policy {
        case .required:
            guard supportsPlus else {
                throw PostgresError.unsupportedAuthenticationType(
                    authenticationType: "SCRAM-SHA-256-PLUS not supported by server.")
            }
            mechanism = "SCRAM-SHA-256-PLUS"
            //                    log(.fine, "\(mechanism) supported; Using channel binding.")
            channelBinding = .requiredByClient(channelBindingName: "tls-server-end-point", channelBindingData: certificateHash)
            
        case .preferred:
            if supportsPlus {
                mechanism = "SCRAM-SHA-256-PLUS"
                //                        log(.fine, "\(mechanism) supported; Using channel binding.")
                channelBinding = .requiredByClient(channelBindingName: "tls-server-end-point", channelBindingData: certificateHash)
            } else if supportsPlain {
                mechanism = "SCRAM-SHA-256"
                //                        log(.warning, "Server does not support SCRAM-SHA-256-PLUS; falling back to \(mechanism). MitM attacks are possible.")
                channelBinding = .notSupportedByServer
            } else {
                throw PostgresError.unsupportedAuthenticationType(
                    authenticationType: "Neither SCRAM-SHA-256 nor SCRAM-SHA-256-PLUS supported by server.")
            }
        }
        return (mechanism, channelBinding)
    }
}
