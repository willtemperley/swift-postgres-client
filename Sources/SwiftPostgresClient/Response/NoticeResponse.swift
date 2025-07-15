//
//  NoticeResponse.swift
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

struct NoticeResponse: Response {
    
    var responseType: Character { "N" }
    let notice: Notice

    init(responseBody: ResponseBody) throws {
        
        assert(responseBody.responseType == "N")
        var responseBody = responseBody
        
        var fields = [Character: String]()
        
        while try responseBody.peekUInt8() != 0 {
            let fieldType = try responseBody.readASCIICharacter()
            let fieldValue = try responseBody.readNullTerminatedString()
            fields[fieldType] = fieldValue
        }
        
        let _ = try responseBody.readUInt8() // the terminal 0
        notice = Notice(fields: fields)
        try responseBody.verifyFullyConsumed()
    }
    
    var description: String {
        "NoticeResponse (" +
            "severity: \(notice.severity ?? "nil"), " +
            "code: \(notice.code ?? "nil"), " +
            "message: \(notice.message ?? "nil")" +
        ")"
    }
}
