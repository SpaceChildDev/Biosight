import SwiftUI
import SwiftData

struct CategoryResultListView: View {
    let category: String
    @Binding var selectedResult: LabResult?
    @Query(sort: \LabResult.date, order: .reverse) private var allLabResults: [LabResult]
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    private var allResults: [LabResult] {
        guard let person = activePerson else { return allLabResults }
        return allLabResults.filter { $0.person == nil || $0.person?.id == person.id }
    }

    private var filteredResults: [LabResult] {
        allResults.filter { $0.category == category }
    }

    var body: some View {
        List(selection: $selectedResult) {
            // Üstte Trend Grafikleri
            Section {
                CategoryTrendView(category: category, results: allResults)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)

            // Inbox tarzı sonuç listesi
            Section {
                if filteredResults.isEmpty {
                    ContentUnavailableView(
                        "Sonuç Bulunamadı",
                        systemImage: "tray",
                        description: Text("Bu kategoride henüz tahlil sonucu yok.")
                    )
                } else {
                    if category == "Tansiyon" {
                        bloodPressureList
                    } else {
                        ForEach(filteredResults) { result in
                            NavigationLink(value: result) {
                                LabResultRow(result: result)
                            }
                        }
                    }
                }
            } header: {
                Text("\(filteredResults.count) Sonuç")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(category)
    }

    private var bloodPressureList: some View {
        let grouped = Dictionary(grouping: filteredResults) { result in
            Calendar.current.startOfDay(for: result.date)
        }
        let sortedDays = grouped.keys.sorted(by: >)
        
        return ForEach(sortedDays, id: \.self) { day in
            let dayResults = grouped[day] ?? []
            // Aynı gün içindeki ölçümleri saat/dakika bazında daha hassas gruplayabiliriz
            // Şimdilik basitleştirmek için her ölçüm çiftini (Sistolik/Diastolik) bulmaya çalışalım
            let systolics = dayResults.filter { $0.valueName.contains("Sistolik") }.sorted { $0.date > $1.date }
            let diastolics = dayResults.filter { $0.valueName.contains("Diastolik") }.sorted { $0.date > $1.date }
            
            ForEach(0..<max(systolics.count, diastolics.count), id: \.self) { index in
                let systolic = index < systolics.count ? systolics[index] : nil
                let diastolic = index < diastolics.count ? diastolics[index] : nil
                
                BloodPressureRow(systolic: systolic, diastolic: diastolic)
            }
        }
    }
}

struct BloodPressureRow: View {
    let systolic: LabResult?
    let diastolic: LabResult?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text((systolic?.date ?? diastolic?.date ?? .now).formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                Spacer()
                Text("Tansiyon Ölçümü")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            HStack(spacing: 0) {
                // Alt (Diastolik)
                VStack(alignment: .center, spacing: 4) {
                    Text("DİASTOLİK (ALT)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        VStack {
                            Text(diastolic?.referenceRange.components(separatedBy: "-").first ?? "60")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Ref. Alt")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                        Text(diastolic?.value ?? "-")
                            .font(.title3.bold())
                            .foregroundColor(diastolic?.isAbnormal == true ? .orange : .primary)
                    }
                }
                .frame(maxWidth: .infinity)
                
                Divider().frame(height: 30)
                
                // Üst (Sistolik)
                VStack(alignment: .center, spacing: 4) {
                    Text("SİSTOLİK (ÜST)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        VStack {
                            Text(systolic?.referenceRange.components(separatedBy: "-").last ?? "120")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("Ref. Üst")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                        Text(systolic?.value ?? "-")
                            .font(.title3.bold())
                            .foregroundColor(systolic?.isAbnormal == true ? .orange : .primary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .cornerRadius(8)
        }
        .padding(.vertical, 4)
    }
}
