//
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
import Network
import CryptoKit

/// A Connection actor provides asynchronous access to a PostgreSQL server.
public actor Connection {
    
    enum ConnectionState {
        case awaitingAuthentication
        case ready
        case querySent
        case awaitingQueryResult
        case errorRecieved
        case closed
    }
    
    private var messageQueue: [Response] = []
    private var waiters: [CheckedContinuation<Response, Never>] = []
    private var socket: NetworkConnection
    
    let certificateHash: Data
    
    var state: ConnectionState = .closed
    var transactionStatus: TransactionStatus = .idle
    
    var commandStatus: CommandStatus?
    
    var openStatements: Set<String> = .init()
    
    public let notifications: AsyncStream<ServerMessage>
    private let notificationContinuation: AsyncStream<ServerMessage>.Continuation
    
    private init(socket: NetworkConnection, certificateHash: Data) {
        self.socket = socket
        self.certificateHash = certificateHash
        precondition(socket.connected)
        self.state = .awaitingAuthentication
        
        // Set up the notification stream
        var continuation: AsyncStream<ServerMessage>.Continuation!
        self.notifications = AsyncStream { c in
            continuation = c
        }
        self.notificationContinuation = continuation
        
        // Start the message queue
        Task { await receiveLoop() }
    }
    
    /// Connect to a server.
    /// - Parameters:
    ///   - host: The host
    ///   - port: The port
    /// - Returns: A connection ready for authentication.
    public static func connect(
        host: String,
        port: Int = 5432
    ) async throws -> Connection {
        
        let (nwConnection, certificateHash) = try await createPostgresConnection(host: host, port: UInt16(port))
        
        let socket = NetworkConnection(connection: nwConnection)
        
        return Connection(
            socket: socket,
            certificateHash: certificateHash,
        )
    }
    
    public func close() async {
        let terminateRequest = TerminateRequest()
        try? await sendRequest(terminateRequest) // consumes any Error
        state = .closed
        openStatements = .init()
        socket.cancel()
    }
    
    var connected: Bool {
        socket.connected
    }
    
    var closed: Bool {
        state == .closed
    }
    
    private func receiveLoop() async {
        while true {
            do {
                try await decodeMessage()
            } catch {
                print("Error receiving message: \(error)")
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
            let message = messageQueue.removeFirst()
            updateState(for: message)
            return message
        }
        
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func updateState(for response: Response) {
        switch response {
        case is DataRowResponse, is RowDescriptionResponse:
            state = .awaitingQueryResult
            
        case is ReadyForQueryResponse:
            state = .ready
            
        case is ErrorResponse:
            state = .errorRecieved  // or maybe .errorRecovering?
            
        default:
            // no change
            break
        }
    }
    
    private func emitNotification(_ notification: ServerMessage) {
        notificationContinuation.yield(notification)
    }

    public func closeNotificationStream() {
        notificationContinuation.finish()
    }
    
    @discardableResult
    func receiveResponse<T: Response>(type: T.Type) async throws -> T {
        while true {
            let message = await receiveResponse()
            
            // TODO: non-command messages should be published as another async stream
            switch message {
            case let notification as NotificationResponse:
                emitNotification(.notification(pid: Int32(notification.processId), channel: notification.channel, payload: notification.payload))
            case let status as ParameterStatusResponse:
                try await Parameter.checkParameterStatusResponse(status, connection: self)
                emitNotification(.parameter(name: status.name, value: status.value))
            case let keyData as BackendKeyDataResponse:
                emitNotification(.backendKeyData(pid: keyData.processID, secretKey: keyData.secretKey))
                continue
            case let notice as NoticeResponse:
                emitNotification(.notice(description: notice.description))
            default:
                // update transaction status
                if let readyForQuery = message as? ReadyForQueryResponse {
                    state = .ready
                    if let status = TransactionStatus(rawValue: readyForQuery.transactionStatus) {
                        self.transactionStatus = status
                    } else {
                        throw PostgresError.protocolError("Unknown transaction status: \(readyForQuery.transactionStatus)")
                    }
                }
                if let typed = message as? T {
                    return typed
                } else if let errorMessage = message as? ErrorResponse {
                    
                    state = .errorRecieved
                    throw PostgresError.protocolError(errorMessage.description)
                } else {
                    throw PostgresError.protocolError("Unexpected message type: \(message)")
                }
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
        // TODO: consider serializing multiple requests to the server - it's common that a command will be followed by a flush
        try await socket.write(from: request.data())
    }
    
    func recoverIfNeeded() async throws {
        switch state {
        case .ready:
            return
            
        case .querySent, .awaitingQueryResult, .errorRecieved:
            logWarning("State is \(state), emptying message queue and sending sync request.")
            
            try await sendRequest(SyncRequest())
            try await sendRequest(FlushRequest())
            
            // Cleanup all open portals
//            for name in try await listOpenPortals() {
//                try await sendRequest(ClosePortalRequest(name: name))
//                try await sendRequest(FlushRequest())
//            }

            // Drain all messages until ReadyForQuery
            while true {
                guard connected else {
                    state = .closed
                    throw PostgresError.connectionClosed
                }
                let message = await receiveResponse()
                updateState(for: message)
                if message is ReadyForQueryResponse { break }
            }

            precondition(state == .ready)

        case .closed:
            throw PostgresError.connectionClosed

        case .awaitingAuthentication:
            throw PostgresError.awaitingAuthentication
        }
    }
}

/// Create a connection to a PostgreSQL server.
/// - Parameters:
///   - host: The host
///   - port: The port
/// - Returns:connection in ready state and the server certificate hash.
fileprivate func createPostgresConnection(host: String, port: UInt16) async throws -> (NWConnection, Data) {
    let tlsOptions = NWProtocolTLS.Options()
    let secProtocolOptions = tlsOptions.securityProtocolOptions
    
    "postgresql".withCString {
        sec_protocol_options_add_tls_application_protocol(secProtocolOptions, $0)
    }
    
    var certHash: Data? = nil
    
    sec_protocol_options_set_verify_block(
        secProtocolOptions,
        { metadata, trustRef, verifyComplete in
            let trust = sec_trust_copy_ref(trustRef).takeRetainedValue()
            let isLocalhost = ["localhost", "127.0.0.1", "::1"].contains(host)
            
            func complete(with cert: SecCertificate?) {
                guard let cert = cert else {
                    verifyComplete(false)
                    return
                }
                
                let data = SecCertificateCopyData(cert) as Data
                let hash = SHA256.hash(data: data)
                certHash = Data(hash)
                verifyComplete(true)
            }
            
            if isLocalhost {
                complete(with: SecTrustGetCertificateAtIndex(trust, 0))
            } else {
                var error: CFError?
                if SecTrustEvaluateWithError(trust, &error) {
                    complete(with: SecTrustGetCertificateAtIndex(trust, 0))
                } else {
                    verifyComplete(false)
                }
            }
        },
        DispatchQueue.global(qos: .utility)
    )
    
    let parameters = NWParameters(tls: tlsOptions)
    let connection = NWConnection(host: .init(host), port: .init(rawValue: port)!, using: parameters)
    
    try await withCheckedThrowingContinuation { cont in
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready: cont.resume(returning: ())
            case .failed(let error): cont.resume(throwing: error)
            default: break
            }
        }
        
        connection.start(queue: .global(qos: .userInitiated))
    }
    
    guard let certHash = certHash else {
        throw PostgresError.certificateRetrievalFailed
    }
    
    return (connection, certHash)
}
