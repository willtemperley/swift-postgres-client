//
//  StatementTest.swift
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

@testable import SwiftPostgresClient
import Testing

/// Tests Statement.
struct StatementTest {
    
    @Test func testPrepareStatement() async throws {
        
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            
            // Success case
            // Throws if invalid SQL text
            await #expect(throws: Never.self) {
                _ = try await connection.prepareStatement(text: "SELECT * FROM weather")
            }
            
            // Throws if invalid SQL text
            await #expect(throws: PostgresError.self) {
                try await connection.prepareStatement(text: "invalid-text")
            }
            
            // Throws if connection closed
            await connection.close()
            let text = "SELECT * FROM weather"
            await #expect(throws: PostgresError.self) {
                try await connection.prepareStatement(text: text)
            }
            
        }
    }
    
    @Test func testPrepareStatementCursor() async throws {
        
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            // Closes an open, undrained cursor
            do {
                let text = "SELECT * FROM weather"
                let statement1 = try await connection.prepareStatement(text: text)
                _ = try await statement1.query()
                
                //                let statements = try await connection.listPreparedStatements()
                //                #expect(statements.count == 1)
                
                #expect(await !statement1.closed)
                
                await #expect(throws: PostgresError.self) {
                    try await connection.prepareStatement(text: text)
                }
                #expect(!(await statement1.closed))
                //                    XCTAssertTrue(cursor1.isClosed)
            }
        }
        //
        //                // Closes an open, drained cursor
        //                do {
        //                    let connection = try Connection(configuration: terryConnectionConfiguration())
        //                    let text = "SELECT * FROM weather"
        //                    let statement1 = try connection.prepareStatement(text: text)
        //                    let cursor1 = try statement1.execute()
        //                    while cursor1.next() != nil { }
        //                    XCTAssertFalse(statement1.isClosed)
        //                    XCTAssertFalse(cursor1.isClosed)
        //                    XCTAssertNil(cursor1.next()) // "drained"
        //                    let statement2 = try connection.prepareStatement(text: text)
        //                    XCTAssertFalse(statement1.isClosed)
        //                    XCTAssertTrue(cursor1.isClosed)
        //                    XCTAssertFalse(statement2.isClosed)
        //                }
    }
    
    @Test func testStatementLifecycle() async throws {
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            
            let text = "SELECT * FROM weather"
            let statement1 = try await connection.prepareStatement(text: text)
            let statement2 = try await connection.prepareStatement(text: text)
            
            
            // Each statement has a unique id
            #expect(statement1.name != statement2.name)
            
            // The statement belongs to the connection that created it
            #expect(statement1.connection === connection)
            
            
            
            // Statements are initially open
            #expect(!(await statement1.closed))
            #expect(!(await statement2.closed))
            // Statements can be independently closed
            try await statement1.close()
            #expect(await statement1.closed)
            #expect(!(await statement2.closed))
            
            // close() is idempotent
            try await statement1.close()
            #expect(await statement1.closed)
            #expect(!(await statement2.closed))
            
            // Closing a connection closes its statements
            await connection.close()
            #expect(await statement2.closed)
        }
    }
    
    @Test func testExecuteStatement() async throws {
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            
            do {
                let statement = try await connection.prepareStatement(text: "SELECT * FROM weather")
                _ = try await statement.query()
            }
            
            // Success case with with parameters
            do {
                try await connection.recoverIfNeeded()
                let text = "SELECT * FROM weather WHERE date = $1"
                let statement = try await connection.prepareStatement(text: text)
                _ = try await statement.bind(parameterValues: [ "1994-12-29" ]).query()
            }
            
            // Throws if parameters invalid
            do {
                try await connection.recoverIfNeeded()
                let text = "SELECT * FROM weather WHERE date = $1"
                let statement = try await connection.prepareStatement(text: text)
                
                await #expect(throws: PostgresError.self) {
                    try await statement.bind(parameterValues: [ "invalid-date" ]).query()
                }
            }
            
            // Throws if connection closed
            do {
                try await connection.recoverIfNeeded()
                let text = "SELECT * FROM weather"
                let statement = try await connection.prepareStatement(text: text)
                await connection.close()
                
                await #expect(throws: PostgresError.self) {
                    try await statement.execute()
                }
            }
        }
        
    }
    
    @Test func testExecuteClosedStatement() async throws {
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            
            let text = "SELECT * FROM weather"
            let statement = try await connection.prepareStatement(text: text)
            try await statement.close()
            
            let thrown = await #expect(throws: PostgresError.self) {
                try await statement.execute()
            }
            
            guard case .statementClosed = thrown else {
                Issue.record("Expected .statementClosed error, got: \(String(describing: thrown))")
                return
            }
        }
    }
    
}
