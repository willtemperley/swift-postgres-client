//
//  SQLStatementTest.swift
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
import Foundation
//import XCTest

/// Tests various DML statements.
struct SQLStatementTest {
    
    @Test func testEmptyStatement() async throws {
        
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            
            // SELECT COUNT(*) to confirm they were deleted.
            do {
                let text = "SELECT COUNT(*) FROM weather WHERE city = 'San Jose'"
                let statement = try await connection.prepareStatement(text: text)
                let count = try await statement.bind().singleValue()?.int()
                #expect(count == 0)
            }
            
            // Postgres allows an empty statement.
            do {
                let text = ""
                let statement = try await connection.prepareStatement(text: text)
                let cursor = try await statement.bind().query()
                var iterator = cursor.makeAsyncIterator()
                let row = try await iterator.next()
                //
                #expect(row == nil)
            }
        }
    }
    
    @Test func testCRUD() async throws {
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            
            
            func time(_ name: String, operation: () async throws -> Void) async throws {
                let start = Date()
                try await operation()
                let elapsed = Date().timeIntervalSince(start) * 1000
                print("\(name): elapsed time \(elapsed) ms")
            }
            
            do {
                
                // Create 1000 days of random weather records for San Jose.
                var weatherHistory = [[PostgresValueConvertible]]()
                
                for i in 0..<1000 {
                    
                    let tempLo = Int.random(in: 20...70)
                    let tempHi = Int.random(in: tempLo...100)
                    
                    let prcp: Decimal? = {
                        let r = Double.random(in: 0..<1)
                        if r < 0.1 { return nil }
                        if r < 0.8 { return Decimal.zero }
                        return Decimal(Double(Int.random(in: 1...20)) / 10.0)
                    }()
                    
                    let date: PostgresDate = {
                        let pgd = PostgresDate(year: 2000, month: 1, day: 1)!
                        var d = pgd.date(in: utcTimeZone)
                        d = enUsPosixUtcCalendar.date(byAdding: .day, value: i, to: d)!
                        return d.postgresDate(in: utcTimeZone)
                    }()
                    
                    weatherHistory.append([ "San Jose", tempLo, tempHi, prcp, date ])
                }
                
                // INSERT the weather records.
                try await time("INSERT \(weatherHistory.count) rows") {
                    try await connection.beginTransaction()
                    
                    let text = "INSERT INTO weather VALUES ($1, $2, $3, $4, $5)"
                    let statement = try await connection.prepareStatement(text: text)
                    
                    for weather in weatherHistory {
                        let status = try await statement.bind(parameterValues: weather).execute()
                        #expect(status.rowCount == 1)
                    }
                    
                    try await connection.commitTransaction()
                }
                
                // SELECT the weather records.
                var selectedWeatherHistory = [[PostgresValueConvertible]]()
                
                try await time("SELECT \(weatherHistory.count) rows") {
                    let text = "SELECT * FROM weather WHERE city = $1 ORDER BY date"
                    let statement = try await connection.prepareStatement(text: text)
                    let cursor = try await statement.bind(parameterValues: [ "San Jose" ]).query()
                    
                    for try await row in cursor {
                        let columns = row.columns
                        let city = try columns[0].string()
                        let tempLo = try columns[1].int()
                        let tempHi = try columns[2].int()
                        let prcp = try columns[3].optionalDecimal()
                        let date = try columns[4].date()
                        selectedWeatherHistory.append([ city, tempLo, tempHi, prcp, date ])
                    }
                    
                    let rowCount = await cursor.rowCount
                    #expect(rowCount == selectedWeatherHistory.count)
                }
                
                // Check the SELECTed weather records.
                #expect(selectedWeatherHistory.count == weatherHistory.count)
                
                for (i, weather) in weatherHistory.enumerated() {
                    let selectedWeather = selectedWeatherHistory[i]
                    #expect(selectedWeather.count == weather.count)
                    for j in 0..<weather.count {
                        #expect(selectedWeather[j].postgresValue == weather[j].postgresValue)
                    }
                }
                
                // UPDATE the weather records (one by one).
                try await time("UPDATE \(weatherHistory.count) rows") {
                    try await connection.beginTransaction()
                    
                    let text = """
                    UPDATE weather
                        SET temp_lo = temp_lo - 1, temp_hi = temp_hi + 1
                        WHERE city = $1 AND date = $2
                    """
                    let statement = try await connection.prepareStatement(text: text)
                    
                    for weather in weatherHistory {
                        let status = try await statement.bind(parameterValues: [ weather[0], weather[4] ]).execute()
                        #expect(status.rowCount == 1)
                    }
                    
                    try await connection.commitTransaction()
                }
                
                // SELECT the updated weather records.
                selectedWeatherHistory = []
                
                try await time("SELECT \(weatherHistory.count) rows") {
                    let text = "SELECT * FROM weather WHERE city = $1 ORDER BY date"
                    let statement = try await connection.prepareStatement(text: text)
                    let cursor = try await statement.bind(parameterValues: [ "San Jose" ]).query()
                    
                    for try await row in cursor {
                        let columns = row.columns
                        let city = try columns[0].string()
                        let tempLo = try columns[1].int()
                        let tempHi = try columns[2].int()
                        let prcp = try columns[3].optionalDecimal()
                        let date = try columns[4].date()
                        selectedWeatherHistory.append([ city, tempLo, tempHi, prcp, date ])
                    }
                    
                    let rowCount = await cursor.rowCount
                    #expect(rowCount == selectedWeatherHistory.count)
                }
                
                // Check the SELECTed updated weather records.
                #expect(selectedWeatherHistory.count == weatherHistory.count)
                
                for (i, weather) in weatherHistory.enumerated() {
                    let selectedWeather = selectedWeatherHistory[i]
                    #expect(selectedWeather.count == weather.count)
                    #expect(selectedWeather[0].postgresValue == weather[0].postgresValue)
                    #expect(selectedWeather[1] as! Int == weather[1] as! Int - 1)
                    #expect(selectedWeather[2] as! Int == weather[2] as! Int + 1)
                    #expect(selectedWeather[3].postgresValue == weather[3].postgresValue)
                    #expect(selectedWeather[4].postgresValue == weather[4].postgresValue)
                }
                
                // DELETE the weather records (all at once).
                try await time("DELETE \(weatherHistory.count) rows") {
                    let text = "DELETE FROM weather WHERE city = $1"
                    let statement = try await connection.prepareStatement(text: text)
                    let cursor = try await statement.bind(parameterValues: [ "San Jose" ]).execute()
                    #expect(cursor.rowCount == weatherHistory.count)
                }
                
            } catch {
                Issue.record(error)
            }
        }
    }
    
    @Test func testSQLCursor() async throws {
        
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            
            do {
                
                var text = "DECLARE wc CURSOR WITH HOLD FOR SELECT * FROM weather"
                var statement = try await connection.prepareStatement(text: text)
                try await statement.bind().execute()
                
                text = "FETCH FORWARD 2 FROM wc"
                statement = try await connection.prepareStatement(text: text)
                var rowCount = 0
                
                while true {
                    let cursor = try await statement.bind().query()
                    var count = 0
                    
                    for try await row in cursor {
                        _ = row
                        count += 1
                    }
                    
                    let theRowCount = await cursor.rowCount
                    #expect(theRowCount == count)
                    
                    if count == 0 {
                        break
                    }
                    
                    rowCount += count
                }
                
                #expect(rowCount == 3)
            } catch {
                Issue.record(error)
            }
        }
        
    }
    
    @Test func testResultMetadata() async throws {
        try await withWeatherTable(config: TestConfigurations().terryConnectionConfiguration) { connection in
            
            do {
                
                func checkResultMetadata(columns: [ColumnMetadata]) {
                    
                    #expect(columns.count == 5)
                    let expectedNames = [ "city", "temp_lo", "temp_hi", "prcp", "date" ]
                    
                    for (index, column) in columns.enumerated() {
                        #expect(column.name == expectedNames[index])
                        #expect(column.tableOID == columns[0].tableOID)
                        #expect(column.columnAttributeNumber == index + 1)
                        #expect(column.dataTypeOID != 0)
                        #expect(column.dataTypeSize != 0)
                        #expect(column.dataTypeModifier != 0)
                    }
                }
                
                // No result metadata for statements that don't return results.
                do {
                    let text = "UPDATE weather SET temp_hi = temp_hi + 1 WHERE city = 'Hayward'"
                    let statement = try await connection.prepareStatement(text: text)
                    
                    let result = try await statement.bind().execute()
                    let rowCount = result.rowCount
                    #expect(rowCount == 1)
                    //                    XCTAssertNil(cursor.columns) // retrieveColumnMetadata defaults to false
                    
                    var status = try await statement.bind(columnMetadata: false).execute()
                    #expect(status.rowCount == 1)
                    //                    XCTAssertNil(cursor.columns) // retrieveColumnMetadata set to false
                    
                    status = try await statement.bind(columnMetadata: false).execute()
                    #expect(status.rowCount == 1)
                    //                    XCTAssertNil(cursor.columns) // UPDATE returns no results
                }
                
                // Result metadata for statements that do return results (but 0 rows).
                do {
                    let text = "SELECT * FROM weather WHERE city = 'Seattle'"
                    let statement = try await connection.prepareStatement(text: text)
                    
                    var cursor = try await statement.bind().query()
                    var rowCount = await cursor.rowCount
                    #expect(rowCount == 0)
                    //                    XCTAssertNil(cursor.columns)
                    
                    cursor = try await statement.bind(columnMetadata: false).query()
                    rowCount = await cursor.rowCount
                    #expect(rowCount == 0)
                    //                    XCTAssertNil(cursor.columns)
                    
                    cursor = try await statement.bind(columnMetadata: true).query()
                    rowCount = await cursor.rowCount
                    #expect(rowCount == 0)
                    //                    XCTAssertNotNil(cursor.columns)
                    //                    checkResultMetadata(columns: cursor.columns!)
                }
                
                // Result metadata available even before retrieving first row.
                do {
                    let text = "SELECT city, temp_lo, temp_hi, prcp, date FROM weather WHERE city = 'San Francisco'"
                    let statement = try await connection.prepareStatement(text: text)
                    
                    let cursor = try await statement.bind(columnMetadata: true).query()
                    await #expect(cursor.rowCount == nil)
                    
                    #expect(cursor.metatdata != nil)
                    checkResultMetadata(columns: cursor.metatdata!)
                    for try await _ in cursor { } // drain cursor
                    #expect(await cursor.rowCount == 2)
                    #expect(cursor.metatdata != nil) // result metadata still available
                    checkResultMetadata(columns: cursor.metatdata!)
                }
            } catch {
                Issue.record(error)
            }
        }
    }
}
