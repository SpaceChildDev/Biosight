import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Gizlilik Politikası")
                        .font(.title2.bold())

                    Text("Son Güncelleme: Nisan 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Temel ilke
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .font(.title)
                                .foregroundColor(.accentColor)
                            Text("Gizliliğiniz Bizim Önceliğimiz")
                                .font(.title2.bold())
                        }

                        Text("Biosight olarak kullanıcılarımızın gizliliğine en yüksek önemi veriyoruz. Hiçbir kişisel sağlık verinizi toplamıyoruz, saklamıyoruz veya üçüncü taraflarla paylaşmıyoruz.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(12)

                    policySection(
                        icon: "iphone",
                        title: "Veri Depolama",
                        content: "Sağlık verileriniz cihazınızda (iPhone/iPad) ve iCloud hesabınızda saklanır. Biosight'ın kendine ait sunucusu yoktur."
                    )

                    policySection(
                        icon: "brain.head.profile",
                        title: "AI Analizi (İsteğe Bağlı)",
                        content: "AI analizi kullandığınızda tahlil değerleriniz Google Gemini servisine gönderilir. Yalnızca tahlil değerleri gönderilir; adınız, doğum tarihiniz gibi kişisel bilgiler gönderilmez. AI kullanımı tamamen isteğe bağlıdır — kullanmadığınız sürece hiçbir veriniz dışarıya çıkmaz."
                    )

                    policySection(
                        icon: "heart.fill",
                        title: "Apple Health",
                        content: "Apple Health verilerinize yalnızca sizin izninizle erişilir. Bu veriler cihazınızda işlenir."
                    )

                    policySection(
                        icon: "chart.bar.fill",
                        title: "Analitik ve Takip",
                        content: "Uygulama deneyimini iyileştirmek için anonim kullanım istatistikleri toplayabiliriz (örn: hangi özelliklerin daha çok kullanıldığı). Bu veriler tamamen anonimdir ve kimliğinizle ilişkilendirilemez. Kişisel sağlık verileriniz hiçbir zaman analitik amaçla kullanılmaz."
                    )

                    policySection(
                        icon: "text.magnifyingglass",
                        title: "Anonim Değer Adı Toplama (Açıklama Güncellemeleri)",
                        content: """
                        Tahlillerinizde bulunan değerlerin YALNIZCA İSİMLERİNİ (örn: "Eritrosit", "TSH") anonim olarak toplayabiliriz. Bu veriler:

                        ✓ Tamamen anonimdir — kim olduğunuz bilinmez
                        ✓ Sadece değer adı gönderilir, sonuç/değer gönderilmez
                        ✓ Kişisel bilgi içermez
                        ✓ Açıklama içeriğini iyileştirmek için kullanılır

                        Bu sayede yaygın değerler için Türkçe açıklamalar hazırlanır ve tüm kullanıcılara otomatik güncelleme olarak sunulur. Şeffaflık birinci önceliğimizdir.
                        """
                    )

                    policySection(
                        icon: "megaphone.fill",
                        title: "Reklam",
                        content: "Uygulamada reklam gösterilmesi durumunda, reklam ağları genel kullanım istatistikleri toplayabilir. Ancak sağlık verileriniz kesinlikle reklam amaçlı kullanılmaz ve reklam ağlarıyla paylaşılmaz."
                    )

                    policySection(
                        icon: "hand.raised.fill",
                        title: "Toplamadığımız Veriler",
                        content: """
                        Aşağıdaki verileri TOPLAMIYORUZ:
                        - Kişisel sağlık verileri (tahlil sonuçları, Apple Health verileri)
                        - Ad, soyad, e-posta, telefon numarası
                        - Konum bilgisi
                        - Kişi listesi veya fotoğraflar
                        - Cihazınızdaki diğer uygulamalara ait veriler
                        """
                    )

                    policySection(
                        icon: "trash.fill",
                        title: "Veri Silme",
                        content: "Uygulamayı sildiğinizde tüm yerel verileriniz otomatik olarak silinir. iCloud'daki verilerinizi Ayarlar > iCloud > Depolama Alanını Yönet bölümünden silebilirsiniz."
                    )

                    policySection(
                        icon: "envelope.fill",
                        title: "İletişim",
                        content: "Gizlilik politikamız hakkında sorularınız için privacy@spacechild.dev adresinden bizimle iletişime geçebilirsiniz."
                    )

                    // Alt bilgi
                    Text("Bu gizlilik politikası zaman zaman güncellenebilir. Değişiklikler uygulama içinden bildirilecektir.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Gizlilik")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }

    private func policySection(icon: String, title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
