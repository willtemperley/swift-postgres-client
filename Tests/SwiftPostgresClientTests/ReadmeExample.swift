//
//  ReadmeExample.swift
//  SwiftPostgresClient
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

import SwiftPostgresClient

// This just ensures the README example compiles
func readmeExample() async throws {
    
    // Connect on the default port, returning a connection actor
    let connection = try await Connection.connect(host: "localhost")

    // Connect using TLS and SCRAM, enforcing channel binding
    let credential: Credential = .scramSHA256(password: "welcome1", channelBindingPolicy: .required)
    try await connection.authenticate(user: "bob", database: "postgres", credential: credential)

    // Prepare a statement
    let text = "SELECT city, temp_lo, temp_hi, prcp, date FROM weather WHERE city = $1;"
    let statement = try await connection.prepareStatement(text: text)

    // Bind the statement within a named portal.
    let portal = try await statement.bind(parameterValues: ["San Francisco"])

    // Obtain an AsyncSequence from the portal and iterate the results.
    let cursor = try await portal.query()

    for try await row in cursor {
      let columns = row.columns
      let city = try columns[0].string()
      let tempLo = try columns[1].int()
      let tempHi = try columns[2].int()
      let prcp = try columns[3].optionalDouble()
      let date = try columns[4].date()
       print("""
        \(city) on \(date): low: \(tempLo), high: \(tempHi), \
        precipitation: \(String(describing: prcp))
       """)
    }
    
    let rowCount = await cursor.rowCount
}
