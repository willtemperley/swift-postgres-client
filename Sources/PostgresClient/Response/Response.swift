// Response 2.swift
// PostgresClientKit
//
// Created by Will Temperley on 13/07/2025. All rights reserved.
// Copyright 2025 Will Temperley.
// 
// Copying or reproduction of this file via any medium requires prior express
// written permission from the copyright holder.
// -----------------------------------------------------------------------------
///
/// Implementation notes, links and internal documentation go here.
///
// -----------------------------------------------------------------------------


protocol Response: Sendable {
    var responseType: Character { get }

    init(responseBody: ResponseBody) async throws
}
