# VitalTrace Roadmap & Aksiyon Planı

## 🎯 Güncel Hedefler ve Değişiklikler

### 🧪 Tahlil Yönetimi (Yeniden Yapılandırma)
- [x] **Menü İsmi Değişikliği:** "Tahlillerim" menüsü "Tahlil" olarak güncellenecek. (iOS ve Web)
- [x] **Tahlil Listeleme:** Tahlillerin alt alta değer bazlı listelenmesi yerine, her bir tahlil raporu ayrı bir giriş (entry) olarak gösterilecek.
- [x] **Tahlil Detay Görünümü:** 
    - [x] Bir tahlil raporuna tıklandığında içindeki tüm değerler (parametreler) listelenecek.
    - [x] Orijinal PDF dosyasına bu detay sayfasından ulaşılabilecek.
- [x] **Kategorizasyon & Metrik Gruplama:** 
    - [x] Dashboard veya "Trendler" bölümünde değerler metrik bazlı (örn: Kreatinin, Üre) gruplanacak.
    - [x] Aynı metrikten farklı tarihlerde birden fazla kayıt varsa, bunlar alt alta listelenmek yerine tek bir satırda gösterilecek.
    - [x] Metriğin içine girildiğinde kronolojik geçmiş listesi ve değişim grafiği görüntülenecek.

### 📚 Kaynak ve AI İyileştirmeleri
- [x] **Akademik Kaynak Whitelist:** Onaylı domain listesi oluşturuldu. (`lib/constants/sources.ts`)
- [x] **Kaynakça Menüsü:** Tüm akademik kaynakların listelendiği "Kaynaklar" sayfası oluşturuldu. Ayarlar sayfasına taşındı.
- [x] **AI Filtreleme:** LLM promptlarına genişletilmiş whitelist kuralı eklendi (PubMed, NCBI, PMC, Cochrane, WHO, NIH, CDC, CLSI, Mayo Clinic, Johns Hopkins, KDIGO, ADA, ACC/AHA, ESC + alan bazlı dergiler).
- [x] **Klinik Kaynak Temizliği:** Doktor klinik siteleri ve reklam içerikli kaynaklar engellendi.
- [x] **Mevcut Veri Temizliği:** Mock verilerdeki "Özel Klinik" gibi ifadeler temizlendi.

### 📱 iOS Uygulaması (SwiftUI)
- [ ] Web'deki veri yapısıyla tam uyumlu hale getirilmesi.
- [x] SwiftData entegrasyonu ile çevrimdışı çalışma desteği.
- [x] **API Anahtar Güvenliği:** Hardcode anahtarlar temizlendi, xcconfig + Info.plist ile gömülü anahtar sistemi kuruldu.
- [x] **App Icon:** VitalTrace logosu eklendi (1024x1024).
- [x] **Tahlil Inbox Tasarımı:** Mail kutusu tarzı rapor bazlı liste, rapor detay sayfası.
- [x] **Değer Detayında Trend Grafiği:** Bir değere tıklandığında o değerin önceki ve sonraki ölçümleri ile mini trend grafiği gösterilecek.
- [x] **Çoklu Profil:** Premium kullanıcılar aile bireylerini ayrı profillerde takip edebilir.
- [x] **Arka Plan PDF İşleme:** PDF'ler anında import edilip arka planda AI ile işleniyor.

---

## 🛠️ Teknik Altyapı Planı

### Faz 1 — Temel Altyapı (Öncelik)
- [x] Next.js 15 projesi oluştur, shadcn/ui + tema kur
- [x] Veritabanı şema + Drizzle ORM setup (Neon Postgres)
- [x] Kişi CRUD
- [x] PDF upload + Claude API ile parse
- [x] Tahlil sonuçları tablo görünümü

### Faz 2 — Görselleştirme ve Gruplama (Devam Ediyor)
- [ ] **Parametre bazlı zaman serisi grafikleri (Recharts)**
- [ ] **Metrik bazlı gruplandırılmış liste görünümü**
- [ ] Referans bant gösterimi
- [ ] İki tahlil karşılaştırma modu

### Faz 3 — Apple Health
- [x] Ham XML upload + SAX streaming parse (Temel altyapı)
- [x] İşlenmiş CSV import desteği
- [ ] Health dashboard (kalp hızı, adım, uyku, vb.)
- [ ] Günlük/haftalık/aylık trend grafikleri

### Faz 4 — Ekstralar
- [ ] AI sağlık yorumu (Claude) - Akademik kaynak kısıtlı
- [ ] Anomali özet kartları
- [ ] PDF rapor export
- [ ] Metrik korelasyon grafikleri

