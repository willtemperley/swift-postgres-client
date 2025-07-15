// QueryRequest.swift
// SwiftPostgresClient
//
// Created by Will Temperley on 15/07/2025. All rights reserved.
// Copyright 2025 Will Temperley.
// 
// Copying or reproduction of this file via any medium requires prior express
// written permission from the copyright holder.
// -----------------------------------------------------------------------------
///
/// Implementation notes, links and internal documentation go here.
///
// -----------------------------------------------------------------------------

import Foundation

struct QueryRequest: Request {
    
    let query: String

    var requestType: Character? { "Q" }

    var body: Data {
        query.dataZero
    }
}
