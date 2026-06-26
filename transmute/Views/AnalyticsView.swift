//
//  AnalyticsView.swift
//  transmute
//

import SwiftUI
import Charts

// MARK: - Word Diff

private enum DiffToken {
    case unchanged(String)
    case removed(String)
    case added(String)
}

private func wordDiff(original: String, corrected: String) -> [DiffToken] {
    let old = original.split(separator: " ").map(String.init)
    let new = corrected.split(separator: " ").map(String.init)
    guard !old.isEmpty || !new.isEmpty else { return [] }

    let m = old.count, n = new.count
    var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
    for i in 1...m { for j in 1...n {
        dp[i][j] = old[i-1] == new[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
    }}

    var tokens: [DiffToken] = []
    var i = m, j = n
    while i > 0 || j > 0 {
        if i > 0, j > 0, old[i-1] == new[j-1] {
            tokens.append(.unchanged(old[i-1])); i -= 1; j -= 1
        } else if j > 0, (i == 0 || dp[i][j-1] >= dp[i-1][j]) {
            tokens.append(.added(new[j-1])); j -= 1
        } else {
            tokens.append(.removed(old[i-1])); i -= 1
        }
    }
    return tokens.reversed()
}

private func diffText(original: String, corrected: String) -> Text {
    let tokens = wordDiff(original: original, corrected: corrected)
    return tokens.reduce(Text("")) { acc, token in
        switch token {
        case .unchanged(let w):
            return acc + Text(w + " ")
        case .removed(let w):
            return acc + Text(w + " ").strikethrough(true, color: .red).foregroundColor(.red.opacity(0.75))
        case .added(let w):
            return acc + Text(w + " ").foregroundColor(Color(red: 0x2A/255.0, green: 0xC4/255.0, blue: 0x66/255.0))
        }
    }
}

// MARK: - Root View

private let brandGradient = LinearGradient(
    colors: [
        Color(red: 0xA9 / 255.0, green: 0x33 / 255.0, blue: 0xFF / 255.0),
        Color(red: 0xB9 / 255.0, green: 0x44 / 255.0, blue: 0xD1 / 255.0),
    ],
    startPoint: .top,
    endPoint: .bottom
)

struct AnalyticsView: View {
    @StateObject private var analytics = AnalyticsService.shared

    var body: some View {
        TabView {
            OverviewTab(records: analytics.records)
                .tabItem { Label("Overview", systemImage: "chart.bar") }
            HistoryTab(records: analytics.records)
                .tabItem { Label("History", systemImage: "clock") }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 440, idealHeight: 520)
        .padding(.top, 8)
    }
}

// MARK: - Overview Tab

private struct OverviewTab: View {
    let records: [AnalyticsRecord]

    private var grammarRecords: [AnalyticsRecord] {
        records.filter { $0.actionName == "Fix Grammar" && !$0.errorCategories.isEmpty }
    }

    private var categoryCounts: [(category: String, count: Int)] {
        var tally: [String: Int] = [:]
        for cat in grammarRecords.flatMap(\.errorCategories) {
            tally[cat, default: 0] += 1
        }
        return tally.map { (category: $0.key, count: $0.value) }
                    .sorted { $0.count > $1.count }
    }

    private var languageCounts: [(language: String, count: Int)] {
        var tally: [String: Int] = [:]
        for r in records where !r.language.isEmpty {
            tally[r.language, default: 0] += 1
        }
        return tally.map { (language: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {

                // Stats row
                HStack(spacing: 32) {
                    StatView(value: records.count, label: "Transformations")
                    StatView(value: grammarRecords.count, label: "Grammar fixes")
                    if let top = categoryCounts.first {
                        StatView(value: top.count, label: "Top error: \(top.category)")
                    }
                }

                if categoryCounts.isEmpty {
                    emptyState
                } else {
                    Divider()

                    // Error category chart
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Error Patterns")
                            .font(.headline)
                        Chart(categoryCounts, id: \.category) { item in
                            BarMark(
                                x: .value("Count", item.count),
                                y: .value("Category", item.category)
                            )
                            .foregroundStyle(brandGradient)
                            .annotation(position: .trailing) {
                                Text("\(item.count)×")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: CGFloat(max(categoryCounts.count, 3)) * 36 + 24)
                        .chartXAxis(.hidden)
                    }

                    // Language breakdown — only shown when more than one language detected
                    if languageCounts.count > 1 {
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Languages")
                                .font(.headline)
                            Chart(languageCounts, id: \.language) { item in
                                BarMark(
                                    x: .value("Count", item.count),
                                    y: .value("Language", item.language)
                                )
                                .foregroundStyle(brandGradient)
                                .annotation(position: .trailing) {
                                    Text("\(item.count)×")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(height: CGFloat(languageCounts.count) * 36 + 24)
                            .chartXAxis(.hidden)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(20)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No grammar data yet")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Use Fix Grammar to start tracking your recurring errors.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

private struct StatView: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.system(size: 32, weight: .semibold, design: .rounded))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - History Tab

private struct HistoryTab: View {
    let records: [AnalyticsRecord]

    var body: some View {
        if records.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "clock")
                    .font(.system(size: 36))
                    .foregroundStyle(.tertiary)
                Text("No transformations yet.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(records.reversed()) { record in
                        CorrectionCard(record: record)
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Correction Card

private struct CorrectionCard: View {
    let record: AnalyticsRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // Header
            HStack(spacing: 6) {
                Text(record.actionName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                if !record.language.isEmpty {
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(record.language)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(record.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Diff
            diffText(original: record.originalText, corrected: record.correctedText)
                .font(.system(size: 14))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            // Explanation
            if !record.explanation.isEmpty {
                Text(record.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            // Category pills
            if !record.errorCategories.isEmpty {
                HStack(spacing: 4) {
                    ForEach(record.errorCategories, id: \.self) { cat in
                        Text(cat)
                            .font(.caption2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(14)
        .background(.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.separator.opacity(0.6), lineWidth: 0.5)
        )
    }
}
