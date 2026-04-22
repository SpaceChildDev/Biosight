import SwiftUI
import SwiftData

struct DetailView: View {
    var result: LabResult
    @State private var showingInfoBox = false
    @State private var showingPDF = false
    
    var body: some View {
        HStack(spacing: 0) {
            List {
                Section("Tahlil Detayları") {
                    LabeledContent("Kategori", value: result.category)
                    LabeledContent("Değer", value: "\(result.value) \(result.unit)")
                    LabeledContent("Referans", value: result.referenceRange)
                    LabeledContent("Tarih", value: result.date.formatted(date: .numeric, time: .omitted))
                }
                
                Section("Eylemler") {
                    Button(action: { showingInfoBox.toggle() }) {
                        Label("Akademik Bilgi ve Analiz", systemImage: "info.circle")
                    }
                    
                    if let pdfPath = result.originalPDFPath, let url = URL(string: pdfPath) {
                        Button(action: { showingPDF.toggle() }) {
                            Label("Orijinal PDF Belgesini Gör", systemImage: "doc.text.fill")
                        }
                        #if os(iOS)
                        .fullScreenCover(isPresented: $showingPDF) {
                            PDFDisplayView(url: url)
                        }
                        #else
                        .sheet(isPresented: $showingPDF) {
                            PDFDisplayView(url: url)
                                .frame(minWidth: 600, minHeight: 800)
                        }
                        #endif
                    }
                }
            }
            .listStyle(.insetGrouped)
            
            if showingInfoBox {
                #if os(macOS)
                Divider()
                AcademicInfoPanel(result: result)
                    .frame(width: 350)
                    .transition(.move(edge: .trailing))
                #else
                .sheet(isPresented: $showingInfoBox) {
                    AcademicInfoPanel(result: result)
                }
                #endif
            }
        }
        .animation(.default, value: showingInfoBox)
        .navigationTitle(result.valueName)
    }
}

struct AcademicInfoPanel: View {
    var result: LabResult
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Değer Hakkında")
                    .font(.title2.bold())
                
                if let note = result.academicNote {
                    Text(note)
                        .font(.body)
                        .lineSpacing(6)
                } else {
                    Text("Bu değer için henüz akademik bilgi toplanmamış.")
                        .italic()
                        .foregroundColor(.secondary)
                }
                
                if let source = result.academicSource {
                    Divider()
                    Text("Kaynaklar")
                        .font(.headline)
                    Text(source)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
        }
        #if os(macOS)
        .background(Color(NSColor.windowBackgroundColor))
        #else
        .background(Color(UIColor.systemBackground))
        #endif
    }
}