### Faz 5 — Monetizasyon: Reklam Entegrasyonu
- [ ] **Google AdMob entegrasyonu** (iOS SDK)
- [ ] **Ücretsiz hesaplar reklamlı** — abonelik alınırsa reklamlar kaldırılır
- [ ] **Reklam pozisyonları:** Banner (liste altları), interstitial (PDF import sonrası)
- [ ] **Reklam kuralı:** Sağlık verisi içeren sayfalarda (detay, dashboard) reklam gösterilmez — sadece nötr sayfalarda
- [ ] **GDPR/ATT uyumu:** App Tracking Transparency izin akışı, iOS 14.5+ zorunlu
- [ ] **SubscriptionService entegrasyonu:** `currentTier == .free` ise reklam göster, değilse gizle

### Faz 6 — Profil Paylaşımı
- [ ] **Profil dışa aktarma:** Kişi profili + tüm tahlil sonuçları JSON/PDF olarak export
- [ ] **Profil içe aktarma:** Paylaşılan profil dosyasını başka cihazda import etme
- [ ] **QR kod ile paylaşım:** Profil bağlantısını QR kod ile paylaşma (yakındaki cihazlar)
- [ ] **AirDrop desteği:** iOS cihazlar arası doğrudan profil transferi
- [ ] **Doktor paylaşımı:** Seçilen tarih aralığındaki sonuçları doktora PDF olarak gönderme
- [ ] **Gizlilik:** Paylaşımda kişisel bilgi (ad, doğum tarihi) opsiyonel — sadece değerler de gönderilebilir

### Faz 7 — Açıklama Altyapısı (Anonim Değer Adı Toplama)
- [ ] **Anonim değer adı toplama:** Tahlilden yalnızca parametre isimleri (ör: "Eritrosit") anonim olarak sunucuya gönderilir. Sonuçlar, tarihler, kişisel bilgiler kesinlikle gönderilmez.
- [ ] **Şeffaflık:** Gizlilik Politikası'nda açıkça belgelendi. Kullanıcı bildirimi ile aktif edilecek.
- [ ] **Otomatik açıklama güncellemesi:** Toplanan yaygın değer isimleri için açıklamalar hazırlanır, push notification ile kullanıcıya sunulur.
- [ ] **Periyodik güncelleme:** AcademicNoteCache haftalık olarak güncellenir (API anahtarı olmayan kullanıcılar için pre-built açıklamalar push edilir).

### Faz 8 — İlaç Takibi & Sağlık Hatırlatıcıları
- [ ] **İlaç Takibi:** İlaç adı, dozu, kullanım sıklığı, başlangıç/bitiş tarihi girişi
- [ ] **Hatırlatıcı:** iOS bildirim sistemi ile ilaç alma saati hatırlatması (UNUserNotificationCenter)
- [ ] **Alındı/Atlandı İzleme:** Her doz için "aldım" / "atladım" kaydı, uyum istatistiği
- [ ] **Su İçme Hatırlatıcısı:** Gün içinde belirli aralıklarla su içme bildirimi; hedef tüketim takibi
- [ ] **İlaç-Tahlil Korelasyonu:** Hangi ilacı kullanırken hangi değerlerin değiştiğini görme

### Faz 8 — Sesli Belirti & Tüketim Günlüğü (AI Asistan)
- [ ] **Sesli Not Butonu:** Sağ alt köşede floating action button, tıklanınca ses kaydı başlar
- [ ] **Konuşma → Metin:** Speech-to-text ile belirtiler ve tüketilen şeyler otomatik yazıya dökülür
- [ ] **Akıllı Ayrıştırma:** AI ile belirtiler (gaz, şişkinlik, baş ağrısı vb.) ve tüketimler (süt, kahve, ilaç vb.) ayrı kategorilere ayrılır
- [ ] **Zaman Damgası:** Her kayıt tarih ve saat ile otomatik etiketlenir
- [ ] **Günlük Görünümü:** Kronolojik belirti/tüketim zaman çizelgesi
- [ ] **Çıktı & Paylaşım:** Belirti günlüğünü PDF/metin olarak dışa aktarma (doktora götürmek için)
- [ ] **Korelasyon:** Belirtilerle tahlil değerleri arasında zaman bazlı eşleştirme

---

## 📜 Temel Prensipler (VITAL_VISION.md)
- Tek sütun (1 column) optimize trend görünümü.
- Mail kutusu sadeliğinde liste görünümü.
- Orijinal belgeye her an erişim.
- Akademik ciddiyet ve kaynak disiplini.
