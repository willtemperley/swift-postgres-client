// Net.swift
// SwiftPostgresClient
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

import Network
import CryptoKit
import Foundation

func createPostgresConnection(host: String, port: UInt16) async throws -> (NWConnection, Data) {
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
        throw PostgresError.certificateRetrievelFailed
    }

    return (connection, certHash)
}

