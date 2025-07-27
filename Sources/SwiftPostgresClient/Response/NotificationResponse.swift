//
//  NotificationResponse.swift
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

struct NotificationResponse: Response {
    
    var responseType: Character { "A" }
    let processId: UInt32
    let channel: String
    let payload: String

    init(responseBody: ResponseBody) throws {
        
        assert(responseBody.responseType == "A")
        
        var responseBody = responseBody
        
        processId = try responseBody.readUInt32()
        channel = try responseBody.readNullTerminatedString()
        payload = try responseBody.readNullTerminatedString()
        
        try responseBody.verifyFullyConsumed()
    }
    
    var description: String {
        "NotificationResponse(" +
            "processId: \(processId), " +
            "channel: \(channel), " +
            "payload: \(payload)" +
        ")"
    }
}
