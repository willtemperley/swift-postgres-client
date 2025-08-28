//
//  TestEnvironment.swift
//  PostgresClientKit
//
//  Copyright 2020 David Pitfield and the PostgresClientKit contributors
//  Copyright 2025 Will Temperley and the SwiftPostgresClient contributors
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
import Foundation
import Testing

/// The configuration for unit testing.
///
/// Edit the properties' default values to reflect your environment.
struct TestEnvironment {
    
    init(postgresPort: Int = 5432, useTLS: Bool = true) {
        self.postgresPort = postgresPort
        self.useTLS = useTLS
    }
    
    /// The hostname or IP address of the Postgres server.
    let postgresHost = "127.0.0.1"
    
    /// The port number of the Postgres server.
    let postgresPort: Int
    
    /// The name of the database on the Postgres server.
    let postgresDatabase = "postgresclientkittest"
    
    /// The username of a Postgres user who can connect by `Credential.trust`.
    let terryUsername = "terry_postgresclientkittest"
    
    /// The password of the Postgres user identified by `terryUsername`.
    let terryPassword = "welcome1"
    
    /// The username of a Postgres user who can connect by `Credential.cleartextPassword`.
    let charlieUsername = "charlie_postgresclientkittest"

    /// The password of the Postgres user identified by `charlieUsername`.
    let charliePassword = "welcome1"
    
    /// The username of a Postgres user who can connect by `Credential.md5Password`.
    let maryUsername = "mary_postgresclientkittest"

    /// The password of the Postgres user identified by `maryUsername`.
    let maryPassword = "welcome1"
    
    /// The username of a Postgres user who can connect by `Credential.scramSHA256`.
    let sallyUsername = "sally_postgresclientkittest"

    /// The password of the Postgres user identified by `sallyUsername`.
    let sallyPassword = "welcome1"
    
    let useTLS: Bool
}

struct TestUtils {
    
    // Enable this to drop test schema if necessary
    func dropTestSchemata() async throws {
        
        let config = TestConfigurations().terryConnectionConfiguration
        let connection = try await Connection.connect(host: config.host)
        
        try await connection.authenticate(user: config.user, database: config.database, credential: config.credential)
        
        let cursor = try await connection.prepareStatement(text: """
                                              select schema_name from information_schema.schemata 
                                              where schema_name like 'test_%';
                                              """).bind().query()
        
        let values = try await cursor.reduce(into: []) { $0.append(try $1.columns[0].string()) }

        for value in values {
            try await connection.execute("drop schema \(value) cascade")
        }
    }
}

/// Creates and tears down an uniquely named schema, allowing tests to be run in parallel.
func withIsolatedSchema(
    config: ConnectionConfiguration,
    perform: @Sendable (_ conn: Connection) async throws -> Void
) async throws {
    var conn = try await Connection.connect(host: config.host, port: config.port, useTLS: config.useTLS)
    try await conn.authenticate(user: config.user, database: config.database, credential: config.credential)

    let schema = "test_\(UUID().uuidString.replacingOccurrences(of: "-", with: "_"))"

    do {
        try await conn.execute("CREATE SCHEMA \(schema)")
        try await conn.execute("SET search_path TO \(schema)")
        try await perform(conn)
    } catch {
        try? await conn.execute("DROP SCHEMA IF EXISTS \(schema) CASCADE")
        await conn.close()
        throw error
    }
    
    if await conn.closed {
        // Recreate connection to clean up.
        conn = try await Connection.connect(host: config.host, port: config.port, useTLS: config.useTLS)
        try await conn.authenticate(user: config.user, database: config.database, credential: config.credential)
    }

    try await conn.recoverIfNeeded()
    try await conn.execute("DROP SCHEMA IF EXISTS \(schema) CASCADE")
    await conn.close()
}

/// Creates (or re-creates) the `weather` table from the Postgres tutorial and populates it
/// with three rows. A unique temporary schema is created and dropped for each invocation to ensure
/// test isolation, necessary as Swift Testing runs tests in parallel.
///
/// - SeeAlso: https://www.postgresql.org/docs/current/tutorial-table.html
/// - SeeAlso: https://www.postgresql.org/docs/current/tutorial-populate.html
func withWeatherTable(
    config: ConnectionConfiguration,
    perform: @Sendable (_ conn: Connection) async throws -> Void
) async throws {
    try await withIsolatedSchema(config: config) { conn in
        try await conn.execute("""
            CREATE TABLE weather (
                city varchar(80),
                temp_lo int,
                temp_hi int,
                prcp real,
                date date
            )
        """)
        let statement = try await conn.prepareStatement(text:
            "INSERT INTO weather (city, temp_lo, temp_hi, prcp, date) VALUES ($1, $2, $3, $4, $5)")
        try await statement.bind(parameterValues: [ "San Francisco", 46, 50, 0.25, "1994-11-27" ]).execute()
        try await statement.bind(parameterValues: [ "San Francisco", 43, 57, 0.0, "1994-11-29" ]).execute()
        try await statement.bind(parameterValues: [ "Hayward", 37, 54, nil, "1994-11-29" ]).execute()
        try await statement.close()
        try await perform(conn)
    }
}

