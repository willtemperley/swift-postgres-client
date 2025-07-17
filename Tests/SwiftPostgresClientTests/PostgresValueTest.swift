//
//  PostgresValueTest.swift
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

import SwiftPostgresClient
import Testing
import Foundation

/// Tests PostgresValue.
struct PostgresValueTest {
    
    @Test
    func test() throws {
        
        let frFrLocale = Locale(identifier: "fr_FR")
        
        func check(
            postgresValueConvertible: PostgresValueConvertible,
            expectedRawValue: String,
            expectedString: String?,
            expectedInt: Int?,
            expectedDouble: Double?,
            expectedDecimal: Decimal?,
            expectedBool: Bool?,
            expectedTimestampWithTimeZone: PostgresTimestampWithTimeZone?,
            expectedTimestamp: PostgresTimestamp?,
            expectedDate: PostgresDate?,
            expectedTime: PostgresTime?,
            expectedTimeWithTimeZone: PostgresTimeWithTimeZone?,
            expectedByteA: PostgresByteA?,
            file: StaticString = #file,
            line: UInt = #line) {
                
                let postgresValue = postgresValueConvertible.postgresValue
                
                var message = "rawValue"
                #expect(postgresValue.rawValue == expectedRawValue, "\(message)")
                
                message = "string"
                if let expectedString = expectedString {
                    #expect(throws: Never.self, "\(message)") {
                        let string = try postgresValue.string()
                        let optionalString = try postgresValue.optionalString()
                        #expect(string == expectedString, "\(message)")
                        #expect(optionalString == .some(expectedString), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.string() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalString() }
                }
                
                message = "int"
                if let expectedInt = expectedInt {
                    #expect(throws: Never.self, "\(message)") {
                        let int = try postgresValue.int()
                        let optionalInt = try postgresValue.optionalInt()
                        #expect(int == expectedInt, "\(message)")
                        #expect(optionalInt == .some(expectedInt), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.int() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalInt() }
                }
                
                message = "double"
                if expectedDouble?.isNaN ?? false {
                    #expect(throws: Never.self, "\(message)") {
                        let double = try postgresValue.double()
                        let optionalDouble = try postgresValue.optionalDouble()
                        #expect(double.isNaN, "\(message)")
                        #expect(optionalDouble!.isNaN, "\(message)")
                    }
                } else if let expectedDouble = expectedDouble {
                    #expect(throws: Never.self, "\(message)") {
                        let double = try postgresValue.double()
                        let optionalDouble = try postgresValue.optionalDouble()
                        #expect(double == expectedDouble, "\(message)")
                        #expect(optionalDouble == .some(expectedDouble), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.double() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalDouble() }
                }
                
                message = "decimal"
                if let expectedDecimal = expectedDecimal {
                    #expect(throws: Never.self, "\(message)") {
                        let decimal = try postgresValue.decimal()
                        let optionalDecimal = try postgresValue.optionalDecimal()
                        #expect(decimal == expectedDecimal, "\(message)")
                        #expect(optionalDecimal == .some(expectedDecimal), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.decimal() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalDecimal() }
                }
                
                message = "bool"
                if let expectedBool = expectedBool {
                    #expect(throws: Never.self, "\(message)") {
                        let bool = try postgresValue.bool()
                        let optionalBool = try postgresValue.optionalBool()
                        #expect(bool == expectedBool, "\(message)")
                        #expect(optionalBool == .some(expectedBool), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.bool() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalBool() }
                }
                
                message = "timestampWithTimeZone"
                if let expectedTimestampWithTimeZone = expectedTimestampWithTimeZone {
                    #expect(throws: Never.self, "\(message)") {
                        let timestampWithTimeZone = try postgresValue.timestampWithTimeZone()
                        let optionalTimestampWithTimeZone = try postgresValue.optionalTimestampWithTimeZone()
                        #expect(timestampWithTimeZone == expectedTimestampWithTimeZone, "\(message)")
                        #expect(optionalTimestampWithTimeZone == .some(expectedTimestampWithTimeZone), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.timestampWithTimeZone() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalTimestampWithTimeZone() }
                }
                
                message = "timestamp"
                if let expectedTimestamp = expectedTimestamp {
                    #expect(throws: Never.self, "\(message)") {
                        let timestamp = try postgresValue.timestamp()
                        let optionalTimestamp = try postgresValue.optionalTimestamp()
                        #expect(timestamp == expectedTimestamp, "\( message)")
                        #expect(optionalTimestamp == .some(expectedTimestamp), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.timestamp() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalTimestamp() }
                }
                
                message = "date"
                if let expectedDate = expectedDate {
                    #expect(throws: Never.self, "\(message)") {
                        let date = try postgresValue.date()
                        let optionalDate = try postgresValue.optionalDate()
                        #expect(date == expectedDate, "\(message)")
                        #expect(optionalDate == .some(expectedDate), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.date() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalDate() }
                }
                
                message = "time"
                if let expectedTime = expectedTime {
                    #expect(throws: Never.self, "\(message)") {
                        let time = try postgresValue.time()
                        let optionalTime = try postgresValue.optionalTime()
                        #expect(time == expectedTime, "\(message)")
                        #expect(optionalTime == .some(expectedTime), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.time() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalTime() }
                }
                
                message = "timeWithTimeZone"
                if let expectedTimeWithTimeZone = expectedTimeWithTimeZone {
                    #expect(throws: Never.self, "\(message)") {
                        let timeWithTimeZone = try postgresValue.timeWithTimeZone()
                        let optionalTimeWithTimeZone = try postgresValue.optionalTimeWithTimeZone()
                        #expect(timeWithTimeZone == expectedTimeWithTimeZone, "\(message)")
                        #expect(optionalTimeWithTimeZone == .some(expectedTimeWithTimeZone), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.timeWithTimeZone() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalTimeWithTimeZone() }
                }
                
                message = "byteA"
                if let expectedByteA = expectedByteA {
                    #expect(throws: Never.self, "\(message)") {
                        let byteA = try postgresValue.byteA()
                        let optionalByteA = try postgresValue.optionalByteA()
                        #expect(byteA == expectedByteA, "\(message)")
                        #expect(optionalByteA == .some(expectedByteA), "\(message)")
                    }
                } else {
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.byteA() }
                    #expect(throws: (Error).self, "\(message)") { try postgresValue.optionalByteA() }
                }
            }
        
        func shouldFail<T>() -> T? {
            return nil
        }
        
        
        //
        // Test init(_:)
        //
        
        let value = PostgresValue("hello")
        #expect(value.rawValue == "hello")
        #expect(value.isNull == false)
        #expect(value.postgresValue == value)
        #expect(value == value)
        #expect(value.description == "hello")
        
        let value2 = PostgresValue(nil)
        #expect(value2.rawValue == nil)
        #expect(value2.isNull)
        #expect(value2.postgresValue == value2)
        #expect(value2 == value2)
        #expect(value2 != value)
        #expect(value2.description == "nil")
        
        
        //
        // Test conversion from String.
        //
        
        check(postgresValueConvertible: "hello",
              expectedRawValue: "hello",
              expectedString: "hello",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: shouldFail(),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "0",
              expectedRawValue: "0",
              expectedString: "0",
              expectedInt: 0,
              expectedDouble: 0.0,
              expectedDecimal: Decimal(0),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "314",
              expectedRawValue: "314",
              expectedString: "314",
              expectedInt: 314,
              expectedDouble: 314.0,
              expectedDecimal: Decimal(314),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "+03140",
              expectedRawValue: "+03140",
              expectedString: "+03140",
              expectedInt: 3140,
              expectedDouble: 3140.0,
              expectedDecimal: Decimal(3140),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "-314",
              expectedRawValue: "-314",
              expectedString: "-314",
              expectedInt: -314,
              expectedDouble: -314.0,
              expectedDecimal: Decimal(-314),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "-314.0",
              expectedRawValue: "-314.0",
              expectedString: "-314.0",
              expectedInt: shouldFail(),
              expectedDouble: -314.0,
              expectedDecimal: Decimal(-314.0),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "-1003.141590",
              expectedRawValue: "-1003.141590",
              expectedString: "-1003.141590",
              expectedInt: shouldFail(),
              expectedDouble: -1003.14159,
              expectedDecimal: Decimal(-1003.14159),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "6.02E23",
              expectedRawValue: "6.02E23",
              expectedString: "6.02E23",
              expectedInt: shouldFail(),
              expectedDouble: 6.02e+23,
              expectedDecimal: Decimal(6.02e+23),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "1.6021765000e-19",
              expectedRawValue: "1.6021765000e-19",
              expectedString: "1.6021765000e-19",
              expectedInt: shouldFail(),
              expectedDouble: 1.6021765e-19,
              expectedDecimal: Decimal(1.6021765e-19),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "inf",
              expectedRawValue: "inf",
              expectedString: "inf",
              expectedInt: shouldFail(),
              expectedDouble: Double.infinity,
              expectedDecimal: shouldFail(),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "infinity",
              expectedRawValue: "infinity",
              expectedString: "infinity",
              expectedInt: shouldFail(),
              expectedDouble: Double.infinity,
              expectedDecimal: shouldFail(),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "nan",
              expectedRawValue: "nan",
              expectedString: "nan",
              expectedInt: shouldFail(),
              expectedDouble: Double.nan,
              expectedDecimal: Decimal.nan,
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "NaN",
              expectedRawValue: "NaN",
              expectedString: "NaN",
              expectedInt: shouldFail(),
              expectedDouble: Double.nan,
              expectedDecimal: Decimal.nan,
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "-12345678987654321.98765432123456789",
              expectedRawValue: "-12345678987654321.98765432123456789",
              expectedString: "-12345678987654321.98765432123456789",
              expectedInt: shouldFail(),
              expectedDouble: -12345678987654321.98765432123456789, // literal will be rounded to nearest Double
              expectedDecimal: Decimal(string: "-12345678987654321.98765432123456789", locale: enUsPosixLocale),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "t",
              expectedRawValue: "t",
              expectedString: "t",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: shouldFail(),
              expectedBool: true,
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "f",
              expectedRawValue: "f",
              expectedString: "f",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: shouldFail(),
              expectedBool: false,
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "2019-01-02 03:04:05.365-08",
              expectedRawValue: "2019-01-02 03:04:05.365-08",
              expectedString: "2019-01-02 03:04:05.365-08",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: PostgresTimestampWithTimeZone("2019-01-02 11:04:05.365+00:00"),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "2019-01-02 03:04:05-08",
              expectedRawValue: "2019-01-02 03:04:05-08",
              expectedString: "2019-01-02 03:04:05-08",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: PostgresTimestampWithTimeZone("2019-01-02 11:04:05+00:00"),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "2019-01-02 03:04:05.365",
              expectedRawValue: "2019-01-02 03:04:05.365",
              expectedString: "2019-01-02 03:04:05.365",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: PostgresTimestamp("2019-01-02 03:04:05.365"),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "2019-01-02 03:04:05",
              expectedRawValue: "2019-01-02 03:04:05",
              expectedString: "2019-01-02 03:04:05",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: PostgresTimestamp("2019-01-02 03:04:05"),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "2019-01-02",
              expectedRawValue: "2019-01-02",
              expectedString: "2019-01-02",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: PostgresDate("2019-01-02"),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "03:04:05.365",
              expectedRawValue: "03:04:05.365",
              expectedString: "03:04:05.365",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(3), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: PostgresTime("03:04:05.365"),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "03:04:05",
              expectedRawValue: "03:04:05",
              expectedString: "03:04:05",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(3), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: PostgresTime("03:04:05"),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "03:04:05.365-08",
              expectedRawValue: "03:04:05.365-08",
              expectedString: "03:04:05.365-08",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(3), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: PostgresTimeWithTimeZone("03:04:05.365-08:00"),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "03:04:05-08",
              expectedRawValue: "03:04:05-08",
              expectedString: "03:04:05-08",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(3), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: PostgresTimeWithTimeZone("03:04:05-08:00"),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "\\xDEADBEEF",
              expectedRawValue: "\\xDEADBEEF",
              expectedString: "\\xDEADBEEF",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: shouldFail(),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: PostgresByteA("\\xdeadbeef"))
        
        
        //
        // Test conversion from Int.
        //
        
        check(postgresValueConvertible: 0,
              expectedRawValue: "0",
              expectedString: "0",
              expectedInt: 0,
              expectedDouble: 0.0,
              expectedDecimal: Decimal(0),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: 314,
              expectedRawValue: "314",
              expectedString: "314",
              expectedInt: 314,
              expectedDouble: 314.0,
              expectedDecimal: Decimal(314),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: -314,
              expectedRawValue: "-314",
              expectedString: "-314",
              expectedInt: -314,
              expectedDouble: -314.0,
              expectedDecimal: Decimal(-314),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from Double.
        //
        
        check(postgresValueConvertible: -314.0,
              expectedRawValue: "-314.0",
              expectedString: "-314.0",
              expectedInt: shouldFail(),
              expectedDouble: -314.0,
              expectedDecimal: Decimal(-314.0),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: -1003.14159,
              expectedRawValue: "-1003.14159",
              expectedString: "-1003.14159",
              expectedInt: shouldFail(),
              expectedDouble: -1003.14159,
              expectedDecimal: Decimal(-1003.14159),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: 6.02E23,
              expectedRawValue: "6.02e+23",
              expectedString: "6.02e+23",
              expectedInt: shouldFail(),
              expectedDouble: 6.02e+23,
              expectedDecimal: Decimal(6.02e+23),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: "1.6021765e-19",
              expectedRawValue: "1.6021765e-19",
              expectedString: "1.6021765e-19",
              expectedInt: shouldFail(),
              expectedDouble: 1.6021765e-19,
              expectedDecimal: Decimal(1.6021765e-19),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: Double.infinity,
              expectedRawValue: "inf",
              expectedString: "inf",
              expectedInt: shouldFail(),
              expectedDouble: Double.infinity,
              expectedDecimal: shouldFail(),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: Double.nan,
              expectedRawValue: "nan",
              expectedString: "nan",
              expectedInt: shouldFail(),
              expectedDouble: Double.nan,
              expectedDecimal: Decimal.nan,
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: Double.signalingNaN,
              expectedRawValue: "nan",
              expectedString: "nan",
              expectedInt: shouldFail(),
              expectedDouble: Double.nan,
              expectedDecimal: Decimal.nan,
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from Decimal.
        //
        
        check(postgresValueConvertible: Decimal(string: "1234.0", locale: enUsPosixLocale),
              expectedRawValue: "1234",
              expectedString: "1234",
              expectedInt: 1234,
              expectedDouble: 1234.0,
              expectedDecimal: Decimal(string: "1234", locale: enUsPosixLocale),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: Decimal(string: "+0001234.4321000", locale: enUsPosixLocale),
              expectedRawValue: "1234.4321",
              expectedString: "1234.4321",
              expectedInt: shouldFail(),
              expectedDouble: 1234.4321,
              expectedDecimal: Decimal(string: "1234.4321", locale: enUsPosixLocale),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: Decimal(string: "-12345678987654321.98765432123456789", locale: enUsPosixLocale),
              expectedRawValue: "-12345678987654321.98765432123456789",
              expectedString: "-12345678987654321.98765432123456789",
              expectedInt: shouldFail(),
              expectedDouble: -12345678987654321.98765432123456789, // literal will be rounded to nearest Double
              expectedDecimal: Decimal(string: "-12345678987654321.98765432123456789", locale: enUsPosixLocale),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
#if !os(Linux) // temporarily disabled on Linux due to https://bugs.swift.org/browse/SR-10525
        check(postgresValueConvertible: Decimal(string: "-12345678987654321,98765432123456789", locale: frFrLocale),
              expectedRawValue: "-12345678987654321.98765432123456789",
              expectedString: "-12345678987654321.98765432123456789",
              expectedInt: shouldFail(),
              expectedDouble: -12345678987654321.98765432123456789, // literal will be rounded to nearest Double
              expectedDecimal: Decimal(string: "-12345678987654321.98765432123456789", locale: enUsPosixLocale),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
#endif
        
        check(postgresValueConvertible: Decimal.nan,
              expectedRawValue: "NaN",
              expectedString: "NaN",
              expectedInt: shouldFail(),
              expectedDouble: Double.nan,
              expectedDecimal: Decimal.nan,
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: Decimal.quietNaN,
              expectedRawValue: "NaN",
              expectedString: "NaN",
              expectedInt: shouldFail(),
              expectedDouble: Double.nan,
              expectedDecimal: Decimal.nan,
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from Bool.
        //
        
        check(postgresValueConvertible: true,
              expectedRawValue: "t",
              expectedString: "t",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: shouldFail(),
              expectedBool: true,
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: false,
              expectedRawValue: "f",
              expectedString: "f",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: shouldFail(),
              expectedBool: false,
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from PostgresTimestampWithTimeZone.
        //
        
        check(postgresValueConvertible: PostgresTimestampWithTimeZone("2019-01-02 03:04:05.365-08"),
              expectedRawValue: "2019-01-02 11:04:05.365+00:00",
              expectedString: "2019-01-02 11:04:05.365+00:00",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: PostgresTimestampWithTimeZone("2019-01-02 11:04:05.365+00:00"),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: PostgresTimestampWithTimeZone("2019-01-02 03:04:05-08"),
              expectedRawValue: "2019-01-02 11:04:05.000+00:00",
              expectedString: "2019-01-02 11:04:05.000+00:00",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: PostgresTimestampWithTimeZone("2019-01-02 11:04:05.000+00:00"),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from PostgresTimestamp.
        //
        
        check(postgresValueConvertible: PostgresTimestamp("2019-01-02 03:04:05.365"),
              expectedRawValue: "2019-01-02 03:04:05.365",
              expectedString: "2019-01-02 03:04:05.365",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: PostgresTimestamp("2019-01-02 03:04:05.365"),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: PostgresTimestamp("2019-01-02 03:04:05"),
              expectedRawValue: "2019-01-02 03:04:05.000",
              expectedString: "2019-01-02 03:04:05.000",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: PostgresTimestamp("2019-01-02 03:04:05.000"),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from PostgresDate.
        //
        
        check(postgresValueConvertible: PostgresDate("2019-01-02"),
              expectedRawValue: "2019-01-02",
              expectedString: "2019-01-02",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(2019), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: PostgresDate("2019-01-02"),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from PostgresTime.
        //
        
        check(postgresValueConvertible: PostgresTime("03:04:05.365"),
              expectedRawValue: "03:04:05.365",
              expectedString: "03:04:05.365",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(3), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: PostgresTime("03:04:05.365"),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: PostgresTime("03:04:05"),
              expectedRawValue: "03:04:05.000",
              expectedString: "03:04:05.000",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(3), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: PostgresTime("03:04:05.000"),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from PostgresTimeWithTimeZone.
        //
        
        check(postgresValueConvertible: PostgresTimeWithTimeZone("03:04:05.365-08"),
              expectedRawValue: "03:04:05.365-08:00",
              expectedString: "03:04:05.365-08:00",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(3), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: PostgresTimeWithTimeZone("03:04:05.365-08:00"),
              expectedByteA: shouldFail())
        
        check(postgresValueConvertible: PostgresTimeWithTimeZone("03:04:05-08"),
              expectedRawValue: "03:04:05.000-08:00",
              expectedString: "03:04:05.000-08:00",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: Decimal(3), // Decimal(string:locale:) behavior is dubious
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: PostgresTimeWithTimeZone("03:04:05.000-08:00"),
              expectedByteA: shouldFail())
        
        
        //
        // Test conversion from PostgresByteA.
        //
        
        check(postgresValueConvertible: PostgresByteA("\\xDEADBEEF"),
              expectedRawValue: "\\xdeadbeef",
              expectedString: "\\xdeadbeef",
              expectedInt: shouldFail(),
              expectedDouble: shouldFail(),
              expectedDecimal: shouldFail(),
              expectedBool: shouldFail(),
              expectedTimestampWithTimeZone: shouldFail(),
              expectedTimestamp: shouldFail(),
              expectedDate: shouldFail(),
              expectedTime: shouldFail(),
              expectedTimeWithTimeZone: shouldFail(),
              expectedByteA: PostgresByteA("\\xdeadbeef"))
        
        
        //
        // Test nil values.
        //
        
        var optionalString: String? = nil
        #expect(optionalString.postgresValue.rawValue == nil)
        #expect(optionalString.postgresValue == PostgresValue(nil))
        
        optionalString = "hello"
        #expect(optionalString.postgresValue.rawValue == "hello")
        #expect(optionalString.postgresValue == PostgresValue("hello"))
        
        let postgresValue = PostgresValue(nil)
        
        #expect(throws: (Error).self) {try postgresValue.string() }
        #expect(try postgresValue.optionalString() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.int() }
        #expect(try postgresValue.optionalInt() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.double() }
        #expect(try postgresValue.optionalDouble() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.decimal() }
        #expect(try postgresValue.optionalDecimal() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.bool() }
        #expect(try postgresValue.optionalBool() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.timestampWithTimeZone() }
        #expect(try postgresValue.optionalTimestampWithTimeZone() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.timestamp() }
        #expect(try postgresValue.optionalTimestamp() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.date() }
        #expect(try postgresValue.optionalDate() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.time() }
        #expect(try postgresValue.optionalTime() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.timeWithTimeZone() }
        #expect(try postgresValue.optionalTimeWithTimeZone() == nil)
        
        #expect(throws: (Error).self) {try postgresValue.byteA() }
        #expect(try postgresValue.optionalByteA() == nil)
    }
}
