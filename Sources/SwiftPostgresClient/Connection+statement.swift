//
//  Connection+query.swift
//  SwiftPostgresClient
//
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

/// A connection to a PostgresSQL server for a specific user and database.
///  Execution is actor-isolated
extension Connection {
    
    func setCommandStatus(to status: CommandStatus) async throws {
        self.commandStatus = status
    }
    
    /// Submits a  statement for parsing to the PostgreSQL server.
    /// - Parameter text: The statement text.
    /// - Returns: a `PreparedStatement` ready for parameter binding.
    public func prepareStatement(text: String) async throws -> PreparedStatement {
        
        if self.state != .ready {
            throw PostgresError.invalidState("Expected connection to be in state .ready, but was \(self.state)")
        }
        
        let statement = Statement(text: text)
        let parseRequest = ParseRequest(statement: statement)
        try await sendRequest(parseRequest)
        
        let flushRequest = FlushRequest()
        try await sendRequest(flushRequest)
        
        try await receiveResponse(type: ParseCompleteResponse.self)
        
        self.openStatements.insert(statement.name)
        return PreparedStatement(name: statement.name, statement: statement, connection: self)
    }
    
    /// Close a prepared statement
    func closeStatement(name: String) async throws {
        
        let closeStatementRequest = CloseStatementRequest(name: name)
        try await sendRequest(closeStatementRequest)
        
        let flushRequest = FlushRequest()
        try await sendRequest(flushRequest)
        
        try await receiveResponse(type: CloseCompleteResponse.self)
        self.openStatements.remove(name)
    }
    
    /// Returns metadata used for decoding structs via column names
    func retrieveColumnMetadata(portalName: String) async throws -> [ColumnMetadata]? {
        
        var columns: [ColumnMetadata]? = nil
        
        let describePortalRequest = DescribePortalRequest(name: portalName)
        try await sendRequest(describePortalRequest)
        
        let flushRequest = FlushRequest()
        try  await sendRequest(flushRequest)
        
        let response = await receiveResponse()
        
        switch response {
            
        case is NoDataResponse:
            columns = nil
            
        case let rowDescriptionResponse as RowDescriptionResponse:
            columns = rowDescriptionResponse.columns
            
        default:
            throw PostgresError.serverError(
                description: "unexpected response type '\(response.responseType)'")
        }
        
        return columns
    }
}
