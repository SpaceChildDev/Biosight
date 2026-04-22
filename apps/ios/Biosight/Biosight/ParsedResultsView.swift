import SwiftUI

struct ParsedResultsView: View {
    @Binding var values: [GeminiService.ParsedLabValue]
    let pdfData: Data?
    let onSave: () -> Void
    let onCancel: () -> Void

    var abnormalCount: Int {
        values.filter { $0.isAbnormal }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Özet başlık
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(values.count) Değer Bulundu")
                        .font(.headline)
                    if abnormalCount > 0 {
                        Text("\(abnormalCount) değer referans dışı")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
                Spacer()
                Button("Yeniden Seç", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            .padding()
            .background(.ultraThinMaterial)

            // Değer listesi
            List {
                ForEach(values) { parsed in
                    ParsedValueRow(value: parsed)
                }
                .onDelete { indexSet in
                    values.remove(atOffsets: indexSet)
                }
            }
            .listStyle(.insetGrouped)

            // Kaydet butonu
            Button {
                onSave()
            } label: {
                Label("Tümünü Kaydet (\(values.count) değer)", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
            .disabled(values.isEmpty)
        }
    }
}

struct ParsedValueRow: View {
    let value: GeminiService.ParsedLabValue

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(value.isAbnormal ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)
                Text(value.valueName)
                    .font(.headline)
                Spacer()
                Text(value.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack {
                Text("\(value.value) \(value.unit)")
                    .font(.subheadline.bold())
                    .foregroundColor(value.isAbnormal ? .orange : .primary)
                if !value.referenceRange.isEmpty {
                    Text("Ref: \(value.referenceRange)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(value.type)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let note = value.academicNote, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
