import SwiftUI

// MARK: - URL Durum Kontrolü

enum URLCheckStatus {
    case checking, valid, invalid
}

struct SourceLinkRow: View {
    let source: (name: String, url: String?)
    @Environment(\.openURL) private var openURL
    @State private var status: URLCheckStatus = .checking

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text.fill")
                .font(.caption)
                .foregroundColor(.accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.name)
                    .font(.footnote.bold())
                    .foregroundColor(status == .invalid ? .secondary : .primary)

                if let urlString = source.url, let url = URL(string: urlString) {
                    HStack(spacing: 4) {
                        switch status {
                        case .checking:
                            ProgressView().controlSize(.mini)
                        case .valid:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption2)
                        case .invalid:
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption2)
                        }
                        Button {
                            openURL(url)
                        } label: {
                            Text(urlString)
                                .font(.caption2)
                                .foregroundColor(status == .invalid ? .secondary : .accentColor)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .disabled(status == .invalid)
                    }
                    if status == .invalid {
                        Text("Bu bağlantı artık erişilebilir olmayabilir")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
        .task {
            await checkURL(source.url)
        }
    }

    private func checkURL(_ urlString: String?) async {
        guard let urlString, let url = URL(string: urlString) else {
            status = .invalid
            return
        }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 8
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                status = (200..<400).contains(httpResponse.statusCode) ? .valid : .invalid
            } else {
                status = .valid
            }
        } catch {
            status = .invalid
        }
    }
}

// MARK: - Panel

struct AcademicInfoPanel: View {
    let result: LabResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Panel açıldığında çözümlenen, cihaz diline uygun açıklama.
    @State private var resolvedNote: String?
    @State private var isLoadingNote = false

    private var cachedSources: [(name: String, url: String?)] {
        AcademicNoteCache.shared.sources(for: result.valueName)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Başlık
                    HStack {
                        Image(systemName: "book.closed.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text("Değer Hakkında")
                                .font(.title2.bold())
                            Text(result.valueName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    // Değer Özeti
                    HStack {
                        Label("\(result.value) \(result.unit)", systemImage: "number")
                        Spacer()
                        Label("Ref: \(result.referenceRange)", systemImage: "arrow.left.and.right")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)

                    Divider()

                    // Akademik Not — önce library/cache (her zaman doğru dil),
                    // sonra AI'dan taze çek, son çare eski kayıtlı not.
                    if isLoadingNote {
                        HStack(spacing: 10) {
                            ProgressView().controlSize(.small)
                            Text("Açıklama yükleniyor...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                    } else if let note = resolvedNote, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Analiz", systemImage: "text.book.closed")
                                .font(.headline)
                            Text(note)
                                .font(.body)
                                .lineSpacing(4)
                        }
                    } else {
                        ContentUnavailableView(
                            "Analiz Mevcut Değil",
                            systemImage: "text.book.closed",
                            description: Text("Bu değer için henüz akademik analiz oluşturulmamış.")
                        )
                    }

                    // Kaynaklar
                    let sources = sourcesToShow
                    if !sources.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Kaynaklar", systemImage: "link")
                                .font(.headline)

                            Text("Bilgiler aşağıdaki akademik kaynaklardan derlenmiştir:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(Array(sources.enumerated()), id: \.offset) { _, source in
                                SourceLinkRow(source: source)
                            }
                        }
                    }

                    // Whitelist bilgisi
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Kaynak Politikası", systemImage: "checkmark.shield.fill")
                            .font(.caption.bold())
                            .foregroundColor(.green)
                        Text("Biosight yalnızca akademik veritabanları (PubMed, PMC, Cochrane), uluslararası sağlık kuruluşları (WHO, NIH, CDC), üniversite hastaneleri (Mayo Clinic, Johns Hopkins) ve hakemli tıp dergilerinden bilgi kullanır. Tüm kaynaklar Ayarlar > Kaynaklar sayfasında listelenmiştir.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Değer Hakkında")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task { await resolveNote() }
        }
    }

    // MARK: - Dil Çözümleme

    /// Açıklamayı cihaz diline göre çözer:
    /// 1. Statik kütüphane (her zaman doğru dil)
    /// 2. Dil etiketli cache  (`valueName_tr` gibi)
    /// 3. AI'dan taze çek — hem cache'i hem DB kaydını günceller
    /// 4. Son çare: DB'deki eski not (yanlış dilde olabilir)
    private func resolveNote() async {
        // Adım 1 & 2: library + dil etiketli cache
        if let note = AcademicNoteCache.shared.note(for: result.valueName) {
            resolvedNote = note
            return
        }
        // Adım 3: AI'dan taze çek
        if AIServiceFactory.hasAvailableKey {
            isLoadingNote = true
            if let freshNote = try? await AIServiceFactory.create().fetchSingleAcademicNote(for: result.valueName),
               !freshNote.isEmpty {
                resolvedNote = freshNote
                result.academicNote = freshNote   // DB kaydını da güncelle
                isLoadingNote = false
                return
            }
            isLoadingNote = false
        }
        // Adım 4: eski kayıtlı not (yanlış dilde olsa bile göster)
        resolvedNote = result.academicNote
    }

    private var sourcesToShow: [(name: String, url: String?)] {
        // Öncelik: cache'teki yapılandırılmış kaynaklar
        if !cachedSources.isEmpty {
            return cachedSources
        }
        // Fallback: LabResult'taki academicSource
        if let source = result.academicSource, !source.isEmpty {
            return [(name: source, url: nil)]
        }
        return []
    }
}
