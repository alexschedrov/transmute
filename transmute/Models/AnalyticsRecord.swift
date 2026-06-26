//
//  AnalyticsRecord.swift
//  transmute
//

import Foundation

struct CorrectionAnalysis {
    let language: String
    let categories: [String]
    let explanation: String
}

struct AnalyticsRecord: Identifiable, Codable {
    var id: UUID
    var date: Date
    var actionName: String
    var originalText: String
    var correctedText: String
    var language: String
    var errorCategories: [String]
    var explanation: String
}
