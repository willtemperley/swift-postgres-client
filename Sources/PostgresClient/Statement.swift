//
//  Statement.swift
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

/// A prepared SQL statement.
///
/// Use `Connection.prepareStatement(text:)` to create a `Statement`.
///
/// Call `Statement.execute(parameterValues:retrieveColumnMetadata:)` to execute the `Statement`,
/// specifying the values of any parameters.
///
/// A `Statement` can be repeatedly executed, and the values of its parameters can be different
/// each time.
///
/// When a `Statement` is no longer required, call `Statement.close()` to release its Postgres
/// server resources.  A `Statement` is automatically closed by its deinitializer.
///
/// A `Statement` in PostgresClientKit corresponds to a prepared statement on the Postgres server
/// whose name is the `id` of the `Statement`.
public struct Statement: Sendable {
    
    /// Creates a `Statement`.
    ///
    /// - Parameters:
    ///   - connection: the `Connection`
    ///   - text: the SQL text
    init(text: String) {
        self.text = text
    }
    
    /// Uniquely identifies this `Statement`.
    ///
    /// The `id` of a `Statement` in PostgresClientKit is also the name of the prepared statement on
    /// the Postgres server.  The `id` is also used in logging and to formulate the `description`.
    public let id = "Statement-\(UUID()))"
    
    /// The SQL text.
    public let text: String
    
}
