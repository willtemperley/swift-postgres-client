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
actor Connection {
    
    private var messageQueue: [Response] = []
    private var waiters: [CheckedContinuation<Response, Never>] = []
    private var socket: NetworkConnection
    
    let certificateHash: Data
    
    var transactionStatus: TransactionStatus = .idle
    
    var commandStatus: CommandStatus?
    private var portalStatus: [String: CommandStatus] = .init()
    
    private init(socket: NetworkConnection, certificateHash: Data) {
        self.socket = socket
        self.certificateHash = certificateHash
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
    
    func cancel() async {
        let terminateRequest = TerminateRequest()
        try? await sendRequest(terminateRequest) // consumes any Error
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
            let message = await receiveResponse()
            
            // TODO: non-command messages should be published as another async stream
            switch message {
            case let notification as NotificationResponse:
                print("notification: \(notification)")
            case let status as ParameterStatusResponse:
                print("parameter status: \(status)")
            case let keyData as BackendKeyDataResponse:
                print("backend key data: \(keyData)")
            case let notice as NoticeResponse:
                print("notice: \(notice)")
            default:
                // update transaction status
                if let readyForQuery = message as? ReadyForQueryResponse {
                    if let status = TransactionStatus(rawValue: readyForQuery.transactionStatus) {
                        self.transactionStatus = status
                    } else {
                        throw PostgresError.protocolError("Unknown transaction status: \(readyForQuery.transactionStatus)")
                    }
                }
                if let typed = message as? T {
                    return typed
                } else if let errorMessage = message as? ErrorResponse {
                    
                    print(errorMessage.description)
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
    
    func cleanupPortal(name: String) async throws {
        // Close the portal
        try await sendRequest(ClosePortalRequest(name: name))
        try await sendRequest(FlushRequest())
        try await receiveResponse(type: CloseCompleteResponse.self)
        portalStatus.removeValue(forKey: name)
        
        // Finalize the transaction (unless already in BEGIN/COMMIT)
        try await sendRequest(SyncRequest())
        
        // transaction status always set on ReadyForQueryResponse
        try await receiveResponse(type: ReadyForQueryResponse.self)
        
#if DEBUG
        print("Transaction status: \(self.transactionStatus)")
#endif
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
