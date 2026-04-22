import SwiftUI
import Charts

enum TimeRange: String, CaseIterable {
    case daily = "Günlük"
    case weekly = "Haftalık"
    case thisMonth = "Bu Ay"
    case lastMonth = "Geçen Ay"
    case thisYear = "Bu Yıl"
    case lastYear = "Geçen Yıl"

    var startDate: Date {
        let cal = Calendar.current
        switch self {
        case .daily: return cal.startOfDay(for: .now)
        case .weekly: return cal.date(byAdding: .day, value: -7, to: .now)!
        case .thisMonth: return cal.date(from: cal.dateComponents([.year, .month], from: .now))!
        case .lastMonth:
            let lm = cal.date(byAdding: .month, value: -1, to: .now)!
            return cal.date(from: cal.dateComponents([.year, .month], from: lm))!
        case .thisYear: return cal.date(from: cal.dateComponents([.year], from: .now))!
        case .lastYear:
            let ly = cal.date(byAdding: .year, value: -1, to: .now)!
            return cal.date(from: cal.dateComponents([.year], from: ly))!
        }
    }

    var endDate: Date {
        let cal = Calendar.current
        switch self {
        case .lastMonth:
            let thisMonthStart = cal.date(from: cal.dateComponents([.year, .month], from: .now))!
            return cal.date(byAdding: .second, value: -1, to: thisMonthStart)!
        case .lastYear:
            let thisYearStart = cal.date(from: cal.dateComponents([.year], from: .now))!
            return cal.date(byAdding: .second, value: -1, to: thisYearStart)!
        default: return .now
        }
    }
}

// MARK: - Data Point

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let isAbnormal: Bool
}

// MARK: - Aggregation

private func aggregateByDay(_ results: [LabResult]) -> [ChartDataPoint] {
    let cal = Calendar.current
    let grouped = Dictionary(grouping: results) { cal.startOfDay(for: $0.date) }
    return grouped.map { day, dayResults in
        let values = dayResults.compactMap { $0.numericValue }
        let avg = values.reduce(0, +) / Double(values.count)
        return ChartDataPoint(date: day, value: (avg * 10).rounded() / 10, isAbnormal: dayResults.contains { $0.isAbnormal })
    }.sorted { $0.date < $1.date }
}

private func aggregateByWeek(_ results: [LabResult]) -> [ChartDataPoint] {
    let cal = Calendar.current
    let grouped = Dictionary(grouping: results) { result in
        cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: result.date))!
    }
    return grouped.map { week, weekResults in
        let values = weekResults.compactMap { $0.numericValue }
        let avg = values.reduce(0, +) / Double(values.count)
        return ChartDataPoint(date: week, value: (avg * 10).rounded() / 10, isAbnormal: weekResults.contains { $0.isAbnormal })
    }.sorted { $0.date < $1.date }
}

// MARK: - Bar Chart (Apple Health Style)

struct ChartContent: View {
    let data: [ChartDataPoint]
    let referenceLow: Double?
    let referenceHigh: Double?
    let maxLabels: Int

    var body: some View {
        Chart {
            // Referans aralığı bandı
            if let low = referenceLow, let high = referenceHigh {
                RectangleMark(yStart: .value("Alt", low), yEnd: .value("Üst", high))
                    .foregroundStyle(.green.opacity(0.08))
            }

            ForEach(data) { point in
                BarMark(
                    x: .value("Tarih", point.date, unit: barUnit),
                    y: .value("Değer", point.value)
                )
                .foregroundStyle(point.isAbnormal ? Color.orange.gradient : Color.accentColor.gradient)
                .cornerRadius(3)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(data.count, maxLabels))) { _ in
                AxisGridLine()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
        }
    }

    /// Veri aralığına göre bar genişliğini belirle
    private var barUnit: Calendar.Component {
        guard let first = data.first?.date, let last = data.last?.date else { return .day }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        if days > 365 { return .month }
        if days > 90 { return .weekOfYear }
        return .day
    }

    private var xAxisFormat: Date.FormatStyle {
        guard let first = data.first?.date, let last = data.last?.date else {
            return .dateTime.day().month(.abbreviated)
        }
        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        if days > 365 { return .dateTime.month(.abbreviated).year(.twoDigits) }
        if days > 60 { return .dateTime.day().month(.abbreviated) }
        return .dateTime.day().month(.abbreviated)
    }
}

// MARK: - Trend Chart (Mini)

struct TrendChartView: View {
    let results: [LabResult]
    let valueName: String
    let timeRange: TimeRange
    @State private var showFullScreen = false

    private var sortedResults: [LabResult] {
        results
            .filter { $0.valueName == valueName && $0.numericValue != nil && $0.date >= timeRange.startDate && $0.date <= timeRange.endDate }
            .sorted { $0.date < $1.date }
    }

    private var chartData: [ChartDataPoint] {
        let raw = sortedResults
        if raw.count > 60 {
            let byDay = aggregateByDay(raw)
            if byDay.count > 40 { return aggregateByWeek(raw) }
            return byDay
        }
        return raw.map { ChartDataPoint(date: $0.date, value: $0.numericValue ?? 0, isAbnormal: $0.isAbnormal) }
    }

