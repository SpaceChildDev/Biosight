import SwiftUI
import Charts
import SwiftData

struct TrendChartView: View {
    var category: String
    @Query private var results: [LabResult]
    
    init(category: String) {
        self.category = category
        _results = Query(filter: #Predicate<LabResult> { $0.category == category }, sort: \LabResult.date)
    }
    
    var body: some View {
        VStack {
            Text("\(category) Zaman Serisi Analizi")
                .font(.headline)
            
            Chart {
                ForEach(results) { result in
                    LineMark(
                        x: .value("Tarih", result.date),
                        y: .value("Değer", Double(result.value) ?? 0)
                    )
                    .foregroundStyle(by: .value("Ölçüm", result.valueName))
                    
                    PointMark(
                        x: .value("Tarih", result.date),
                        y: .value("Değer", Double(result.value) ?? 0)
                    )
                    .foregroundStyle(by: .value("Ölçüm", result.valueName))
                }
            }
            .frame(height: 300)
            .padding()
            .chartLegend(position: .bottom)
        }
    }
}
