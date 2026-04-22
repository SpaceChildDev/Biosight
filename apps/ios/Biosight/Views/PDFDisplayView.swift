import SwiftUI
import PDFKit

struct PDFDisplayView: View {
    let url: URL
    
    var body: some View {
        PDFKitRepresentedView(url: url)
            .edgesIgnoringSafeArea(.all)
            .navigationTitle("Orijinal Tahlil Belgesi")
    }
}

#if os(iOS)
struct PDFKitRepresentedView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
#elseif os(macOS)
struct PDFKitRepresentedView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {}
}
#endif
