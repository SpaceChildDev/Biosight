import SwiftUI

struct SourcesView: View {
    @Environment(\.openURL) private var openURL

    private var cachedData: [(valueName: String, sources: [(name: String, url: String?)])] {
        AcademicNoteCache.shared.allSourcedValues
    }

    // MARK: - Kaynak Whitelist

    private struct SourceCategory {
        let title: String
        let icon: String
        let sources: [(name: String, url: String?)]
    }

    private let sourceCategories: [SourceCategory] = [
        SourceCategory(
            title: "Birincil Veritabanları",
            icon: "server.rack",
            sources: [
                ("PubMed / NCBI", "https://pubmed.ncbi.nlm.nih.gov"),
                ("PMC (PubMed Central)", "https://pmc.ncbi.nlm.nih.gov"),
                ("NCBI Bookshelf", "https://www.ncbi.nlm.nih.gov/books"),
                ("Cochrane Library", "https://www.cochranelibrary.com"),
                ("MEDLINE / Ovid", "https://ovidsp.ovid.com"),
            ]
        ),
        SourceCategory(
            title: "Uluslararası Sağlık Kuruluşları",
            icon: "building.columns.fill",
            sources: [
                ("WHO Guidelines", "https://www.who.int/publications/who-guidelines"),
                ("WHO — Good Clinical Laboratory Practice (GCLP)", "https://wkc.who.int"),
                ("NIH", "https://www.nih.gov"),
                ("CDC", "https://www.cdc.gov"),
                ("CLSI (Clinical & Laboratory Standards Institute)", "https://clsi.org"),
            ]
        ),
        SourceCategory(
            title: "Referans Laboratuvarları & Üniversite Hastaneleri",
            icon: "cross.case.fill",
            sources: [
                ("Mayo Clinic Laboratories — Test Catalog", "https://www.mayocliniclabs.com/test-catalog"),
                ("Johns Hopkins Medicine", "https://www.hopkinsmedicine.org"),
                ("Harvard Medical School", "https://hms.harvard.edu"),
                ("ACCP Lab Values Reference", "https://www.accp.com/docs/sap/Lab_Values_Table_PSAP.pdf"),
            ]
        ),
        SourceCategory(
            title: "Alan Bazlı Klinik Rehberler",
            icon: "text.book.closed.fill",
            sources: [
                ("KDIGO (Böbrek)", "https://kdigo.org"),
                ("ADA Standards of Care (Diyabet)", "https://diabetesjournals.org/care"),
                ("ACC/AHA Guidelines (Kardiyovasküler)", "https://www.acc.org/guidelines"),
                ("ESC Guidelines (Kardiyovasküler, Avrupa)", "https://www.escardio.org/Guidelines"),
            ]
        ),
        SourceCategory(
            title: "Genel Laboratuvar / Klinik Kimya Dergileri",
            icon: "magazine.fill",
            sources: [
                ("Clinical Chemistry (AACC)", "https://academic.oup.com/clinchem"),
                ("Annals of Clinical Biochemistry", "https://journals.sagepub.com/home/acb"),
                ("Journal of Clinical Pathology", "https://jcp.bmj.com"),
            ]
        ),
        SourceCategory(
            title: "Kardiyovasküler Dergiler",
            icon: "heart.fill",
            sources: [
                ("JACC", "https://www.jacc.org"),
                ("European Heart Journal", "https://academic.oup.com/eurheartj"),
                ("Circulation (AHA)", "https://www.ahajournals.org/journal/circ"),
            ]
        ),
        SourceCategory(
            title: "Metabolizma / Diyabet Dergileri",
            icon: "drop.fill",
            sources: [
                ("Diabetes Care (ADA)", "https://diabetesjournals.org/care"),
                ("Diabetologia", "https://www.springer.com/journal/125"),
            ]
        ),
        SourceCategory(
            title: "Böbrek Dergileri",
            icon: "kidney.fill",
            sources: [
                ("Kidney International", "https://www.kidney-international.org"),
                ("JASN", "https://jasn.asnjournals.org"),
            ]
        ),
        SourceCategory(
            title: "Hematoloji Dergileri",
            icon: "drop.triangle.fill",
            sources: [
                ("Blood (ASH)", "https://ashpublications.org/blood"),
                ("British Journal of Haematology", "https://onlinelibrary.wiley.com/journal/13652141"),
            ]
        ),
        SourceCategory(
            title: "Tiroid Dergileri",
            icon: "waveform.path.ecg",
            sources: [
                ("Thyroid (ATA)", "https://www.liebertpub.com/journal/thy"),
                ("European Thyroid Journal", "https://eurthyroidj.org"),
            ]
        ),
        SourceCategory(
            title: "Karaciğer / Lipid Dergileri",
            icon: "chart.bar.fill",
            sources: [
                ("Journal of Hepatology", "https://www.journal-of-hepatology.eu"),
                ("Atherosclerosis", "https://www.atherosclerosis-journal.com"),
            ]
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Kaynak Politikası
                VStack(alignment: .leading, spacing: 10) {
                    Label("Kaynak Politikası", systemImage: "checkmark.shield.fill")
                        .font(.title3.bold())
                        .foregroundColor(.green)

                    Text("Biosight, sağlık bilgilerini yalnızca aşağıdaki akademik ve resmi tıp kaynaklarından derler. Blog yazıları, özel hastane siteleri veya reklam içerikli kaynaklar kesinlikle kullanılmaz.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                // Onaylı Kaynak Kategorileri
                ForEach(Array(sourceCategories.enumerated()), id: \.offset) { _, category in
                    VStack(alignment: .leading, spacing: 10) {
                        Label(category.title, systemImage: category.icon)
                            .font(.headline)

                        ForEach(Array(category.sources.enumerated()), id: \.offset) { _, source in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.0)
                                        .font(.subheadline.bold())
                                    if let urlString = source.1, let url = URL(string: urlString) {
                                        Button {
                                            openURL(url)
                                        } label: {
                                            Text(urlString)
                                                .font(.caption)
                                                .foregroundColor(.accentColor)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Divider()

                // Kullanılan Kaynaklar (cache'ten)
                if cachedData.isEmpty {
                    ContentUnavailableView(
                        "Henüz Kaynak Yok",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Tahlil sonuçlarınız analiz edildiğinde kullanılan spesifik kaynaklar burada listelenecektir.")
                    )
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Analizlerde Kullanılan Kaynaklar", systemImage: "book.closed.fill")
                            .font(.headline)

                        Text("Aşağıda, tahlil değerleriniz için AI tarafından referans alınan spesifik kaynaklar listelenmiştir.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ForEach(Array(cachedData.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.valueName.uppercased())
                                    .font(.subheadline.bold())
                                    .foregroundColor(.accentColor)

                                ForEach(Array(item.sources.enumerated()), id: \.offset) { _, source in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.top, 2)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(source.name)
                                                .font(.caption)
                                            if let urlString = source.url, let url = URL(string: urlString) {
                                                Button {
                                                    openURL(url)
                                                } label: {
                                                    Text(urlString)
                                                        .font(.caption2)
                                                        .foregroundColor(.accentColor)
                                                        .lineLimit(1)
                                                        .truncationMode(.middle)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.ultraThinMaterial)
                            .cornerRadius(10)
                        }
                    }
                }

                // Uyarı
                Label("Tüm bilgiler yalnızca bilgilendirme amaçlıdır. Tıbbi tanı veya tedavi yerine geçmez.", systemImage: "info.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
            .padding()
        }
        .navigationTitle("Kaynaklar")
    }
}