    var body: some View {
        if !sortedResults.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(valueName)
                            .font(.headline)
                        if let last = sortedResults.last {
                            HStack(spacing: 4) {
                                Text("\(last.value) \(last.unit)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(last.isAbnormal ? .orange : .accentColor)
                                Text("son değer")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    Spacer()
                    Text("\(sortedResults.count) ölçüm")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Button {
                        showFullScreen = true
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(6)
                    }
                }

                if chartData.count >= 2 {
                    ChartContent(
                        data: chartData,
                        referenceLow: sortedResults.first?.referenceLow,
                        referenceHigh: sortedResults.first?.referenceHigh,
                        maxLabels: 5
                    )
                    .frame(height: 160)
                } else {
                    // Tek veri noktası
                    if let point = chartData.first {
                        HStack {
                            Spacer()
                            VStack(spacing: 4) {
                                Text(String(format: "%.1f", point.value))
                                    .font(.title.bold())
                                    .foregroundColor(point.isAbnormal ? .orange : .accentColor)
                                Text("Bu aralıkta tek ölçüm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .frame(height: 80)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .onTapGesture { showFullScreen = true }
            .fullScreenCover(isPresented: $showFullScreen) {
                FullScreenChartView(results: sortedResults, valueName: valueName)
            }
        }
    }
}

// MARK: - Full Screen Chart

struct FullScreenChartView: View {
    let results: [LabResult]
    let valueName: String
    @Environment(\.dismiss) private var dismiss

    private var chartData: [ChartDataPoint] {
        let raw = results
        if raw.count > 60 {
            let byDay = aggregateByDay(raw)
            if byDay.count > 40 { return aggregateByWeek(raw) }
            return byDay
        }
        return raw.map { ChartDataPoint(date: $0.date, value: $0.numericValue ?? 0, isAbnormal: $0.isAbnormal) }
    }

    private var statistics: (min: Double, max: Double, avg: Double, trend: String, count: Int) {
        let values = results.compactMap { $0.numericValue }
        guard !values.isEmpty else { return (0, 0, 0, "-", 0) }
        let mn = values.min() ?? 0
        let mx = values.max() ?? 0
        let avg = values.reduce(0, +) / Double(values.count)

        let trend: String
        if values.count >= 4 {
            let firstQ = Array(values.prefix(values.count / 3))
            let lastQ = Array(values.suffix(values.count / 3))
            let firstAvg = firstQ.reduce(0, +) / Double(firstQ.count)
            let lastAvg = lastQ.reduce(0, +) / Double(lastQ.count)
            if lastAvg > firstAvg * 1.05 { trend = "Artış Eğiliminde" }
            else if lastAvg < firstAvg * 0.95 { trend = "Azalış Eğiliminde" }
            else { trend = "Stabil" }
        } else {
            trend = values.count >= 2 ? "Stabil" : "Veri Yetersiz"
        }
        return (mn, mx, avg, trend, values.count)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Özet banner
                    HStack(spacing: 16) {
                        if let last = results.last {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Son Değer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(last.value) \(last.unit)")
                                    .font(.title2.bold())
                                    .foregroundColor(last.isAbnormal ? .orange : .accentColor)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(statistics.count) ölçüm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(statistics.trend)
                                .font(.subheadline.bold())
                                .foregroundColor(
                                    statistics.trend.contains("Artış") ? .orange :
                                    statistics.trend.contains("Azalış") ? .blue : .green
                                )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Ana grafik
                    if chartData.count >= 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            if chartData.count < results.count {
                                Text("Veriler okunabilirlik için gruplandı (\(chartData.count) nokta)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                            }

                            ChartContent(
                                data: chartData,
                                referenceLow: results.first?.referenceLow,
                                referenceHigh: results.first?.referenceHigh,
                                maxLabels: 6
                            )
                            .frame(height: 280)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    } else if let point = chartData.first {
                        VStack(spacing: 8) {
                            Text(String(format: "%.1f", point.value))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(point.isAbnormal ? .orange : .accentColor)
                            Text(results.first?.unit ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("Tek ölçüm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    // İstatistikler
                    if statistics.count >= 2 {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("İstatistiksel Özet")
                                .font(.title3.bold())

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                StatBox(title: "Ortalama", value: String(format: "%.1f", statistics.avg), unit: results.first?.unit ?? "", icon: "chart.bar.fill", color: .blue)
                                StatBox(title: "Trend", value: statistics.trend, unit: "", icon: "arrow.up.forward.circle.fill", color: .purple)
                                StatBox(title: "En Düşük", value: String(format: "%.1f", statistics.min), unit: results.first?.unit ?? "", icon: "arrow.down.circle.fill", color: .green)
                                StatBox(title: "En Yüksek", value: String(format: "%.1f", statistics.max), unit: results.first?.unit ?? "", icon: "arrow.up.circle.fill", color: .orange)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Değer hakkında
                    if let lastResult = results.last, let academicNote = lastResult.academicNote {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Değer Hakkında", systemImage: "info.circle.fill")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                            Text(academicNote)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.accentColor.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Bilgilendirme
                    Label("Bu bilgiler yalnızca bilgilendirme amaçlıdır. Tıbbi tanı veya tedavi yerine geçmez.", systemImage: "info.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle(valueName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Category Trend View

struct CategoryTrendView: View {
    let category: String
    let results: [LabResult]
    @State private var timeRange: TimeRange = .thisMonth

    private var valueNames: [String] {
        let filtered = results.filter { $0.category == category && $0.numericValue != nil && $0.date >= timeRange.startDate && $0.date <= timeRange.endDate }
        return Array(Set(filtered.map { $0.valueName })).sorted()
    }

    private var filteredResults: [LabResult] {
        results.filter { $0.category == category }
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Zaman Aralığı")
                    .font(.subheadline.bold())
                Spacer()
                Picker("", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .tint(.accentColor)
            }
            .padding(.horizontal)

            if valueNames.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.downtrend.xyaxis")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text("Bu aralıkta veri bulunamadı")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(valueNames, id: \.self) { name in
                    TrendChartView(results: filteredResults, valueName: name, timeRange: timeRange)
                }
            }
        }
        .padding(.vertical)
    }
}
