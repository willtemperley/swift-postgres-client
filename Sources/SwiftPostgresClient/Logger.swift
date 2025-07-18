// Logger.swift
// SwiftPostgresClient
//
// Created by Will Temperley on 18/07/2025. All rights reserved.
// Copyright 2025 Will Temperley.
// 
// Copying or reproduction of this file via any medium requires prior express
// written permission from the copyright holder.
// -----------------------------------------------------------------------------
///
/// Implementation notes, links and internal documentation go here.
///
// -----------------------------------------------------------------------------


#if DEBUG
#if canImport(os)
import os
private let logger = Logger(subsystem: "com.geolocalised.swiftpostgresclient", category: "debug")
#endif
#endif

public func logWarning(_ message: String) {
    #if DEBUG
    #if canImport(os)
    logger.warning("\(message, privacy: .public)")
    #else
    print("Warning: \(message)")
    #endif
    #endif
}

