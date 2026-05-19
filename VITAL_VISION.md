# VitalTrace - Temel Yapı Taşları ve Vizyon

Bu dosya, uygulamanın temel geliştirme prensiplerini ve öncelikli özelliklerini içerir.

## 1. Görsel ve Fonksiyonel Tasarım
- **Trendler:** Sayfa yapısı tek sütun (1 column) olarak optimize edilecek.
- **Kayıt Listesi:** Kayıtlar mail kutusu gibi satır satır, temiz bir liste görünümünde olacak.
- **Bilgi Erişimi:** Her değerin yanında kısa açıklama için "i" ikonu ve detaylı akademik bilgi için sağdan açılan bilgi kutucuğu bulunacak.

## 2. Veri Yönetimi ve Analiz
- **Akıllı Birleştirme:** Benzer tıbbi değerler farklı zamanlarda/yerlerde ölçülmüş olsa bile tek bir grafikte birleştirilerek gösterilecek.
- **Kategorizasyon:** Değerler organ/sistem bazlı (Böbrek, Karaciğer vb.) gruplanacak ve bu kategoriler toplu grafikler üzerinden izlenebilecek.
- **Geniş Kapsam:** Sadece kan/idrar tahlili değil; MR, BT, Ultrason gibi radyolojik raporlar da sistemde saklanabilecek.
- **Orijinal Belge Sadakati:** Import edilen PDF'lerin orijinalleri saklanacak ve sonuç ekranında sağ tarafta görüntülenebilecek.

## 3. Akademik Yapay Zeka (AI) Entegrasyonu
- **Kaynak Kısıtı:** Yapay zeka yorumları **SADECE** akademik makaleler, üniversite hastaneleri ve resmi tıp kaynakları (PubMed, NCBI, WHO vb.) kullanılarak yapılacak.
- **Filtreleme:** Blog yazıları, özel hastane reklam içerikleri veya doktor klinik siteleri kesinlikle dikkate alınmayacak.
- **Domain Whitelist:** Uygulama, sadece onaylanmış (whitelist) domainlerden gelen bilgileri işleyebilir. (Bkz: `apps/web/src/lib/constants/sources.ts`)
- **Kaynak Gösterimi:** Her tıbbi yorumun altında ilgili akademik kaynağa doğrudan link (PubMed ID veya direkt URL) bulunacak.
- **Güncellik:** Akademik kaynaklar periyodik olarak taranacak ve özet bilgiler sisteme aktarılacak.

## 4. Teknik Altyapı
- **Konteynerizasyon:** Uygulamanın Docker versiyonu hazırlanacak.
- **Mobil Strateji:** Mimari, ileride geliştirilecek iOS uygulamasına veri sağlayacak şekilde (API-first) kurgulanacak.
