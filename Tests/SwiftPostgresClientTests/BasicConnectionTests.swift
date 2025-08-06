//
//  BasicConnectionTests.swift
//  SwiftPostgresClient
//
//  Copyright 2025 Will Temperley and the SwiftPostgresClient contributors.
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

@testable import SwiftPostgresClient
import Testing
import Network

public struct BasicConnectionTests {
    
    static let environments: [TestEnvironment] = [
        .init(postgresPort: 5432, useTLS: false),
        .init(postgresPort: 5432, useTLS: true),
        .init(postgresPort: 5433, useTLS: false)
    ]
    
    static let invalidEnvironments: [TestEnvironment] = [
        .init(postgresPort: 5433, useTLS: true), // Connect using TLS to a server configured without SSL
        .init(postgresPort: 5434, useTLS: true)  // Not running at all
    ]
    
    @Test("Clean-fail invalid connections", arguments: invalidEnvironments) func cleanFail(environment: TestEnvironment) async throws {
        
        let configurations = TestConfigurations(environment: environment)
        let config = configurations.sallyConnectionConfiguration
        
        let error = await #expect(throws: NWError.self) {
            _ = try await Connection.connect(host: config.host, port: config.port, useTLS: config.useTLS)
        }
        
        switch environment.postgresPort {
        case 5433:
            // This happens when attempting to connect to a non-SSL server using TLS
            #expect(error?.errorCode == -9816)
        case 5434:
            // Connection refused; the server isn't running.
            #expect(error?.errorCode == 61)
        default:
            break;
        }
    }
    
    @Test("Query weather table", arguments: environments) func basicQuery(environment: TestEnvironment) async throws {
        
        let configurations = TestConfigurations(environment: environment)
        
        try await withWeatherTable(config: configurations.sallyConnectionConfiguration) { connection in
            
            let text = "SELECT city, temp_lo, temp_hi, prcp, date FROM weather WHERE city = $1;"
            let statement = try await connection.prepareStatement(text: text)
            let portal = try await statement.bind(parameterValues: ["San Francisco"])
            
            let cursor = try await portal.query()
            
            var count = 0
            for try await row in cursor {
                count += 1
                print(row)
                row.columns.forEach { (column) in
                    print("\(column.description)")
                }
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
            #expect(rowCount == 2)
            #expect(rowCount == count)
            
            // Reuse the same statement with a different portal
            let portal2 = try await statement.bind(parameterValues: ["Hayward"])
            let cursor2 = try await portal2.query()
            for try await row in cursor2 {
                count += 1
                print(row)
                row.columns.forEach { (column) in
                    print("\(column.description)")
                }
            }
            let rowCount2 = await cursor2.rowCount
            #expect(rowCount2 == 1)
        }
    }
    
    @Test("Rollback test", arguments: environments) func transactionRollback(environment: TestEnvironment) async throws {
        
        let configurations = TestConfigurations(environment: environment)
        
        let config = configurations.sallyConnectionConfiguration
        let connection = try await Connection.connect(host: config.host)
        try await connection.authenticate(user: config.user, database: config.database, credential: config.credential)
        
        try await connection.execute("DROP TABLE IF EXISTS notes")
        
        await #expect(throws: PostgresError.self) {
            try await connection.withTransaction {
                let statement = try await connection.prepareStatement(text: "INSERT INTO notes (text) VALUES ($1)")
                let portal = try await statement.bind(parameterValues: ["Hello, world"])
                _ = try await portal.execute()
            }
        }
        
        await #expect(connection.transactionStatus == .idle)
    }
}
