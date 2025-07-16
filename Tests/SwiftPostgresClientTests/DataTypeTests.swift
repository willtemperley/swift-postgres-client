//
//  DataTypeTest.swift
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

/// Tests roundtripping PostgresValue -> Postgres server data types -> PostgresValue.
struct DataTypeTest {
    
    let configurations = TestConfigurations()
    
    @Test
    func test() async {
        
        let connectionConfig = configurations.terryConnectionConfiguration

        do {
            let connection = try await Connection.connect(host: connectionConfig.host, port: connectionConfig.port)
            try await connection.authenticate(user: connectionConfig.user, database: connectionConfig.database, credential: connectionConfig.credential)

            var text = "DROP TABLE IF EXISTS datatypetest"
            try await connection.executeSimpleQuery(text)

            text = """
                CREATE TABLE datatypetest (
                    sequence    integer,
                    cv          character varying(80),
                    c           character(10),
                    i           integer,
                    si          smallint,
                    bi          bigint,
                    dp          double precision,
                    r           real,
                    n           numeric,
                    b           boolean,
                    tstz        timestamp with time zone,
                    ts          timestamp,
                    d           date,
                    t           time,
                    ttz         time with time zone,
                    ba          bytea
                )
                """
            try await connection.executeSimpleQuery(text)

            var lastSequence = 0

            func check(_ column: String, _ value: PostgresValueConvertible) async {

                do {
                    lastSequence += 1

                    var text = "INSERT INTO datatypetest (sequence, \(column)) VALUES ($1, $2)"

                    try await connection
                        .prepareStatement(text: text)
                        .bind(parameterValues: [ lastSequence, value ])
                        .execute()

                    text = "SELECT \(column) FROM datatypetest WHERE sequence = $1"

                    let cursor = try await connection
                        .prepareStatement(text: text)
                        .bind(parameterValues: [ lastSequence ])
                        .query()
                    
                    let readValue = try await cursor.reduce(nil) { _, row in row.columns[0] }!

                    switch value {

                    case let value as String:
                        #expect(try readValue.string() == value, "\(column)")

                    case let value as Int:
                        #expect(try readValue.int() == value, "\(column)")

                    case let value as Double:
                        if value.isNaN {
                            #expect(try readValue.double().isNaN, "\(column)")
                        } else {
                            #expect(try readValue.double() == value, "\(column)")
                        }

                    case let value as Decimal:
                        #expect(try readValue.decimal() == value, "\(column)")

                    case let value as Bool:
                        #expect(try readValue.bool() == value, "\(column)")

                    case let value as PostgresTimestampWithTimeZone:
                        #expect(try readValue.timestampWithTimeZone() == value, "\(column)")

                    case let value as PostgresTimestamp:
                        #expect(try readValue.timestamp() == value, "\(column)")

                    case let value as PostgresDate:
                        #expect(try readValue.date() == value, "\(column)")

                    case let value as PostgresTime:
                        #expect(try readValue.time() == value, "\(column)")

                    case let value as PostgresTimeWithTimeZone:
                        #expect(try readValue.timeWithTimeZone() == value, "\(column)")

                    case let value as PostgresByteA:
                        #expect(try readValue.byteA() ==    value, "\(column)")

                    default: Issue.record("Unexpected type: \(type(of: value))")
                    }
                } catch {
                    Issue.record(error)
                }
            }

            // character varying
            await check("cv", "")
            await check("cv", "hello")
            await check("cv", "你好世界")
            await check("cv", "🐶🐮")

            // character
            await check("c", "          ")
            await check("c", "hello     ")
            await check("c", "你好世界      ")
            await check("c", "🐶🐮        ")

            // int
            await check("i", 0)
            await check("i", 314)
            await check("i", -314)

            // smallint
            await check("si", 0)
            await check("si", 314)
            await check("si", -314)

            // bigint
            await check("bi", 0)
            await check("bi", 314)
            await check("bi", -314)

            // double precision
            await check("dp", -314.0)
            await check("dp", -1003.14159)
            await check("dp", 6.02e+23)
            await check("dp", 1.6021765e-19)
            await check("dp", Double.infinity)
            await check("dp", Double.signalingNaN)

            // real
            await check("r", -314.0)
            await check("r", -1003.14)
            await check("r", 6.02e+23)
            await check("r", 1.60218e-19)
            await check("r", Double.infinity)
            await check("r", Double.signalingNaN)

            // numeric
            await check("n", Decimal(string: "1234.0"))
            await check("n", Decimal(string: "+0001234.4321000"))
            await check("n", Decimal(string: "-12345678987654321.98765432123456789"))
            await check("n", Decimal.nan)
            await check("n", Decimal.quietNaN)

            // boolean
            await check("b", true)
            await check("b", false)

            // timestamp with time zone
            await check("tstz", PostgresTimestampWithTimeZone("2019-01-02 03:04:05.006-08"))
            await check("tstz", PostgresTimestampWithTimeZone("2019-01-02 03:04:05.06-08"))
            await check("tstz", PostgresTimestampWithTimeZone("2019-01-02 03:04:05.6-08"))
            await check("tstz", PostgresTimestampWithTimeZone("2019-01-02 03:04:05-08"))
            await check("tstz", PostgresTimestampWithTimeZone("2019-01-02 03:04:05.365+130"))

            // timestamp
            await check("ts", PostgresTimestamp("2019-01-02 03:04:05.006"))
            await check("ts", PostgresTimestamp("2019-01-02 03:04:05.06"))
            await check("ts", PostgresTimestamp("2019-01-02 03:04:05.6"))
            await check("ts", PostgresTimestamp("2019-01-02 03:04:05"))

            // date
            await check("d", PostgresDate("2019-01-02"))

            // time
            await check("t", PostgresTime("03:04:05.006"))
            await check("t", PostgresTime("03:04:05.06"))
            await check("t", PostgresTime("03:04:05.6"))
            await check("t", PostgresTime("03:04:05"))

            // time with time zone
            await check("ttz", PostgresTimeWithTimeZone("03:04:05.006-08:00"))
            await check("ttz", PostgresTimeWithTimeZone("03:04:05.06-08:00"))
            await check("ttz", PostgresTimeWithTimeZone("03:04:05.6-08:00"))
            await check("ttz", PostgresTimeWithTimeZone("03:04:05-08:00"))
            await check("ttz", PostgresTimeWithTimeZone("03:04:05.365+1:30"))

            // bytea
            await check("ba", PostgresByteA("\\xDEADBEEF"))

            var bs = [UInt8]()

            for _ in 0..<1_000_000 {
                bs.append(UInt8.random(in: 0...255))
            }

            let data = Data(bs)

            await check("ba", PostgresByteA(data: data))

        } catch {
            Issue.record(error)
        }
    }
}
