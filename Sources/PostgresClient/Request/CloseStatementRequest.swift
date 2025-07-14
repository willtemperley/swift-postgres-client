// CloseStatementRequest 2.swift
// PostgresClientKit
//
// Created by Will Temperley on 12/07/2025. All rights reserved.
// Copyright 2025 Will Temperley.
// 
// Copying or reproduction of this file via any medium requires prior express
// written permission from the copyright holder.
// -----------------------------------------------------------------------------
///
/// Implementation notes, links and internal documentation go here.
///
// -----------------------------------------------------------------------------



//
//  CloseStatementRequest.swift
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

struct CloseStatementRequest: Request {
    
    init(statement: Statement) {
        self.statement = statement
    }
    
    private let statement: Statement
    
    var requestType: Character? {
        return "C"
    }
    
    var body: Data {
        var body = "S".data                 // for "statement"
        body.append(statement.id.dataZero)  // name of the prepared statement
        return body
    }
}
