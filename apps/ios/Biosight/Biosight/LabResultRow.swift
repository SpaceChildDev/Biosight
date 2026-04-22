import SwiftUI

struct LabResultRow: View {
    let result: LabResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Tarih
                Text(result.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Tür Etiketi
                Text(result.type)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.valueName)
                        .font(.headline)
                    
                    if result.isAbnormal {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    Text("\(result.value) \(result.unit)")
                        .font(.subheadline.bold())
                        .foregroundColor(result.isAbnormal ? .orange : .primary)
                }
                
                HStack {
                    if let hospital = result.hospital {
                        Label(hospital, systemImage: "building.columns.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Label("Belirtilmemiş Kurum", systemImage: "building.columns")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if result.academicNote != nil {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundColor(.purple)
                    }
                    
                    if result.originalPDFPath != nil {
                        Image(systemName: "doc.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}
