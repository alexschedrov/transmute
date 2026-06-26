//
//  AnalyticsService.swift
//  transmute
//

import Foundation
import Combine

final class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()

    @Published private(set) var records: [AnalyticsRecord] = []

    private let fileURL: URL

    private init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("transmute")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("analytics.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([AnalyticsRecord].self, from: data)
        else { return }
        records = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func record(action: TextAction, original: String, result: String) async {
        var analysis = CorrectionAnalysis(language: "", categories: [], explanation: "")
        if action.name == "Fix Grammar" && original != result {
            analysis = await LLMService.shared.analyzeCorrection(original: original, corrected: result)
        }
        let rec = AnalyticsRecord(
            id: UUID(),
            date: Date(),
            actionName: action.name,
            originalText: original,
            correctedText: result,
            language: analysis.language,
            errorCategories: analysis.categories,
            explanation: analysis.explanation
        )
        await MainActor.run {
            records.append(rec)
            save()
        }
    }
}
