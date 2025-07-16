//
//  TestEnvironment.swift
//  PostgresClientKit
//
//  Copyright 2020 David Pitfield and the PostgresClientKit contributors
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

struct TestConfigurations {
    
    /// A `ConnectionConfiguration` for Terry, authenticating by `Credential.trust`.
    var terryConnectionConfiguration: ConnectionConfiguration {
        
        let environment = TestEnvironment.current
        
        var configuration = ConnectionConfiguration()
        configuration.host = environment.postgresHost
        configuration.port = environment.postgresPort
        configuration.database = environment.postgresDatabase
        configuration.user = environment.terryUsername
        configuration.credential = .trust
        
        return configuration
    }
    
    /// A `ConnectionConfiguration` for Charlie, authenticating by
    /// `Credential.cleartextPassword`.
    var charlieConnectionConfiguration:  ConnectionConfiguration {
        
        let environment = TestEnvironment.current
        
        var configuration = ConnectionConfiguration()
        configuration.host = environment.postgresHost
        configuration.port = environment.postgresPort
        configuration.database = environment.postgresDatabase
        configuration.user = environment.charlieUsername
        configuration.credential = .cleartextPassword(password: environment.charliePassword)
        
        return configuration
    }
    
    /// A `ConnectionConfiguration` for Mary, authenticating by `Credential.md5Password`.
    var maryConnectionConfiguration: ConnectionConfiguration {
        
        let environment = TestEnvironment.current
        
        var configuration = ConnectionConfiguration()
        configuration.host = environment.postgresHost
        configuration.port = environment.postgresPort
        configuration.database = environment.postgresDatabase
        configuration.user = environment.maryUsername
        configuration.credential = .md5Password(password: environment.maryPassword)
        
        return configuration
    }
    
    /// A `ConnectionConfiguration` for Sally, authenticating by `Credential.scramSHA256`.
    var sallyConnectionConfiguration: ConnectionConfiguration {
        
        let environment = TestEnvironment.current
        
        var configuration = ConnectionConfiguration()
        configuration.host = environment.postgresHost
        configuration.port = environment.postgresPort
        configuration.database = environment.postgresDatabase
        configuration.user = environment.sallyUsername
        configuration.credential = .scramSHA256(password: environment.sallyPassword, channelBindingPolicy: .preferred)
        
        return configuration
    }
}
