# SwiftPostgresClient

<p>

  <img src="https://img.shields.io/badge/swift-6-green.svg">
  <img src="https://img.shields.io/badge/os-macOS-green.svg">
  <img src="https://img.shields.io/badge/os-iOS-green.svg">  
  
</p>

This project has been adapted from PostgresClientKit, with the following changes:

- Designed to be fully asynchronous, using Swift 5.5 structured concurrency.
- The network backend now uses Apple’s Network Framework, removing Kitura BlueSocket and BlueSSLService dependencies which are no longer supported. 
- Channel binding support has been enabled, significantly reducing chances of man-in-the-middle attacks. 
- Non-TLS connection support has been removed in favour of the  [second alternate method](https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-SSL) of connecting. This relies on Application-Layer Protocol Negotiation (ALPN) managed by Apple's Network framework, to directly negotiate a secure (TLS) connection without first sending a plain-text SSLRequest. This reduces connection latency and mitigates exposure to [CVE-2024-10977](https://www.postgresql.org/support/security/CVE-2024-10977/) and [CVE-2021-23222](https://www.postgresql.org/support/security/CVE-2021-23222/).
- All requests and responses are now sendable structs instead of classes.
- When using extended query mode, queries execute on named portals instead of the default portal.
- Tests have been migrated from XCTest to Swift Testing.

## Features

- **Fully concurrent, asynchronous API.**  Queries can execute off the main thread, essential in modern frameworks like SwiftUI. Query results are exposed as `AsyncSequence`s and server notifications can be subscribed to via an `AsyncStream`. 

- **Doesn't require libpq.**  SwiftPostgresClient implements the Postgres network protocol in Swift, so it does not require `libpq`.

- **Safe conversion between Postgres and Swift types.** Type conversion is explicit and robust.  Conversion errors are signaled, not masked. These were adapted from PostgresClientKit, providing additional Swift types for dates and times to address the impedance mismatch between Postgres types and Foundation `Date`.

- **SSL/TLS support.** Encrypts the connection between SwiftPostgresClient and the Postgres server.

- **Channel binding support.** A security feature for SCRAM-SHA-256 authentication over TLS, channel binding links the TLS session to the authentication exchange, protecting against man-in-the-middle (MitM) attacks.

## Example

This is a basic, but complete, example of how to connect to a PostgresSQL server, perform a SQL `SELECT` command, and process the resulting rows.  It uses the `weather` table in the [Postgres tutorial](https://www.postgresql.org/docs/current/tutorial-table.html).

```swift
import SwiftPostgresClient

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
```

Output:

```
San Francisco on 1994-11-27: low: 46, high: 50, precipitation: Optional(0.25)
San Francisco on 1994-11-29: low: 43, high: 57, precipitation: Optional(0.0)
```

## Channel binding

This is only relevant when using SCRAM-SHA-256 SASL authentication.

The channel binding policy can be configured as either:

* `preferred` - If the server supports SCRAM-SHA-256-PLUS, the client will use channel binding. Otherwise, a warning is logged and the connection falls back to plain SCRAM-SHA-256.
* `required` - If the server does not support SCRAM-SHA-256-PLUS, an error is thrown and the connection fails.

⚠️ When using `.preferred` mode, if the connection proceeds with plain SCRAM-SHA-256 (without -PLUS), it's important to verify that the server genuinely does not support SCRAM-SHA-256-PLUS. Otherwise, a protocol downgrade attack may be possible, where an attacker strips the -PLUS mechanism to force weaker authentication.

## Proxy Environment Support

For database proxy environments like StrongDM, pgBouncer, or other connection poolers that handle TLS termination:

```swift
// Connect through a proxy without TLS
let connection = try await Connection.connect(
    host: "proxy.example.com", 
    port: 5432, 
    useTLS: false
)
```
<<<<<<< HEAD
=======
```
>>>>>>> bfd19d0eef3fe2d04acdbefb71b4147a52a06013

## Prerequisites

- **Swift 5.5 or later**  (PostgresClientKit uses Swift 5.5 structured concurrency)

This fork of PostgresClientKit is compatible with macOS and iOS.
It has only been tested on Postgres 17.

## Building

```
cd <path-to-clone>
swift package clean
swift build
```

## Testing

[Set up a Postgres database for testing](https://github.com/willtemperley/swift-postgres-client/blob/main/Docs/setting_up_a_postgres_database_for_testing.md).  This is a one-time process.

## Additional examples


## License

SwiftPostgresClient is licensed under the Apache 2.0 license.

## Authors

- Will Temperley [(@willtemperley)](https://github.com/willtemperley) current maintainer.
- David Pitfield [(@pitfield)](https://github.com/pitfield) author of the original project PostgresClientKit.
