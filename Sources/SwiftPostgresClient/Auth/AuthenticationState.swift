//
//  AuthenticationState.swift
//  SwiftPostgresClient
//
//  Copyright 2025 Will Temperley and the SwiftPostgresClient contributors.
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

import Foundation

enum AuthenticationState {
    case start
    case awaitingCleartextPassword(String)
    case awaitingMd5Password(String, [UInt8])
    case awaitingSaslInitial([String])
    case awaitingSaslContinue(SCRAMSHA256Authenticator)
    case awaitingSaslFinal(SCRAMSHA256Authenticator)
    case awaitingOK
    case done
}