//
// MARK: Localization
//
/// Temporary workaround for https://bugs.swift.org/browse/SR-11569.
func isValidDate(_ dc: DateComponents) -> Bool {
    
    var calendar = dc.calendar ?? enUsPosixUtcCalendar
    
    if let timeZone = dc.timeZone {
        calendar.timeZone = timeZone
    }
    
    return dc.isValidDate(in: calendar)
}

/// The en_US_POSIX locale.
let enUsPosixLocale = Locale(identifier: "en_US_POSIX")

/// The UTC/GMT time zone.
let utcTimeZone = TimeZone(secondsFromGMT: 0)!

/// The PST/PDT time zone.
let pacificTimeZone = TimeZone.init(identifier: "America/Los_Angeles")!

var enUsPosixUtcCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = enUsPosixLocale
    calendar.timeZone = utcTimeZone
    return calendar
}()

//
// MARK: Test helpers
//

/// Asserts two values are either both `nil` or both non-`nil`.
func assertBothNilOrBothNotNil<T>(_ value1: T?, _ value2: T?,
                                     _ message: String = "XCTAssertBothNilOrBothNotNil",
                                     file: StaticString = #file, line: UInt = #line) {
    #expect(
        (value1 == nil && value2 == nil) ||
        (value1 != nil && value2 != nil),
        "\(message): \(String(describing: value1)) and \(String(describing: value2))",
        )
}

/// Two `Date` instances are "approximately equal" if their `timeSinceReferenceDate` values,
/// rounded to millisecond precision, are equal.
///
/// The PostgresClientKit tests use this definition for two reasons:
///
/// - `DateFormatter` retains only millisecond precision (truncating additional digits in
///   converting strings to dates, and rounding in converting from dates to string).
///
/// - Because `Date` is implemented on a `Double`, lossless conversion between `Date`
///   and `DateComponents` (whose `nanoseconds` property is an `Int`) is not possible for
///   some date values.
func assertApproximatelyEqual(_ date1: Date, _ date2: Date,
                                 _ message: String = "XCTAssertApproximatelyEqual",
                                 file: StaticString = #file, line: UInt = #line) {
    
    let milliseconds1 = (date1.timeIntervalSinceReferenceDate * 1000.0).rounded()
    let milliseconds2 = (date2.timeIntervalSinceReferenceDate * 1000.0).rounded()
    
    #expect(
        milliseconds1 == milliseconds2,
        "\(message): \(date1) and \(date2)",
        )
}

/// Two `DateComponent` instances are "approximately equal" if each of the following conditions
/// are met:
///
/// - their `calendar`, `timeZone`, and `era` properties are equal
///
/// - the properties for their other components are either both `nil` or both non-`nil`
///
/// - calling `Calendar.date(from:)` on them produces two `Date` instances that are themselves
///   "approximately equal"
func assertApproximatelyEqual(_ dc1: DateComponents,
                                 _ dc2: DateComponents,
                                 file: StaticString = #file, line: UInt = #line) {
    
    #expect( dc1.calendar == dc2.calendar, "DateComponents.calendar")
    
    #expect(
        dc1.timeZone == dc2.timeZone,
        "DateComponents.timeZone")
    
    #expect(
        dc1.era == dc2.era,
        "DateComponents.era")
    
    assertBothNilOrBothNotNil(
        dc1.year, dc2.year,
        "DateComponents.year",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.yearForWeekOfYear, dc2.yearForWeekOfYear,
        "DateComponents.yearForWeekOfYear",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.quarter, dc2.quarter,
        "DateComponents.quarter",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.month, dc2.month,
        "DateComponents.month",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.weekOfMonth, dc2.weekOfMonth,
        "DateComponents.weekOfMonth",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.weekOfYear, dc2.weekOfYear,
        "DateComponents.weekOfYear",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.weekday, dc2.weekday,
        "DateComponents.weekday",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.weekdayOrdinal, dc2.weekdayOrdinal,
        "DateComponents.weekdayOrdinal",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.day, dc2.day,
        "DateComponents.day",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.hour, dc2.hour,
        "DateComponents.hour",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.minute, dc2.minute,
        "DateComponents.minute",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.second, dc2.second,
        "DateComponents.second",
        file: file, line: line)
    
    assertBothNilOrBothNotNil(
        dc1.nanosecond, dc2.nanosecond,
        "DateComponents.nanosecond",
        file: file, line: line)
    
    let date1 = enUsPosixUtcCalendar.date(from: dc1)
    let date2 = enUsPosixUtcCalendar.date(from: dc2)
    
    if let date1 = date1, let date2 = date2 {
        assertApproximatelyEqual(date1, date2, "DateComponents", file: file, line: line)
    } else {
        assertBothNilOrBothNotNil(date1, date2, "DateComponents", file: file, line: line)
    }
}
