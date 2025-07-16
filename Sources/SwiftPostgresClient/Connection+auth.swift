//
//  Connection+auth.swift
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

extension Connection {
    
    /// Asynchronously authenticate to the server.
    /// - Parameters:
    ///   - user: The database user.
    ///   - database: The database to connect to.
    ///   - credential: The credential the user authenticates with.
    public func authenticate(user: String, database: String, credential: Credential) async throws {
        
        try await sendRequest(StartupRequest(user: user, database: database, applicationName: "SwiftPostgresClient"))

        var state: AuthenticationState = .start
        var authenticationRequestSent = false

        authLoop:
        while true {
            let authResponse = try await receiveResponse(type: AuthenticationResponse.self)
            state = try await handleAuthenticationStep(state: state,
                                                       response: authResponse,
                                                       user: user,
                                                       credential: credential,
                                                       authenticationRequestSent: &authenticationRequestSent)
            if case .done = state {
                break authLoop
            }
        }

        try await receiveResponse(type: ReadyForQueryResponse.self)

        if !authenticationRequestSent {
            // Postgres allowed trust authentication, yet a cleartextPassword,
            // md5Password, or scramSHA256 credential was supplied.  Throw to
            // alert of a possible Postgres misconfiguration.
            guard case .trust = credential else {
                throw PostgresError.trustCredentialRequired
            }
        }
    }

    private func handleAuthenticationStep(
        state: AuthenticationState,
        response: AuthenticationResponse,
        user: String,
        credential: Credential,
        authenticationRequestSent: inout Bool
    ) async throws -> AuthenticationState {
        switch response {
        case .ok:
            return .done
        case .cleartextPassword:
            guard case let .cleartextPassword(password) = credential else {
                throw PostgresError.cleartextPasswordCredentialRequired
            }
            try await sendRequest(PasswordMessageRequest(password: password))
            authenticationRequestSent = true
            return .awaitingOK

        case .md5Password(let salt):
            guard case let .md5Password(password) = credential else {
                throw PostgresError.md5PasswordCredentialRequired
            }
            let md5Password = computeMd5Password(user: user, password: password, salt: salt)
            try await sendRequest(PasswordMessageRequest(password: md5Password))
            authenticationRequestSent = true
            return .awaitingOK

        case .sasl(let mechanisms):
            guard case let .scramSHA256(password, policy) = credential else {
                throw PostgresError.scramSHA256CredentialRequired
            }
            let (mechanism, channelBinding) = try selectScramMechanism(mechanisms: mechanisms, policy: policy, certificateHash: certificateHash)
            let authenticator = SCRAMSHA256Authenticator(user: user, password: password, selectedChannelBinding: channelBinding)
            let clientFirst = try authenticator.prepareClientFirstMessage()
            let saslInitialRequest = SASLInitialRequest(mechanism: mechanism, clientFirstMessage: clientFirst)
            try await sendRequest(saslInitialRequest)
            authenticationRequestSent = true
            return .awaitingSaslContinue(authenticator)

        case .saslContinue(let message):
            guard case .awaitingSaslContinue(let authenticator) = state else {
                throw PostgresError.serverError(description: "Unexpected saslContinue state")
            }
            try authenticator.processServerFirstMessage(message)
            let final = try authenticator.prepareClientFinalMessage()
            try await sendRequest(SASLRequest(clientFinalMessage: final))
            return .awaitingSaslFinal(authenticator)

        case .saslFinal(let message):
            guard case let .awaitingSaslFinal(authenticator) = state else {
                throw PostgresError.serverError(description: "Unexpected saslFinal state")
            }
            try authenticator.processServerFinalMessage(message)
            return .awaitingOK

        default:
            throw PostgresError.protocolError("\(response) not handled")
        }
    }

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
