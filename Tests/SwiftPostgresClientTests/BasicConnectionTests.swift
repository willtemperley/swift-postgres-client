import Testing
@testable import SwiftPostgresClient

public struct BasicConnectionTests {
    
    let configurations = ConnectionConfigurations()
    
    @Test
    func connectActor() async throws {
        
//        let config = neonConnection
//        let config = terryConnectionConfiguration
        let config = configurations.sallyConnectionConfiguration
        let connection = try await Connection.connect(configuration: config)

        try await connection.authenticate(user: config.user, database: config.database, credential: config.credential)
        
        print(connection)
        
        let queryCursor = QueryCursor(connection: connection)
        
        let text = "SELECT city, temp_lo, temp_hi, prcp, date FROM weather WHERE city = $1;"

        let statement = try await queryCursor.prepareStatement(query: text)
        try await queryCursor.executeStatement(statement: statement, parameterValues: [ "San Francisco" ])
        
        for try await row in queryCursor {
            print(row)
            row.columns.forEach { (column) in
                print("\(column.description)")
            }
        }
        
        print("rowCount: \(String(describing: queryCursor.rowCount))")
//        try await connection.closeStatement(statement2)

    }

}
