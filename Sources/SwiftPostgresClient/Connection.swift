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
internal import os

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
    private var waiters: [CheckedContinuation<Response, Error>] = []
    private var socket: NetworkConnection
    
    let certificateHash: Data
    
    var state: ConnectionState = .closed
    var transactionStatus: TransactionStatus = .idle
    
    var commandStatus: CommandStatus?
    
    var openStatements: Set<String> = .init()
    
    public let notifications: AsyncStream<ServerMessage>
    private let notificationContinuation: AsyncStream<ServerMessage>.Continuation
    private let flushBytes: [UInt8] = [0x48, 0x00, 0x00, 0x00, 0x04]
    
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
    ///   - useTLS: Whether to use TLS (default: true)
    /// - Returns: A connection ready for authentication.
    public static func connect(
        host: String,
        port: Int = 5432,
        useTLS: Bool = true
    ) async throws -> Connection {
        
        let (nwConnection, certificateHash) = try await createPostgresConnection(host: host, port: UInt16(port), useTLS: useTLS)
        
        let socket = NetworkConnection(connection: nwConnection)
        
        return Connection(
            socket: socket,
            certificateHash: certificateHash,
        )
    }
    
    public func close() async {
        try? await sendRequest(TerminateRequest())
        tearDown()
        openStatements = .init()
        socket.cancel()
    }

    var connected: Bool {
        socket.connected
    }
    
    var closed: Bool {
        state == .closed
    }
    
    private func tearDown() {
        state = .closed
        let pending = waiters
        waiters.removeAll()
        for w in pending { w.resume(throwing: PostgresError.connectionClosed) }
        notificationContinuation.finish()
    }

    private func receiveLoop() async {
        while true {
            do {
                try await decodeMessage()
            } catch {
                tearDown()
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
    
    func receiveResponse() async throws -> Response {
        if !messageQueue.isEmpty {
            let message = messageQueue.removeFirst()
            updateState(for: message)
            return message
        }
        // If the connection already died, don't suspend on a continuation
        // nobody will ever resume.
        guard state != .closed else {
            throw PostgresError.connectionClosed
        }
        return try await withCheckedThrowingContinuation { continuation in
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
            let message = try await receiveResponse()
            
            // Publish server notices and parameter changes to the notifications AsyncStream
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
        guard responseLength >= 4 else {
            throw PostgresError.protocolError("Invalid message length: \(responseLength)")
        }
        guard responseLength <= 0x7FFF_FFFF else {  // Int32 max — protocol ceiling
            throw PostgresError.protocolError("Message length exceeds protocol maximum: \(responseLength)")
        }
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
    
    func sendRequest(_ request: Request, flush: Bool = false) async throws {
        var data = request.data()
        if flush {
            data.append(contentsOf: flushBytes)
        }
        try await socket.write(from: data)
    }
    
    func recoverIfNeeded() async throws {
        switch state {
        case .ready:
            return
        case .querySent, .awaitingQueryResult, .errorRecieved:
            logWarning("State is \(state), emptying message queue and sending sync request.")
            try await sendRequest(SyncRequest(), flush: true)
            // Drain all messages until ReadyForQuery
            while true {
                guard connected else {
                    state = .closed
                    throw PostgresError.connectionClosed
                }
                let message = try await receiveResponse()
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
///   - useTLS: Whether to use TLS (default: true)
/// - Returns:connection in ready state and the server certificate hash.
fileprivate func createPostgresConnection(
    host: String,
    port: UInt16,
    useTLS: Bool = true,
) async throws -> (NWConnection, Data) {
    let parameters: NWParameters
    let certHashBox = OSAllocatedUnfairLock<Data?>(initialState: useTLS ? nil : Data())
    if useTLS {
        let tlsOptions = NWProtocolTLS.Options()
        let secProtocolOptions = tlsOptions.securityProtocolOptions
        "postgresql".withCString {
            sec_protocol_options_add_tls_application_protocol(secProtocolOptions, $0)
        }
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
                    certHashBox.withLock { $0 = Data(hash) }
                    verifyComplete(true)
                }
                let secCert = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first
                if isLocalhost {
                    complete(with: secCert)
                } else {
                    var error: CFError?
                    if SecTrustEvaluateWithError(trust, &error) {
                        complete(with: secCert)
                    } else {
                        verifyComplete(false)
                    }
                }
            },
            DispatchQueue.global(qos: .utility)
        )
        parameters = NWParameters(tls: tlsOptions)
    } else {
        // Plain TCP connection
        parameters = NWParameters.tcp
    }
    let connection = NWConnection(
        host: .init(host),
        port: .init(rawValue: port)!,
        using: parameters
    )
    try await withCheckedThrowingContinuation { cont in
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                // Replace handler on connection to prevent the continuation
                // being called more than once.
                connection.stateUpdateHandler = { [weak connection] state in
                    if case .failed = state {
                        connection?.cancel()
                    }
                }
                cont.resume(returning: ())
            case .failed(let error):
                connection.stateUpdateHandler = nil
                cont.resume(throwing: error)
            case .waiting(let reason):
                // NWConnection considers this recoverable and would retry
                // indefinitely. Nil out the state update handler to prevent
                // an attempted resume and crash on the spent continuation.
                connection.stateUpdateHandler = nil
                cont.resume(throwing: reason)
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global(qos: .userInitiated))
    }
    guard let certHash = certHashBox.withLock({ $0 }) else {
        // Avoid leaking the live connection with no certificate available.
        // Note that the localhost
        connection.cancel()
        throw PostgresError.certificateRetrievalFailed
    }
    return (connection, certHash)
}
