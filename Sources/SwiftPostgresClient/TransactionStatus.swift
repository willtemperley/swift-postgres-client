//
//  TransactionStatus.swift
//  PostgresClientKit
//
//  Copyright 2021 David Pitfield and the PostgresClientKit contributors
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

/// Represents the transaction status of a PostgreSQL connection.
/// Derived from the ReadyForQuery message's status byte.
enum TransactionStatus: Character, Sendable {
    
    /// No transaction is in progress.
    case idle = "I"
    
    /// A transaction is in progress. Must be committed or rolled back.
    case activeTransaction = "T"
    
    /// A transaction has failed. Must be rolled back before continuing.
    case failedTransaction = "E"
}

extension TransactionStatus {
    var isInTransaction: Bool {
        self == .activeTransaction || self == .failedTransaction
    }
    
    var isFailed: Bool {
        self == .failedTransaction
    }
}
