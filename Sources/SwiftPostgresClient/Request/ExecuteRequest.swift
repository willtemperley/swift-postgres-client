//
//  ExecuteRequest.swift
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

struct ExecuteRequest: Request {
    
    private let statement: Statement
    
    private let portalName: String

    init(portalName: String, statement: Statement) {
        self.statement = statement
        self.portalName = portalName
    }
    
    //
    // MARK: Request
    //
    
    var requestType: Character? {
        return "E"
    }
    
    var body: Data {
        var body = portalName.dataZero      // unnamed destination portal
        body.append(UInt32(0).data) // no row limit
        return body
    }
    
}
