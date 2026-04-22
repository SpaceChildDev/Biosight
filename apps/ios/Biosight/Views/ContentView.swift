import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabResult.date, order: .reverse) private var labResults: [LabResult]
    
    @State private var selectedCategory: String?
    @State private var selectedResult: LabResult?
    
    var categories: [String] {
        Array(Set(labResults.map { $0.category })).sorted()
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                NavigationLink(value: "Dashboard") {
                    Label("Özet Paneli", systemImage: "heart.text.square.fill")
                }
                
                Section("Kategoriler") {
                    ForEach(categories, id: \.self) { category in
                        NavigationLink(value: category) {
                            Label(category, systemImage: "chart.line.uptrend.xyaxis")
                        }
                    }
                }
                
                Section("Hızlı Erişim") {
                    Label("Favoriler", systemImage: "star.fill")
                    Label("Anomaliler", systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                }
            }
            .navigationTitle("VitalTrace")
        } content: {
            if let category = selectedCategory {
                if category == "Dashboard" {
                    DashboardView()
                } else {
                    CategoryResultListView(category: category, selectedResult: $selectedResult)
                }
            } else {
                Text("Lütfen bir kategori seçin")
                    .foregroundColor(.secondary)
            }
        } detail: {
            if let result = selectedResult {
                DetailView(result: result)
            } else {
                Text("Detayları görmek için bir sonuç seçin")
                    .foregroundColor(.secondary)
            }
        }
    }
}

// Mail kutusu gibi satır satır liste görünümü
struct CategoryResultListView: View {
    var category: String
    @Binding var selectedResult: LabResult?
    @Query private var results: [LabResult]
    
    init(category: String, selectedResult: Binding<LabResult?>) {
        self.category = category
        self._selectedResult = selectedResult
        _results = Query(filter: #Predicate<LabResult> { $0.category == category }, sort: \LabResult.date, order: .reverse)
    }
    
    var body: some View {
        VStack {
            TrendChartView(category: category)
                .frame(height: 200)
                .padding(.top)
            
            List(results, selection: $selectedResult) { result in
                LabResultRow(result: result)
                    .tag(result)
            }
        }
        .navigationTitle(category)
    }
}

struct LabResultRow: View {
    var result: LabResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.valueName)
                    .font(.headline)
                if result.isAbnormal {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }
                Spacer()
                Text("\(result.value) \(result.unit)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
            }
            
            HStack {
                Text(result.date, format: .dateTime.day().month().year())
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Ref: \(result.referenceRange)")
                    .font(.caption2)
                    .italic()
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Günlük Özet")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)
                
                // Buraya özet kartları gelecek
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 15) {
                    SummaryCard(title: "Kan Şekeri", value: "95 mg/dL", trend: "Stabil")
                    SummaryCard(title: "Kreatinin", value: "0.9 mg/dL", trend: "Düşüş")
                }
                .padding()
            }
        }
        .navigationTitle("Özet Paneli")
    }
}

struct SummaryCard: View {
    var title: String
    var value: String
    var trend: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
            Text(trend)
                .font(.caption2)
                .foregroundColor(.green)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: LabResult.self, inMemory: true)
}
