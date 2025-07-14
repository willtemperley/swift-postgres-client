//
//  Request.swift
//  PostgresClientKit
//
//  Copyright 2019 David Pitfield and the PostgresClientKit contributors
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

protocol Request: Sendable {
    /// The request type (optional for some messages like SSLRequest).
    var requestType: Character? { get }

    /// The body of the request (excluding the type and length prefix).
    var body: Data { get }
}

extension Request {
    /// The encoded request: type (optional) + 4-byte length + body
    func data() -> Data {
        var request = Data()

        if let requestType = requestType {
            request.append(String(requestType).data)
        }

        let body = self.body
        let length = UInt32(body.count + 4) // includes 4 bytes for length itself
        request.append(length.data)
        request.append(body)

        return request
    }
}
