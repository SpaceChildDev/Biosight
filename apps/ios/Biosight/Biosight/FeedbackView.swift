import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subject = ""
    @State private var description = ""
    @State private var showSuccess = false
    @State private var isSending = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Konu", text: $subject)
                    TextEditor(text: $description)
                        .frame(minHeight: 150)
                        .overlay(
                            Group {
                                if description.isEmpty {
                                    Text("Lütfen hata bildirimini veya önerinizi buraya yazın...")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                } header: {
                    Text("Geri Bildirim")
                } footer: {
                    Text("Biosight'ı geliştirmemize yardımcı olduğunuz için teşekkürler.")
                }
                
                Section {
                    Button {
                        sendFeedback()
                    } label: {
                        if isSending {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Gönder")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(subject.isEmpty || description.isEmpty || isSending)
                }
            }
            .navigationTitle("Geri Bildirim")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .alert("Teşekkürler", isPresented: $showSuccess) {
                Button("Tamam") { dismiss() }
            } message: {
                Text("Geri bildiriminiz başarıyla iletildi.")
            }
        }
    }

    private func sendFeedback() {
        isSending = true
        // Simüle edilen gönderim
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isSending = false
            showSuccess = true
        }
    }
}
