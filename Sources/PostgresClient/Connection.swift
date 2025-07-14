//  Connection.swift
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

actor Connection {
    
    private var messageQueue: [Response] = []
    private var waiters: [CheckedContinuation<Response, Never>] = []
    private var socket: NetworkConnection
    
    private let certificateHash: Data
    
    private init(socket: NetworkConnection, certificateHash: Data) {
        self.socket = socket
        self.certificateHash = certificateHash
        Task { await receiveLoop() }
    }

    public static func connect(
        configuration: ConnectionConfiguration
    ) async throws -> Connection {
        
        let (nwConnection, certificateHash) = try await createPostgresConnection(host: configuration.host, port: UInt16(configuration.port))
        
        let socket = NetworkConnection(connection: nwConnection)
        
        return Connection(
            socket: socket,
            certificateHash: certificateHash,
        )
    }
    
    func cancel() {
        socket.cancel()
    }
    
    var connected: Bool {
        socket.connected
    }

    private func receiveLoop() async {
        while true {
            do {
                try await decodeMessage()
            } catch {
                print("Error receiving message: \(error)")
//                handleError(error)
                break
            }
        }
    }

    private func handleIncoming(_ message: Response) {
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume(returning: message)
        } else {
            messageQueue.append(message)
        }
    }

    func receiveResponse() async -> Response {
        if !messageQueue.isEmpty {
            return messageQueue.removeFirst()
        }

        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    @discardableResult
    func receiveResponse<T: Response>(type: T.Type) async throws -> T {
        while true {
            let message = await receiveResponse() // could be side-effect-only

            if let typed = message as? T {
                return typed
            }

            // Process known side-effect messages here
            switch message {
            case let notification as NotificationResponse:
//                await handleNotification(notification)
                print("notification: \(notification)")

            case let status as ParameterStatusResponse:
//                handleParameterStatus(status)
                print("parameter status: \(status)")

            case let keyData as BackendKeyDataResponse:
//                handleBackendKeyData(keyData)
                print("backend key data: \(keyData)")

            default:
                throw PostgresError.protocolError("Unexpected message type: \(message)")
            }
        }
    }

    private func decodeMessage() async throws {
        
        let responseType = try await socket.readASCIICharacter()
        let responseLength = try await socket.readUInt32()
        // The response length includes itself (4 bytes) but excludes the response type (1 byte).
        let body = try await socket.readData(count: Int(responseLength) - 4)
        let responseBody = ResponseBody(responseType: responseType, data: body)
        
        let response: Response
        
        switch responseType {
            
        case "1": response = try ParseCompleteResponse(responseBody: responseBody)
        case "2": response = try BindCompleteResponse(responseBody: responseBody)
        case "3": response = try CloseCompleteResponse(responseBody: responseBody)
        case "A": response = try NotificationResponse(responseBody: responseBody)
        case "C": response = try CommandCompleteResponse(responseBody: responseBody)
        case "D": response = try DataRowResponse(responseBody: responseBody)
        case "E": response = try ErrorResponse(responseBody: responseBody)
        case "I": response = try EmptyQueryResponse(responseBody: responseBody)
        case "K": response = try BackendKeyDataResponse(responseBody: responseBody)
        case "N": response = try NoticeResponse(responseBody: responseBody)
        case "R": response = try AuthenticationResponse(responseBody: responseBody)
        case "S": response = try ParameterStatusResponse(responseBody: responseBody)
        case "T": response = try RowDescriptionResponse(responseBody: responseBody)
        case "Z": response = try ReadyForQueryResponse(responseBody: responseBody)
        case "n": response = try NoDataResponse(responseBody: responseBody)
            
        default:
            throw PostgresError.serverError(
                description: "unrecognized response type '\(responseType)'")
        }
        
        handleIncoming(response)
    }
    
    func sendRequest(_ request: Request) async throws {
        try await socket.write(from: request.data())
    }

    public func authenticate(user: String, database: String, credential: Credential) async throws {
        try await sendRequest(StartupRequest(user: user, database: database, applicationName: "PostgresClientKit"))

        var state: AuthenticationState = .start
        var authenticationRequestSent = false

        authLoop:
        while true {
            let authResponse = try await receiveResponse(type: AuthenticationResponse.self)
            print("authResponse: \(authResponse)")

            state = try await handleAuthenticationStep(state: state,
                                                       response: authResponse,
                                                       user: user,
                                                       credential: credential,
                                                       authenticationRequestSent: &authenticationRequestSent)
            print(state)
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
            return .done

        case .md5Password(let salt):
            guard case let .md5Password(password) = credential else {
                throw PostgresError.md5PasswordCredentialRequired
            }
            let md5Password = computeMd5Password(user: user, password: password, salt: salt)
            try await sendRequest(PasswordMessageRequest(password: md5Password))
            authenticationRequestSent = true
            return .done

        case .sasl(let mechanisms):
            guard case let .scramSHA256(password, policy) = credential else {
                throw PostgresError.scramSHA256CredentialRequired
            }
            let (mechanism, channelBinding) = try selectScramMechanism(mechanisms: mechanisms, policy: policy, certificateHash: certificateHash)
            let authenticator = SCRAMSHA256Authenticator(user: user, password: password, selectedChannelBinding: channelBinding)
            let clientFirst = try authenticator.prepareClientFirstMessage()
            let saslInitialRequest = SASLInitialRequest(mechanism: mechanism, clientFirstMessage: clientFirst)
            print(saslInitialRequest.data().hexEncodedString())
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

    func cleanupPortal() async throws {
        // Close the portal
        try await sendRequest(ClosePortalRequest())
        try await sendRequest(FlushRequest())
        try await receiveResponse(type: CloseCompleteResponse.self)
        
        // Finalize the transaction (unless already in BEGIN/COMMIT)
        try await sendRequest(SyncRequest())
        try await receiveResponse(type: ReadyForQueryResponse.self)
    }
}
