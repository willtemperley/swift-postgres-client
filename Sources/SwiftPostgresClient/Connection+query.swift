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
        
        let statement = Statement(text: text)
        let parseRequest = ParseRequest(statement: statement)
        try await sendRequest(parseRequest)
        
        let flushRequest = FlushRequest()
        try await sendRequest(flushRequest)
        
        try await receiveResponse(type: ParseCompleteResponse.self)
        
        return PreparedStatement(name: statement.name, statement: statement, connection: self)
    }
    
    func query(
        portalName: String,
        statement: Statement,
        metadata: [ColumnMetadata]?
    ) async throws -> ResultCursor {
        
        state = .querySent
        
        let executeRequest = ExecuteRequest(portalName: portalName, statement: statement)
        try await sendRequest(executeRequest)
        
        let flushRequest = FlushRequest()
        try await sendRequest(flushRequest)
        
        // The first response of the query is evaluated eagerly to check its
        // type.
        // An zero-result query could immediately give a CommandCompleteResponse
        // This also prevents some issues with undrained message queues.
        // TODO: check error response
        let response = await receiveResponse()

        return ResultCursor(connection: self, portalName: portalName, metadata: metadata, initialResponse: response)
    }
    
    public func closeStatement(name: String) async throws {
        
        let closeStatementRequest = CloseStatementRequest(name: name)
        try await sendRequest(closeStatementRequest)
        
        let flushRequest = FlushRequest()
        try await sendRequest(flushRequest)
        
        try await receiveResponse(type: CloseCompleteResponse.self)
    }
    
    // used for decoding structs using column names
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
