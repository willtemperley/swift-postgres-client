# SwiftPostgresClient

<p>

  <img src="https://img.shields.io/badge/swift-6-green.svg">
  <img src="https://img.shields.io/badge/os-macOS-green.svg">
  <img src="https://img.shields.io/badge/os-iOS-green.svg">  
  
  <img src="https://img.shields.io/github/release/codewinsdotcom/PostgresClientKit.svg">
  <img src="https://img.shields.io/github/license/codewinsdotcom/PostgresClientKit.svg">
  
</p>

This project has been adapted from PostgresClientKit, with the following changes:

- Designed to be fully asynchronous, using Swift 5.5 structured concurrency.
- The network backend now uses Apple’s Network Framework, removing Kitura BlueSocket and BlueSSLService dependencies which are no longer supported. 
- Channel binding support has been enabled, significantly reducing chances of man-in-the-middle attacks. 
- Non-TLS connection support has been removed in favour of the  [second alternate method] (https://www.postgresql.org/docs/current/protocol-flow.html#PROTOCOL-FLOW-SSL) of connecting. This relies on Application-Layer Protocol Negotiation (ALPN) managed by Apple's Network framework, to directly negotiate a secure (TLS) connection without first sending a plain-text SSLRequest. This reduces connection latency and mitigates exposure to [CVE-2024-10977](https://www.postgresql.org/support/security/CVE-2024-10977/) and [CVE-2021-23222](https://www.postgresql.org/support/security/CVE-2021-23222/).
- All requests and responses are now sendable structs instead of classes.
- When using extended query mode, queries execute on named portals instead of the default portal.
- Tests have been migrated from XCTest to Swift Testing.

## Features

- **Doesn't require libpq.**  SwiftPostgresClient implements the Postgres network protocol in Swift, so it does not require `libpq`.

- **Fully concurrent, asynchronous API.**  Query results are exposed as `AsyncSequence`s. Connections are stateful and modeled as actors, allowing protocol-level messages to be received concurrently on one task while results are processed by client code on another.  This design ensures high performance and thread safety without explicit locking.

- **Safe conversion between Postgres and Swift types.** Type conversion is explicit and robust.  Conversion errors are signaled, not masked. These were adapted from PostgresClientKit, providing additional Swift types for dates and times to address the impedance mismatch between Postgres types and Foundation `Date`.

- **SSL/TLS support.** Encrypts the connection between SwiftPostgresClient and the Postgres server.

- **Channel binding support.** A security feature for SCRAM-SHA-256 authentication over TLS, channel binding links the TLS session to the authentication exchange, protecting against man-in-the-middle (MitM) attacks.

Sounds good?  Let's look at an example.

## Example

This is a basic, but complete, example of how to connect to Postgres, perform a SQL `SELECT` command, and process the resulting rows.  It uses the `weather` table in the [Postgres tutorial](https://www.postgresql.org/docs/11/tutorial-table.html).

```swift
import SwiftPostgresClient

// Connect on the default port, returning a connection actor
let connection = try await Connection.connect(host: "localhost")

// Connect using TLS and SCRAM, enforcing channel binding
let credential: Credential = .scramSHA256(password: "welcome1", channelBindingPolicy: .required)
try await connection.authenticate(user: "bob", database: "postgres", credential: credential)

// Prepare a statement
let text = "SELECT city, temp_lo, temp_hi, prcp, date FROM weather WHERE city = $1;"
let statement = try await connection.prepareStatement(query: text)

// Bind the statement within a named portal.
let portal = try await statement.bind(parameterValues: ["San Francisco"])

// Obtain an AsyncSequence from the portal and iterate the results.
let cursor = try await portal.execute()

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

Channel binding is only relevant when using SCRAM-SHA-256 SASL authentication.

The channel binding policy can be configured as either:

* `preferred` - If the server supports SCRAM-SHA-256-PLUS, the client will use channel binding. Otherwise, a warning is logged and the connection falls back to plain SCRAM-SHA-256.
* `required` - If the server does not support SCRAM-SHA-256-PLUS, an error is thrown and the connection fails.

⚠️ When using `.preferred` mode, if the connection proceeds with plain SCRAM-SHA-256 (without -PLUS), it's important to verify that the server genuinely does not support SCRAM-SHA-256-PLUS. Otherwise, a protocol downgrade attack may be possible, where an attacker strips the -PLUS mechanism to force weaker authentication.

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

[Set up a Postgres database for testing](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/Docs/setting_up_a_postgres_database_for_testing.md).  This is a one-time process.

Then:

```
cd <path-to-clone>
swift package clean
swift build
swift test
```

## Using

### From an Xcode project (as a package dependency)

In Xcode:

- Select File > Add Packages...

- Enter the package URL: `https://github.com/codewinsdotcom/PostgresClientKit`

- Set the package version requirements (see [Decide on Package Requirements](https://developer.apple.com/documentation/xcode/adding-package-dependencies-to-your-app)).  For example, choose `Up To Next Major Version` and `1.0.0` to select the latest 1.x.x release of PostgresClientKit.

- Click Add Package.

Import to your source code file:

```swift
import PostgresClientKit
```

### From a standalone Swift package (`Package.swift`)

In your `Package.swift` file:

- Add PostgresClientKit to the `dependencies`.  For example:

```swift
dependencies: [
    .package(url: "https://github.com/codewinsdotcom/PostgresClientKit", from: "1.0.0"),
],
```

- Reference the `PostgresClientKit` product in the `targets`.  For example:

```swift
targets: [
    .target(
        name: "MyProject",
        dependencies: ["PostgresClientKit"]),
]
```

Import to your source code file:

```swift
import PostgresClientKit
```

### Using CocoaPods

Add `PostgresClientKit` to your `Podfile`.  For example:

```
target 'MyApp' do
  pod 'PostgresClientKit', '~> 1.0'
end
```

Then run `pod install`.

Import to your source code file:

```swift
import PostgresClientKit
```

## Documentation

- [API](https://codewinsdotcom.github.io/PostgresClientKit/Docs/API/index.html)
- [Troubleshooting](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/Docs/troubleshooting.md)
- [FAQ](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/Docs/faq.md)

## Additional examples

- [PostgresClientKit-CommandLine-Example](https://github.com/pitfield/PostgresClientKit-CommandLine-Example): an example command-line application

- [PostgresClientKit-iOS-Example](https://github.com/pitfield/PostgresClientKit-iOS-Example): an example iOS app

## Contributing

Thank you for your interest in contributing to PostgresClientKit.

This project has a code of conduct.  See [CODE_OF_CONDUCT.md](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/CODE_OF_CONDUCT.md) for details.

Please use [issues](https://github.com/codewinsdotcom/PostgresClientKit/issues) to:

- ask questions
- report problems (bugs)
- request enhancements

Pull requests against the `develop` branch are welcomed.  For a non-trivial contribution (for example, more than correcting spelling, typos, or whitespace) please first discuss the proposed change by opening an issue.
    
## License

PostgresClientKit is licensed under the Apache 2.0 license.  See [LICENSE](https://github.com/codewinsdotcom/PostgresClientKit/blob/master/LICENSE) for details.

## Versioning

PostgresClientKit uses [Semantic Versioning 2.0.0](https://semver.org).  For the versions available, see the [tags on this repository](https://github.com/codewinsdotcom/PostgresClientKit/releases).

## Built with

- [Jazzy](https://github.com/realm/jazzy) - generation of API documentation pages

## Authors

- David Pitfield [(@pitfield)](https://github.com/pitfield)
