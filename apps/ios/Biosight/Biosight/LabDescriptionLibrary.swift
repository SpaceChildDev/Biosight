import Foundation

/// Common lab value descriptions in multiple languages.
/// Key = lowercased, trimmed value name. Falls back to English if the device
/// language is not explicitly supported.
struct LabDescriptionLibrary {

    // MARK: - Public API

    /// Returns a description for the given value name in the device's current language.
    static func description(for valueName: String) -> String? {
        description(for: valueName, locale: .current)
    }

    /// Returns a description for the given value name in the specified locale.
    static func description(for valueName: String, locale: Locale) -> String? {
        let lang = resolvedLangCode(locale)
        let key  = normalize(valueName)

        let dict = libraries[lang] ?? libraries["en"]!

        // 1. Exact match
        if let desc = dict[key] { return desc }

        // 2. Word-token partial match (prevents "üre" matching "süresi")
        let keyTokens = Set(key.components(separatedBy: " ").filter { !$0.isEmpty })
        for (libKey, desc) in dict {
            let libTokens = Set(libKey.components(separatedBy: " ").filter { !$0.isEmpty })
            // Accept only if there is a shared whole word AND the libKey is reasonably specific
            if !keyTokens.isDisjoint(with: libTokens) && libKey.count > 2 {
                return desc
            }
        }

        // 3. Cross-language fallback: try English
        if lang != "en" {
            return description(for: valueName, locale: Locale(identifier: "en"))
        }
        return nil
    }

    // MARK: - Value name canonicalization

    /// Maps known archaic/variant spellings to their canonical modern form.
    /// Apply this when saving a value name from any external source (AI, PDF parser).
    static func canonicalize(_ valueName: String) -> String {
        let aliases: [String: String] = [
            // Türkçe arkaik yazımlar → modern Türkçe
            "ürik asid":    "Ürik Asit",
            "urik asit":    "Ürik Asit",
            "urik asid":    "Ürik Asit",
            "klorid":       "Klor",
            "klorit":       "Klor",
            "sodyum (na)":  "Sodyum",
            "potasyum (k)": "Potasyum",
            "kalsiyum (ca)":"Kalsiyum",
            // İngilizce → standart İngilizce
            "uric acid":    "Uric Acid",
            "uric-acid":    "Uric Acid",
        ]
        let key = valueName.lowercased().trimmingCharacters(in: .whitespaces)
        return aliases[key] ?? valueName
    }

    // MARK: - Helpers

    private static func normalize(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespaces)
    }

    /// Maps a Locale to a supported language code, defaulting to "en".
    private static func resolvedLangCode(_ locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier
            ?? locale.identifier.prefix(2).lowercased()
        let supported = Set(libraries.keys)
        return supported.contains(code) ? code : "en"
    }

    // MARK: - Language Registry

    private static let libraries: [String: [String: String]] = [
        "tr": turkish,
        "en": english,
        "de": german,
        "fr": french,
        "es": spanish,
        "ar": arabic,
        "ru": russian,
    ]

    // MARK: - Turkish

    private static let turkish: [String: String] = [
        // Hemogram
        "eritrosit": "Kırmızı kan hücresi (RBC) sayısıdır. Oksijeni akciğerlerden vücudun tüm dokularına taşır. Düşük eritrosit sayısı anemi (kansızlık) belirtisi olabilirken yüksek değerler polisitemi veya dehidrasyona işaret edebilir.",
        "rbc": "Kırmızı kan hücresi (eritrosit) sayısıdır. Oksijeni akciğerlerden dokulara taşır. Düşük değer anemi; yüksek değer polisitemi veya dehidrasyon belirtisi olabilir.",
        "hemoglobin": "Alyuvarların içindeki oksijen taşıyıcı demir içerikli proteindir. Kansızlığın (aneminin) en temel göstergesidir. Düşük hemoglobin yorgunluk, nefes darlığı ve solgunluğa yol açabilir.",
        "hgb": "Hemoglobin değeridir. Alyuvarlardaki oksijen taşıyıcı proteindir. Kansızlığın temel göstergesidir.",
        "hematokrit": "Kanda alyuvarların kapladığı hacim yüzdesidir. Anemi ve polisitemi tanısında hemoglobin ile birlikte değerlendirilir.",
        "hct": "Hematokrit değeridir. Kanda alyuvarların oranını gösterir. Anemi tanısında önemli bir parametredir.",
        "mcv": "Ortalama alyuvar hacmidir. Düşük MCV demir eksikliği anemisini; yüksek MCV B12 veya folik asit eksikliğini akla getirir.",
        "mch": "Ortalama alyuvar hemoglobin miktarıdır. Her alyuvardaki ortalama hemoglobin miktarını ifade eder.",
        "mchc": "Ortalama alyuvar hemoglobin konsantrasyonudur. MCV ve MCH ile birlikte anemi sınıflandırmasında kullanılır.",
        "rdw": "Kırmızı kan hücrelerinin boyut farklılığını gösteren parametredir. Yüksek RDW, demir eksikliği veya B12 eksikliği anemilerinde görülür.",
        "lökosit": "Beyaz kan hücresi (WBC) sayısıdır. Bağışıklık sisteminin temel unsurlarıdır. Yüksek değer enfeksiyon veya iltihap; düşük değer bağışıklık zayıflığını gösterebilir.",
        "wbc": "Beyaz kan hücresi sayısıdır. Bağışıklık sisteminin temel hücreleridir. Yüksek değer enfeksiyon; düşük değer bağışıklık zayıflığını gösterebilir.",
        "nötrofil": "En yaygın beyaz kan hücresidir. Bakteriyel enfeksiyonlara karşı ilk savunma hattını oluşturur. Düşük nötrofil (nötropeni) enfeksiyona yatkınlığa işaret eder.",
        "lenfosit": "Virüslere ve tümör hücrelerine karşı savunma sağlayan beyaz kan hücreleridir. Yüksek lenfosit viral enfeksiyonları; düşük değer bağışıklık sorunlarını akla getirebilir.",
        "monosit": "Büyük beyaz kan hücreleridir; dokuya geçince makrofaja dönüşür. Kronik enfeksiyon veya iltihapla ilişkili olabilir.",
        "eozinofil": "Alerjik reaksiyonlarda ve parazit enfeksiyonlarında artış gösteren beyaz kan hücresidir.",
        "bazofil": "En az sayıda bulunan beyaz kan hücresidir. Alerjik yanıtlarda görev yapar.",
        "trombosit": "Kanın pıhtılaşmasını sağlayan küçük hücrelerdir. Düşük trombosit kanama riskini; yüksek trombosit pıhtı riskini artırır.",
        "plt": "Trombosit sayısıdır. Kanın pıhtılaşmasını sağlar. Düşük değer kanama; yüksek değer pıhtı riski taşır.",
        "mpv": "Ortalama trombosit hacmidir. Yüksek MPV daha aktif trombositlere işaret edebilir ve kardiyovasküler riskle ilişkilendirilir.",
        "pdw": "Trombosit boyut farklılığını gösteren indekstir.",
        // Karaciğer
        "alt": "Karaciğer hasar göstergesi olan bir enzimdir. Yüksek ALT karaciğer hasarına, hepatite veya yağlı karaciğere işaret edebilir.",
        "sgpt": "ALT (Alanin aminotransferaz) enzimidir. Karaciğer hasarının önemli bir göstergesidir.",
        "ast": "Karaciğer, kalp ve iskelet kasında bulunan bir enzimdir. Yüksek AST karaciğer hasarını, kalp krizini veya kas hasarını işaret edebilir.",
        "sgot": "AST (Aspartat aminotransferaz) enzimidir. Karaciğer ve kalp hasarının göstergesidir.",
        "ggt": "Karaciğer ve safra yolu hastalıklarında yükselen, alkole duyarlı bir enzimdir.",
        "gamma gt": "GGT (Gama-glutamil transferaz) enzimidir. Karaciğer hasarı ve alkol tüketiminin göstergesidir.",
        "alp": "Karaciğer, kemik ve safra yollarında bulunan bir enzimdir. Yüksek ALP safra yolu tıkanıklığını, kemik hastalığını veya karaciğer hasarını gösterebilir.",
        "total bilirubin": "Hemoglobinin parçalanmasından oluşan sarı pigmenttir. Yüksek değer sarılığa yol açabilir ve karaciğer ya da safra yolu sorunlarıyla ilişkilidir.",
        "direkt bilirubin": "Karaciğerde işlenmiş bilirubin miktarıdır. Yüksek değer safra yolu tıkanıklığını düşündürür.",
        "indirekt bilirubin": "İşlenmemiş serbest bilirubin miktarıdır. Yüksek değer aşırı alyuvar yıkımını akla getirebilir.",
        "albumin": "Karaciğer tarafından üretilen en önemli kan proteinidir. Düşük albumin karaciğer hastalığını, yetersiz beslenmeyi veya böbrek kaybını gösterebilir.",
        "total protein": "Kanda bulunan tüm proteinlerin toplam miktarıdır. Karaciğer fonksiyonu ve beslenme durumunun değerlendirilmesinde kullanılır.",
        // Böbrek
        "kreatinin": "Böbrekler tarafından atılan kas metabolizması atığıdır. Yüksek kreatinin böbrek fonksiyon bozukluğunun önemli bir göstergesidir.",
        "bun": "Kan üre nitrojenidir. Böbrek fonksiyonunu değerlendirmede kreatinin ile birlikte kullanılır.",
        "üre": "Proteinin parçalanmasıyla oluşan ve böbrekler tarafından atılan atık bir üründür.",
        "ürik asit": "Pürin metabolizmasının son ürünüdür. Yüksek değer gut hastalığına yol açabilir ve böbrek taşı riskini artırabilir.",
        "ürik asid": "Pürin metabolizmasının son ürünüdür. Yüksek değer gut hastalığına yol açabilir ve böbrek taşı riskini artırabilir.",
        "egfr": "Böbreklerin dakikada kanı ne kadar filtrelediğini gösterir. 60 mL/dk/1.73m² altındaki değerler böbrek fonksiyon bozukluğuna işaret eder.",
        // Tiroid
        "tsh": "Tiroid uyarıcı hormondur. Yüksek TSH hipotiroidizmi; düşük TSH hipertiroidizmi gösterebilir.",
        "t3": "Tiroid bezi tarafından üretilen ve metabolizmayı düzenleyen hormondur.",
        "t4": "Tiroid bezinin ürettiği ve T3'e dönüşen temel hormondur.",
        "serbest t3": "Aktif (bağlanmamış) triiyodotironin miktarıdır. Tiroid fonksiyonunun güvenilir bir göstergesidir.",
        "ft3": "Serbest T3 değeridir. Aktif tiroid hormonunu gösterir.",
        "serbest t4": "Aktif tiroksin miktarıdır. TSH ile birlikte tiroid hastalıklarının tanısında temel parametredir.",
        "ft4": "Serbest T4 değeridir. Aktif tiroid hormonunu gösterir.",
        "anti-tpo": "Tiroid bezine karşı üretilen otoimmün antikordur. Yüksek değer Hashimoto tiroiditi veya Graves hastalığını düşündürür.",
        "anti-tg": "Tiroglobuline karşı üretilen otoimmün antikordur. Anti-TPO ile birlikte otoimmün tiroid hastalıklarında değerlendirilir.",
        // Lipid
        "total kolesterol": "Kanda bulunan tüm kolesterol türlerinin toplamıdır. LDL, HDL ve trigliserid ile birlikte kardiyovasküler risk değerlendirilir.",
        "ldl kolesterol": "'Kötü kolesterol' olarak bilinir. Damar duvarlarında birikerek ateroskleroza yol açabilir.",
        "ldl": "LDL kolesteroludür. 'Kötü kolesterol' olarak bilinir. Yüksek LDL kalp hastalığı riskini artırır.",
        "hdl kolesterol": "'İyi kolesterol' olarak bilinir. Damarlardan kolesterol taşıyarak uzaklaştırır. Yüksek HDL kardiyovasküler koruma sağlar.",
        "hdl": "HDL kolesteroludür. 'İyi kolesterol' olarak bilinir. Yüksek HDL kalp-damar sağlığını korur.",
        "trigliserid": "Kanda bulunan yağ türüdür. Yüksek değer kardiyovasküler hastalık riskini artırır.",
        "vldl": "Çok düşük yoğunluklu lipoprotein; trigliserid taşıyan bir lipoprotein türüdür.",
        // Şeker
        "açlık kan şekeri": "8 saatlik açlık sonrası ölçülen kan şekeridir. 100–125 mg/dL arası prediyabeti; 126 mg/dL ve üzeri diyabeti gösterebilir.",
        "glikoz": "Kandaki şeker miktarıdır. Yüksek glikoz diyabet veya prediyabete işaret edebilir.",
        "kan şekeri": "Kandaki şeker miktarıdır. Diyabet izleminde temel parametredir.",
        "hba1c": "Son 2–3 aydaki ortalama kan şekeri kontrolünü gösterir. %6.5 ve üzeri diyabeti; %5.7–6.4 arası prediyabeti gösterebilir.",
        "hemoglobin a1c": "Son 2–3 aydaki ortalama kan şekeri düzeyini yansıtır. Diyabet tanısı ve takibinde kritik bir parametredir.",
        "insülin": "Kan şekerini düzenleyen hormondur. Yüksek insülin insülin direncini; düşük insülin tip 1 diyabeti akla getirebilir.",
        "açlık insülin": "Açlık sonrası ölçülen insülin düzeyidir. Yüksek değer insülin direncine işaret edebilir.",
        "homa-ir": "İnsülin direncinin hesaplanan bir göstergesidir. 2.5 üzerindeki değerler insülin direncini düşündürür.",
        // Demir
        "serum demir": "Kanda serbest halde bulunan demir miktarıdır. Ferritin ve TIBC ile birlikte değerlendirilir.",
        "demir": "Kandaki demir miktarıdır. Düşük değer demir eksikliği anemisini gösterebilir.",
        "tibc": "Total demir bağlama kapasitesidir. Yüksek TIBC demir eksikliğine; düşük TIBC kronik hastalık anemisine işaret edebilir.",
        "demir bağlama kapasitesi": "Kandaki transferrinin ne kadar demir bağlayabileceğini gösterir. Demir eksikliğinde yükselir.",
        "ferritin": "Vücuttaki demir depolarını yansıtan proteindir. Düşük ferritin demir depolarının tükendiğini; yüksek ferritin kronik iltihap veya demir yükünü gösterebilir.",
        "transferrin": "Demiri kanda taşıyan proteindir.",
        // Vitaminler
        "b12": "Sinir sistemi sağlığı ve alyuvar üretimi için gereklidir. Eksikliği megaloblastik anemiye ve sinir hasarına yol açabilir.",
        "vitamin b12": "Sinir sistemi ve kan üretimi için kritik öneme sahip vitamindir. Eksikliği anemi ve sinir hasarına yol açabilir.",
        "d vitamini": "Kemik sağlığı, bağışıklık sistemi ve pek çok metabolik süreç için gereklidir. Türkiye'de yaygın bir eksiklik durumudur.",
        "25-oh vitamin d": "D vitamininin kandaki aktif formudur. 20 ng/mL altı eksikliği; 20–30 ng/mL arası yetersizliği gösterir.",
        "folik asit": "Hücre bölünmesi ve alyuvar üretimi için gereklidir. Hamilelikte özellikle önemlidir.",
        "b9": "Folik asit (B9 vitamini) değeridir. Hücre bölünmesi ve DNA sentezi için gereklidir.",
        "çinko": "Bağışıklık sistemi ve yara iyileşmesi için gerekli mineraldir.",
        "magnezyum": "Kemik sağlığı, kas ve sinir işlevi için gerekli mineraldir.",
        // Elektrolitler
        "sodyum": "Vücut sıvı dengesi ve kan basıncı düzenlemesinde kritik elektrolitdir. Yüksek sodyum dehidrasyonu; düşük sodyum böbrek veya hormonal sorunları akla getirebilir.",
        "potasyum": "Kalp ritmi ve kas fonksiyonu için kritik elektrolitdir. Dengesizliği ciddi kalp ritim bozukluklarına yol açabilir.",
        "kalsiyum": "Kemik ve diş sağlığı, kas kasılması ve sinir iletimi için gerekli mineraldir.",
        "klor": "Vücut sıvı dengesi ve asit-baz dengesini düzenleyen elektrolitdir.",
        "fosfor": "Kemik yapısının önemli bileşenidir. Böbrek hastalıklarında yükselebilir.",
        // Kardiyovasküler
        "crp": "Enfeksiyon veya iltihap varlığında karaciğer tarafından üretilen proteindir. Yüksek CRP enfeksiyon veya doku hasarını gösterir.",
        "c reaktif protein": "Enfeksiyon ve iltihap durumlarında yükselen proteindir.",
        "hscrp": "Düşük düzeydeki kronik iltihabı ölçer. Kardiyovasküler hastalık riskini tahmin etmede kullanılır.",
        "sedimantasyon": "Eritrosit sedimantasyon hızıdır. Vücuttaki iltihabi durumların özgül olmayan bir göstergesidir.",
        "esr": "Eritrosit sedimantasyon hızıdır. Vücuttaki iltihabi durumların göstergesidir.",
        "d-dimer": "Pıhtı oluşumu ve çözülmesinin göstergesidir. Yüksek D-dimer pulmoner emboli veya derin ven trombozuna işaret edebilir.",
        "fibrinojen": "Pıhtılaşmada görev yapan plazma proteinidir. Yüksek değer kardiyovasküler risk ve iltihabın göstergesi olabilir.",
        "homosistein": "Yüksek homosistein kardiyovasküler hastalık, felç riskini artırabilir. B12, B6 ve folik asit eksikliğiyle ilişkilidir.",
        "troponin": "Kalp kas hasarına özgü proteindir. Kalp krizi tanısında altın standarttır.",
        // Enzimler
        "ck": "Kalp kası, iskelet kası ve beyinde bulunan enzimdir. Yüksek CK kalp krizi veya kas hasarını gösterir.",
        "kreatin kinaz": "Kalp ve kas hasarının göstergesidir.",
        "ldh": "Doku hasarının özgül olmayan göstergesidir. Kalp, karaciğer veya kan hastalıklarında yükselebilir.",
        "amilaz": "Pankreas ve tükürük bezlerinden salgılanan, nişastayı parçalayan enzimdir. Yüksek amilaz pankreatiti düşündürür.",
        "lipaz": "Yağları parçalayan pankreatite özgü enzimdir.",
        // Hormonlar
        "fsh": "Folikül uyarıcı hormondur. Kadınlarda yumurtalık fonksiyonu; erkeklerde sperm üretimi için gereklidir.",
        "lh": "Lüteinizan hormondur. Kadınlarda ovülasyonu tetikler; erkeklerde testosteron üretimini uyarır.",
        "prolaktin": "Süt üretimini uyaran hipofiz hormondur. Yüksek prolaktin adet düzensizliğine ve infertiliteye yol açabilir.",
        "estradiol": "En güçlü östrojen hormonudur. Üreme fonksiyonu ve kemik yoğunluğu için önemlidir.",
        "e2": "Estradiol (E2) değeridir. Menstrüel döngü ve menopoz değerlendirmesinde kullanılır.",
        "progesteron": "Menstrüel döngüyü düzenleyen ve hamileliği sürdüren hormondur.",
        "testosteron": "Androjen hormondur. Kas kütlesi, kemik yoğunluğu ve libidoyu etkiler.",
        "total testosteron": "Kanda toplam testosteron miktarıdır. Düşük değer erkeklerde hipogonadizme işaret edebilir.",
        "kortizol": "Stres hormonudur. Yüksek kortizol Cushing sendromunu; düşük değer Addison hastalığını akla getirebilir.",
        "dhea-s": "Böbreküstü bezinden salgılanan, cinsiyet hormonlarının öncüsüdür. Yaşla birlikte azalır.",
        "dheas": "DHEA-S hormonu değeridir.",
        "acth": "Hipofizden salgılanan, böbreküstü bezlerini kortizol üretmesi için uyaran hormondur.",
        "igf-1": "Büyüme hormonu düzeyinin dolaylı göstergesidir. Büyüme hormonu eksikliği veya fazlalığının tespitinde kullanılır.",
        // İdrar
        "idrar dansitesi": "Böbreklerin idrarı konsantre etme yeteneğini yansıtır.",
        "idrar ph": "İdrarın asit-baz dengesini gösterir.",
        "idrar proteini": "Normalde idrarda az protein bulunur. Yüksek değer böbrek hasarının erken göstergesi olabilir.",
        "idrar glukozu": "Normalde idrarda glikoz bulunmaz. İdrarda glikoz varlığı kan şekeri yüksekliğini gösterebilir.",
        // PSA
        "psa": "Prostat spesifik antijenidir. Yüksek PSA prostat kanseri, büyümesi veya iltihabını akla getirebilir.",
        "total psa": "Prostat spesifik antijen toplam değeridir.",
        // Tümör belirteçleri
        "cea": "Bazı kanserlerin takibinde kullanılan tümör belirtecidir.",
        "afp": "Karaciğer ve testis kanserinin takibinde kullanılan tümör belirtecidir.",
        "ca 125": "Yumurtalık kanserinin takibinde kullanılan tümör belirtecidir.",
        "ca 19-9": "Pankreas ve safra yolu kanserinin takibinde kullanılan tümör belirtecidir.",
        // Apple Health — Kardiyovasküler
        "kalp atış hızı": "Dakikada kaç kez attığını gösteren kalp ritmidir. Dinlenme halindeki normal kalp hızı 60–100 atım/dk arasındadır. Sürekli yüksek veya düşük değerler kalp ritim sorunlarını işaret edebilir.",
        "dinlenme kalp hızı": "Tam dinlenme halindeyken ölçülen kalp hızıdır. Düşük dinlenme kalp hızı (50–60 atım/dk civarı) genellikle iyi kardiyovasküler formu gösterir. 40 atım/dk altı veya 100 üstü dikkat gerektirebilir.",
        "kalp hızı değişkenliği": "Art arda gelen iki kalp atışı arasındaki zaman farkının değişkenliğidir. Yüksek kalp hızı değişkenliği genel olarak iyi sağlık ve stres yönetiminin göstergesidir.",
        "oksijen satürasyonu": "Kandaki hemoglobinin yüzde kaçının oksijenle dolu olduğunu gösterir. Normal değer %94–100 arasındadır. %90'ın altındaki değerler tıbbi müdahale gerektirebilir.",
        "vo2 max": "Maksimal oksijen tüketimidir; kardiyovasküler kondisyonun en önemli göstergelerinden biridir. Yüksek VO2 Max değeri daha iyi aerobik kapasiteyi gösterir.",
        "sistolik tansiyon": "Kalbin kasılırken damarlara uyguladığı basıncın üst değeridir. 120 mmHg altı normal, 130–139 mmHg yüksek-normal, 140 mmHg ve üzeri hipertansiyon olarak değerlendirilir.",
        "diastolik tansiyon": "Kalbin gevşerken damarlardaki basıncın alt değeridir. 80 mmHg altı normal, 80–89 mmHg yüksek-normal, 90 mmHg ve üzeri hipertansiyon sınırındadır.",
        // Apple Health — Vücut ölçüleri
        "kilo": "Vücut ağırlığıdır. BMI ile birlikte sağlıklı ağırlık aralığı değerlendirilir. Ani ve açıklanamayan kilo değişimleri takip gerektirebilir.",
        "bmi": "Beden Kitle İndeksi; kilo ve boydan hesaplanan, vücut yağ miktarının genel bir göstergesidir. 18.5–24.9 normal; 25–29.9 fazla kilolu; 30 ve üzeri obez olarak değerlendirilir.",
        "vücut yağ oranı": "Vücut ağırlığının yüzde kaçının yağdan oluştuğunu gösterir. Fazla vücut yağı kardiyovasküler hastalık ve diyabet riskini artırabilir.",
        "boy": "Vücut yüksekliğidir. BMI ve bel-boy oranı hesaplamalarında kullanılır.",
        "bel çevresi": "Karın bölgesindeki yağlanmayı gösteren önemli bir ölçümdür. Erkeklerde 102 cm, kadınlarda 88 cm üzeri metabolik risk taşıyabilir.",
        // Apple Health — Solunum
        "solunum hızı": "Dakikada kaç kez nefes alındığını gösterir. Normal dinlenme solunum hızı 12–20 soluk/dk'dır. Sürekli yüksek değerler solunum veya kalp sorunlarına işaret edebilir.",
        // Apple Health — Aktivite
        "adım sayısı": "Günde atılan adım sayısıdır. Dünya Sağlık Örgütü günde en az 8.000–10.000 adım önermektedir. Düzenli yürüyüş kardiyovasküler sağlığı destekler.",
        "aktif kalori": "Fiziksel aktivite sırasında yakılan kalori miktarıdır (bazal metabolizma hariç). Düzenli aktif kalori harcaması kilo yönetimi ve kardiyovasküler sağlık için önemlidir.",
        "egzersiz süresi": "Orta ve yüksek yoğunluklu fiziksel aktivite süresidir. WHO, haftada en az 150 dakika orta yoğunluklu aktivite önermektedir.",
        // Apple Health — Uyku
        "uyku süresi": "Gece boyunca gerçek uyku (hafif + derin + REM) süresidir. Yetişkinlere önerilen uyku süresi geceleri 7–9 saattir. Düzenli yetersiz uyku bağışıklık, bilişsel işlev ve kardiyovasküler sağlık üzerinde olumsuz etkiler yaratabilir.",
        // Apple Health — Beslenme
        "alınan kalori": "Gün içinde yiyeceklerden alınan toplam kalori miktarıdır. Kişinin yaşına, cinsiyetine ve aktivite düzeyine göre değişen enerji ihtiyacını karşılamak önemlidir.",
        "su tüketimi": "Gün içinde içilen su miktarıdır. Yetişkinlere genel olarak günde 2–2.5 litre su tüketimi önerilir; aktivite ve sıcaklığa göre bu miktar artabilir.",
    ]

    // MARK: - English

    private static let english: [String: String] = [
        // Complete blood count
        "eritrosit": "Red blood cell (RBC) count. Red blood cells carry oxygen from your lungs to all tissues in your body. A low count may indicate anemia; a high count may suggest polycythemia or dehydration.",
        "rbc": "Red blood cell count. Red blood cells carry oxygen from the lungs to the body's tissues. Low values may indicate anemia; high values may suggest dehydration or polycythemia.",
        "hemoglobin": "The iron-containing protein inside red blood cells that carries oxygen. It is the primary indicator of anemia. Low hemoglobin can cause fatigue, shortness of breath, and paleness.",
        "hgb": "Hemoglobin level. The oxygen-carrying protein in red blood cells. The main indicator of anemia.",
        "hematokrit": "The percentage of blood volume occupied by red blood cells. Used alongside hemoglobin to evaluate anemia and polycythemia.",
        "hct": "Hematocrit. The proportion of blood made up of red blood cells. An important parameter in diagnosing anemia.",
        "mcv": "Mean Corpuscular Volume — the average size of your red blood cells. Low MCV suggests iron-deficiency anemia; high MCV suggests vitamin B12 or folate deficiency.",
        "mch": "Mean Corpuscular Hemoglobin — the average amount of hemoglobin per red blood cell. Used together with MCV to classify anemia type.",
        "mchc": "Mean Corpuscular Hemoglobin Concentration — the average hemoglobin density per red blood cell. Used with MCV and MCH to classify anemia.",
        "rdw": "Red Cell Distribution Width — measures variation in red blood cell size. A high RDW is seen in iron-deficiency or B12-deficiency anemia.",
        "lökosit": "White blood cell (WBC) count. White blood cells are key immune-system cells. A high count may suggest infection or inflammation; a low count may indicate immune deficiency.",
        "wbc": "White blood cell count. Key immune-system cells. High values suggest infection or inflammation; low values suggest immune deficiency.",
        "nötrofil": "Neutrophils — the most common white blood cells; they form the first line of defense against bacterial infections. Low neutrophils (neutropenia) increase infection risk.",
        "lenfosit": "Lymphocytes — white blood cells that defend against viruses and tumor cells. High levels can indicate viral infection; low levels may suggest immune problems.",
        "monosit": "Monocytes — large white blood cells that become macrophages in tissues. Elevated levels may be associated with chronic infection or inflammation.",
        "eozinofil": "Eosinophils — white blood cells that increase in allergic reactions and parasitic infections.",
        "bazofil": "Basophils — the least common white blood cells; they play a role in allergic responses.",
        "trombosit": "Platelet count — tiny cells responsible for blood clotting. Low platelets increase bleeding risk; high platelets increase clot risk.",
        "plt": "Platelet count. Platelets are responsible for blood clotting. Low values increase bleeding risk; high values increase clot risk.",
        "mpv": "Mean Platelet Volume — the average size of platelets. High MPV may indicate more active platelets and is associated with cardiovascular risk.",
        "pdw": "Platelet Distribution Width — a measure of variation in platelet size.",
        // Liver
        "alt": "Alanine aminotransferase — a liver enzyme. Elevated ALT may indicate liver damage, hepatitis, or fatty liver disease.",
        "sgpt": "ALT (alanine aminotransferase). An important indicator of liver damage.",
        "ast": "Aspartate aminotransferase — found in liver, heart, and skeletal muscle. Elevated AST may indicate liver damage, heart attack, or muscle injury.",
        "sgot": "AST (aspartate aminotransferase). An indicator of liver and heart damage.",
        "ggt": "Gamma-glutamyl transferase — a liver enzyme sensitive to alcohol use and bile duct disease. Elevated levels suggest liver damage or bile duct obstruction.",
        "gamma gt": "GGT enzyme. Elevated in liver disease and with alcohol use.",
        "alp": "Alkaline phosphatase — found in liver, bone, and bile ducts. Elevated ALP can indicate bile duct obstruction, bone disease, or liver damage.",
        "total bilirubin": "A yellow pigment produced when hemoglobin breaks down. High bilirubin causes jaundice and may indicate liver disease or bile duct obstruction.",
        "direkt bilirubin": "Direct (conjugated) bilirubin — processed by the liver. Elevated levels suggest bile duct obstruction.",
        "indirekt bilirubin": "Indirect (unconjugated) bilirubin — not yet processed by the liver. High levels suggest excessive red blood cell breakdown.",
        "albumin": "The main protein made by the liver. Low albumin can indicate liver disease, poor nutrition, or kidney protein loss.",
        "total protein": "Total amount of proteins in blood. Used to assess liver function and nutritional status.",
        // Kidney
        "kreatinin": "A waste product of muscle metabolism filtered by the kidneys. High creatinine is an important sign of impaired kidney function.",
        "bun": "Blood urea nitrogen — a measure of protein metabolism waste. Used alongside creatinine to evaluate kidney function.",
        "üre": "Urea is a waste product of protein breakdown filtered by the kidneys. Elevated levels may indicate kidney failure or dehydration.",
        "ürik asit": "The end product of purine metabolism. High uric acid can cause gout and increases the risk of kidney stones.",
        "ürik asid": "The end product of purine metabolism. High uric acid can cause gout and increases the risk of kidney stones.",
        "uric acid": "The end product of purine metabolism. High uric acid can cause gout and increases the risk of kidney stones.",
        "egfr": "Estimated Glomerular Filtration Rate — measures how well the kidneys filter blood. Values below 60 mL/min/1.73m² indicate impaired kidney function.",
        // Thyroid
        "tsh": "Thyroid-stimulating hormone. High TSH suggests hypothyroidism (underactive thyroid); low TSH suggests hyperthyroidism (overactive thyroid).",
        "t3": "Triiodothyronine — a thyroid hormone that regulates metabolism.",
        "t4": "Thyroxine — the main thyroid hormone, converted to T3 in the body.",
        "serbest t3": "Free T3 (active, unbound triiodothyronine). A reliable indicator of thyroid function.",
        "ft3": "Free T3 — the active form of the thyroid hormone triiodothyronine.",
        "serbest t4": "Free T4 (active, unbound thyroxine). Used with TSH to diagnose thyroid disorders.",
        "ft4": "Free T4 — the active form of the thyroid hormone thyroxine.",
        "anti-tpo": "Anti-thyroid peroxidase antibody — an autoimmune antibody against the thyroid. Elevated levels suggest Hashimoto's thyroiditis or Graves' disease.",
        "anti-tg": "Anti-thyroglobulin antibody — an autoimmune antibody against thyroid tissue. Used with anti-TPO to diagnose autoimmune thyroid diseases.",
        // Lipid panel
        "total kolesterol": "Total cholesterol — the sum of all cholesterol types in blood. Should be interpreted together with LDL, HDL, and triglycerides for cardiovascular risk.",
        "ldl kolesterol": "LDL cholesterol — known as 'bad cholesterol'. It builds up in artery walls and can cause atherosclerosis.",
        "ldl": "LDL cholesterol — 'bad cholesterol'. High LDL increases the risk of heart disease and stroke.",
        "hdl kolesterol": "HDL cholesterol — known as 'good cholesterol'. It removes cholesterol from arteries. High HDL protects against cardiovascular disease.",
        "hdl": "HDL cholesterol — 'good cholesterol'. High HDL is protective for heart health.",
        "trigliserid": "A type of fat (lipid) found in blood. High triglycerides increase cardiovascular risk and can cause pancreatitis.",
        "vldl": "Very low-density lipoprotein — carries triglycerides in the blood. Elevated VLDL is a cardiovascular risk marker.",
        // Blood sugar
        "açlık kan şekeri": "Fasting blood glucose — measured after an 8-hour fast. 100–125 mg/dL suggests prediabetes; ≥126 mg/dL suggests diabetes.",
        "glikoz": "Blood glucose (sugar) level. Elevated levels may indicate diabetes or prediabetes.",
        "kan şekeri": "Blood glucose level. A key parameter in monitoring diabetes.",
        "hba1c": "Hemoglobin A1c — reflects average blood sugar control over the past 2–3 months. ≥6.5% suggests diabetes; 5.7–6.4% suggests prediabetes.",
        "hemoglobin a1c": "Reflects average blood sugar levels over the past 2–3 months. A critical parameter for diagnosing and monitoring diabetes.",
        "insülin": "Insulin — the hormone that regulates blood sugar. High insulin suggests insulin resistance; low insulin may indicate type 1 diabetes.",
        "açlık insülin": "Fasting insulin level. Used to calculate HOMA-IR. Elevated values suggest insulin resistance.",
        "homa-ir": "A calculated index of insulin resistance. Values above 2.5 are considered indicative of insulin resistance.",
        // Iron
        "serum demir": "Serum iron — the amount of free iron in blood. Should be interpreted with ferritin and TIBC.",
        "demir": "Iron level in blood. Low values may indicate iron-deficiency anemia.",
        "tibc": "Total Iron-Binding Capacity — how much iron the blood's transferrin can carry. High TIBC suggests iron deficiency; low TIBC may suggest chronic disease anemia.",
        "demir bağlama kapasitesi": "Iron-binding capacity of blood proteins. Increases in iron deficiency.",
        "ferritin": "A protein that stores iron in the body. Low ferritin indicates depleted iron stores; high ferritin may suggest chronic inflammation or iron overload.",
        "transferrin": "The protein that transports iron in the blood.",
        // Vitamins & minerals
        "b12": "Vitamin B12 is essential for the nervous system and red blood cell production. Deficiency can cause megaloblastic anemia and nerve damage.",
        "vitamin b12": "Essential for nerve function and blood cell production. Deficiency causes anemia and neurological problems.",
        "d vitamini": "Vitamin D is essential for bone health, immune function, and metabolic processes. Deficiency is common worldwide.",
        "25-oh vitamin d": "The active form of vitamin D in blood. Below 20 ng/mL is deficiency; 20–30 ng/mL is insufficiency.",
        "folik asit": "Folic acid (vitamin B9) is needed for cell division and red blood cell production. Especially important during pregnancy.",
        "b9": "Folic acid (vitamin B9). Required for cell division and DNA synthesis.",
        "çinko": "Zinc is essential for immune function and wound healing.",
        "magnezyum": "Magnesium is essential for bone health, muscle function, and nerve function.",
        // Electrolytes
        "sodyum": "Sodium is the main electrolyte in blood. It regulates fluid balance and blood pressure. High sodium suggests dehydration; low sodium may indicate kidney or hormonal problems.",
        "potasyum": "Potassium is critical for heart rhythm and muscle function. Imbalances can cause serious arrhythmias.",
        "kalsiyum": "Calcium is essential for bone and tooth health, muscle contraction, and nerve transmission.",
        "klor": "Chloride is an electrolyte that regulates fluid balance and acid-base balance.",
        "fosfor": "Phosphorus is a key component of bone structure. It can rise in kidney disease.",
        // Cardiovascular / inflammation
        "crp": "C-reactive protein — produced by the liver during infection or inflammation. Elevated CRP indicates infection or tissue damage.",
        "c reaktif protein": "Elevated in infection and inflammation. An indicator of acute inflammatory reactions.",
        "hscrp": "High-sensitivity CRP — measures low-level chronic inflammation. Used to predict cardiovascular disease risk.",
        "sedimantasyon": "Erythrocyte sedimentation rate (ESR) — a non-specific indicator of inflammation in the body.",
        "esr": "Erythrocyte sedimentation rate. A non-specific marker of inflammation.",
        "d-dimer": "A fibrin degradation product. Elevated D-dimer may indicate pulmonary embolism, deep vein thrombosis, or other clotting disorders.",
        "fibrinojen": "A clotting protein. Elevated fibrinogen may indicate cardiovascular risk or inflammation.",
        "homosistein": "High homocysteine increases the risk of cardiovascular disease, stroke, and dementia. Associated with B12, B6, and folate deficiency.",
        "troponin": "A protein specific to heart muscle damage. The gold standard for diagnosing a heart attack.",
        // Enzymes
        "ck": "Creatine kinase — found in heart, skeletal muscle, and brain. Elevated CK indicates heart attack or muscle damage.",
        "kreatin kinaz": "An indicator of heart and muscle damage.",
        "ldh": "Lactate dehydrogenase — a non-specific marker of tissue damage. Can be elevated in heart, liver, kidney, or blood diseases.",
        "amilaz": "Amylase — a digestive enzyme produced by the pancreas and salivary glands. Elevated amylase suggests pancreatitis.",
        "lipaz": "Lipase — a pancreas-specific fat-digesting enzyme. More specific than amylase for pancreatitis.",
        // Hormones
        "fsh": "Follicle-stimulating hormone. Regulates ovarian function in women and sperm production in men.",
        "lh": "Luteinizing hormone. Triggers ovulation in women and stimulates testosterone production in men.",
        "prolaktin": "Prolactin — a pituitary hormone that stimulates breast milk production. Elevated levels can cause menstrual irregularities and infertility.",
        "estradiol": "The most potent estrogen hormone. Important for reproductive function and bone density.",
        "e2": "Estradiol (E2). Used in menstrual cycle, menopause, and fertility evaluations.",
        "progesteron": "Progesterone — regulates the menstrual cycle and maintains pregnancy.",
        "testosteron": "Testosterone — an androgen hormone. Affects muscle mass, bone density, and libido.",
        "total testosteron": "Total testosterone in blood. Low values in men may indicate hypogonadism.",
        "kortizol": "Cortisol — the stress hormone. High cortisol suggests Cushing syndrome; low cortisol may suggest Addison's disease.",
        "dhea-s": "DHEA-sulfate — produced by the adrenal glands, a precursor to sex hormones. Decreases with age.",
        "dheas": "DHEA-S hormone value.",
        "acth": "Adrenocorticotropic hormone — stimulates the adrenal glands to produce cortisol.",
        "igf-1": "Insulin-like growth factor-1 — an indirect measure of growth hormone levels. Used to detect growth hormone deficiency or excess.",
        // Urinalysis
        "idrar dansitesi": "Urine specific gravity — reflects the kidneys' ability to concentrate urine.",
        "idrar ph": "Urine pH — indicates the acid-base balance of urine.",
        "idrar proteini": "Normally very little protein is found in urine. High protein (proteinuria) can be an early sign of kidney damage.",
        "idrar glukozu": "Glucose is not normally found in urine. Its presence may indicate high blood sugar.",
        // PSA
        "psa": "Prostate-specific antigen. Elevated PSA may indicate prostate cancer, benign prostatic hyperplasia, or prostatitis.",
        "total psa": "Total prostate-specific antigen.",
        // Tumor markers
        "cea": "Carcinoembryonic antigen — a tumor marker used in monitoring certain cancers, especially colorectal cancer.",
        "afp": "Alpha-fetoprotein — a tumor marker used in monitoring liver and testicular cancers.",
        "ca 125": "A tumor marker used in monitoring ovarian cancer.",
        "ca 19-9": "A tumor marker used in monitoring pancreatic and bile duct cancers.",
        // Apple Health — Cardiovascular
        "kalp atış hızı": "Heart rate — the number of times your heart beats per minute. A normal resting heart rate is 60–100 bpm. Consistently high or low values may signal heart rhythm problems.",
        "dinlenme kalp hızı": "Resting heart rate — measured when completely at rest. A lower resting heart rate (around 50–60 bpm) generally indicates better cardiovascular fitness.",
        "kalp hızı değişkenliği": "Heart rate variability (HRV) — the variation in time between consecutive heartbeats. Higher HRV is generally a sign of good health and stress resilience.",
        "oksijen satürasyonu": "Blood oxygen saturation — the percentage of hemoglobin carrying oxygen. Normal is 94–100%. Values below 90% may require medical attention.",
        "vo2 max": "Maximal oxygen uptake — a key measure of cardiovascular fitness. Higher VO2 Max indicates better aerobic capacity.",
        "sistolik tansiyon": "Systolic blood pressure — the pressure in your arteries when your heart beats. Below 120 mmHg is normal; 130–139 is elevated; 140+ is hypertension.",
        "diastolik tansiyon": "Diastolic blood pressure — the pressure in your arteries between heartbeats. Below 80 mmHg is normal; 90+ is in the hypertension range.",
        // Apple Health — Body measurements
        "kilo": "Body weight. Changes in weight are tracked alongside BMI for overall health assessment.",
        "bmi": "Body Mass Index — calculated from height and weight as a general indicator of body fat. 18.5–24.9 is normal; 25–29.9 is overweight; 30+ is obese.",
        "vücut yağ oranı": "Body fat percentage — what proportion of your body weight is fat. Excess body fat increases the risk of cardiovascular disease and diabetes.",
        "boy": "Height. Used in BMI and waist-to-height ratio calculations.",
        "bel çevresi": "Waist circumference — measures abdominal fat. Above 102 cm in men and 88 cm in women may indicate metabolic risk.",
        // Apple Health — Sleep
        "uyku süresi": "Sleep duration — total time spent in actual sleep (light + deep + REM). Adults need 7–9 hours per night. Regular sleep deprivation can negatively affect immunity, cognitive function, and cardiovascular health.",
        // Apple Health — Activity
        "adım sayısı": "Step count — number of steps taken per day. The WHO recommends at least 8,000–10,000 steps daily for health benefits.",
        "aktif kalori": "Active calories burned — calories burned through physical activity beyond your base metabolic rate.",
        "egzersiz süresi": "Exercise time — duration of moderate to vigorous physical activity. The WHO recommends at least 150 minutes of moderate activity per week.",
        // Apple Health — Nutrition
        "alınan kalori": "Dietary energy — total calories consumed from food. Meeting your daily energy needs depends on age, sex, and activity level.",
        "su tüketimi": "Water intake. Adults are generally advised to drink 2–2.5 liters of water per day; more in hot weather or during exercise.",
        // Apple Health — Respiratory
        "solunum hızı": "Respiratory rate — number of breaths per minute. Normal at rest is 12–20 breaths/min. Persistently elevated values may indicate respiratory or cardiac problems.",
    ]

    // MARK: - German

    private static let german: [String: String] = [
        "eritrosit": "Erythrozytenzahl (rote Blutkörperchen). Sie transportieren Sauerstoff von der Lunge zu allen Geweben. Ein niedriger Wert kann auf Anämie hinweisen; ein hoher Wert auf Polyzythämie oder Dehydration.",
        "rbc": "Erythrozytenzahl. Sauerstofftransportierende rote Blutkörperchen. Niedrig: mögliche Anämie; hoch: mögliche Polyzythämie.",
        "hemoglobin": "Das sauerstofftransportierende Eisenprotein in den roten Blutkörperchen. Der wichtigste Indikator für Anämie.",
        "hgb": "Hämoglobinwert. Das Sauerstofftransportprotein der roten Blutkörperchen.",
        "hematokrit": "Der prozentuale Anteil der roten Blutkörperchen am Blutvolumen. Wird zusammen mit Hämoglobin zur Beurteilung von Anämie verwendet.",
        "hct": "Hämatokrit. Anteil der roten Blutkörperchen im Blut.",
        "mcv": "Mittleres korpuskuläres Volumen — die durchschnittliche Größe der roten Blutkörperchen. Niedrig: Eisenmangelanämie; hoch: B12- oder Folsäuremangel.",
        "wbc": "Leukozytenzahl (weiße Blutkörperchen). Zellen des Immunsystems. Erhöht bei Infektion; erniedrigt bei Immunschwäche.",
        "lökosit": "Leukozytenzahl. Zellen des Immunsystems. Erhöht bei Infektion oder Entzündung; erniedrigt bei Immunschwäche.",
        "trombosit": "Thrombozytenzahl (Blutplättchen). Verantwortlich für die Blutgerinnung. Niedrig: erhöhtes Blutungsrisiko; hoch: erhöhtes Thromboserisiko.",
        "plt": "Thrombozytenzahl. Blutplättchen für die Gerinnung. Niedrig: Blutungsrisiko; hoch: Thromboserisiko.",
        "alt": "Alaninaminotransferase — ein Leberenzym. Erhöhte ALT kann auf Leberschäden, Hepatitis oder Fettleber hinweisen.",
        "ast": "Aspartataminotransferase — in Leber, Herz und Skelettmuskel. Erhöhte AST kann Leberschaden, Herzinfarkt oder Muskelschaden anzeigen.",
        "tsh": "Thyreoidea-stimulierendes Hormon. Hohe TSH weist auf Hypothyreose hin; niedrige TSH auf Hyperthyreose.",
        "kreatinin": "Abfallprodukt des Muskelstoffwechsels, das von den Nieren ausgeschieden wird. Erhöhtes Kreatinin ist ein wichtiger Hinweis auf Nierenfunktionsstörungen.",
        "ldl": "LDL-Cholesterin — das 'schlechte Cholesterin'. Hohe Werte erhöhen das Herzerkrankungsrisiko.",
        "hdl": "HDL-Cholesterin — das 'gute Cholesterin'. Schützt die Herzgesundheit.",
        "ferritin": "Eisenspeicherprotein. Niedriges Ferritin zeigt erschöpfte Eisenspeicher an; hohes Ferritin kann chronische Entzündung oder Eisenüberladung anzeigen.",
        "crp": "C-reaktives Protein — wird bei Infektion oder Entzündung von der Leber produziert. Erhöhte CRP zeigt Entzündung oder Gewebeschaden an.",
        "hba1c": "Hämoglobin A1c — spiegelt die durchschnittliche Blutzuckerkontrolle der letzten 2–3 Monate wider.",
        "d vitamini": "Vitamin D ist für Knochengesundheit, Immunfunktion und viele Stoffwechselprozesse unerlässlich.",
    ]

    // MARK: - French

    private static let french: [String: String] = [
        "eritrosit": "Numération des globules rouges (GR). Ils transportent l'oxygène des poumons vers tous les tissus. Un nombre bas peut indiquer une anémie ; un nombre élevé peut signaler une polycythémie ou une déshydratation.",
        "rbc": "Numération des globules rouges. Ils transportent l'oxygène. Un taux bas indique une possible anémie.",
        "hemoglobin": "La protéine ferreuse transporteuse d'oxygène dans les globules rouges. Principal indicateur de l'anémie.",
        "hgb": "Taux d'hémoglobine. Principal indicateur de l'anémie.",
        "hematokrit": "Le pourcentage du volume sanguin occupé par les globules rouges. Évalué avec l'hémoglobine pour diagnostiquer l'anémie.",
        "hct": "Hématocrite. Proportion des globules rouges dans le sang.",
        "wbc": "Numération des globules blancs. Cellules du système immunitaire. Élevé en cas d'infection ; bas en cas d'immunodéficience.",
        "lökosit": "Numération leucocytaire. Cellules du système immunitaire. Elevé lors d'infection ou inflammation ; bas en cas d'immunodéficience.",
        "trombosit": "Numération plaquettaire. Responsables de la coagulation. Faible : risque de saignement ; élevé : risque de thrombose.",
        "plt": "Numération plaquettaire. Plaquettes pour la coagulation.",
        "alt": "Alanine aminotransférase — enzyme hépatique. Une ALT élevée peut indiquer des lésions hépatiques, une hépatite ou une stéatose.",
        "tsh": "Hormone thyréotrope. Une TSH élevée indique une hypothyroïdie ; une TSH basse indique une hyperthyroïdie.",
        "kreatinin": "Déchet du métabolisme musculaire filtré par les reins. Une créatinine élevée indique une insuffisance rénale.",
        "ldl": "Cholestérol LDL — le 'mauvais cholestérol'. Des niveaux élevés augmentent le risque de maladies cardiovasculaires.",
        "hdl": "Cholestérol HDL — le 'bon cholestérol'. Protège contre les maladies cardiovasculaires.",
        "ferritin": "Protéine de stockage du fer. Un ferritine bas signale des réserves de fer épuisées.",
        "crp": "Protéine C-réactive — produite lors d'infections ou inflammations. Une CRP élevée indique une inflammation.",
        "hba1c": "Hémoglobine A1c — reflète le contrôle moyen de la glycémie sur 2–3 mois.",
        "d vitamini": "La vitamine D est essentielle pour la santé osseuse et le système immunitaire.",
    ]

    // MARK: - Spanish

    private static let spanish: [String: String] = [
        "eritrosit": "Conteo de glóbulos rojos (eritrocitos). Transportan oxígeno desde los pulmones a todos los tejidos. Un conteo bajo puede indicar anemia; uno alto puede sugerir policitemia o deshidratación.",
        "rbc": "Conteo de glóbulos rojos. Transportan oxígeno. Un valor bajo puede indicar anemia.",
        "hemoglobin": "La proteína que contiene hierro en los glóbulos rojos y transporta oxígeno. Indicador principal de anemia.",
        "hgb": "Nivel de hemoglobina. Principal indicador de anemia.",
        "hematokrit": "El porcentaje del volumen sanguíneo ocupado por los glóbulos rojos. Evaluado junto con la hemoglobina para diagnosticar anemia.",
        "hct": "Hematocrito. Proporción de glóbulos rojos en la sangre.",
        "wbc": "Conteo de glóbulos blancos. Células del sistema inmunitario. Elevado en infección; bajo en inmunodeficiencia.",
        "lökosit": "Recuento leucocitario. Células del sistema inmunitario. Elevado en infección o inflamación; bajo en inmunodeficiencia.",
        "trombosit": "Recuento de plaquetas. Responsables de la coagulación. Bajo: riesgo de sangrado; alto: riesgo de trombosis.",
        "plt": "Recuento plaquetario. Plaquetas para la coagulación.",
        "alt": "Alanina aminotransferasa — enzima hepática. ALT elevada puede indicar daño hepático, hepatitis o hígado graso.",
        "tsh": "Hormona estimulante de la tiroides. TSH alta indica hipotiroidismo; TSH baja indica hipertiroidismo.",
        "kreatinin": "Producto de desecho del metabolismo muscular filtrado por los riñones. Creatinina elevada indica disfunción renal.",
        "ldl": "Colesterol LDL — el 'colesterol malo'. Niveles altos aumentan el riesgo de enfermedades cardíacas.",
        "hdl": "Colesterol HDL — el 'colesterol bueno'. Protege contra enfermedades cardiovasculares.",
        "ferritin": "Proteína de almacenamiento de hierro. Ferritina baja indica reservas de hierro agotadas.",
        "crp": "Proteína C reactiva — producida durante infecciones o inflamaciones. CRP elevada indica inflamación.",
        "hba1c": "Hemoglobina A1c — refleja el control promedio del azúcar en sangre durante 2–3 meses.",
        "d vitamini": "La vitamina D es esencial para la salud ósea y la función inmunitaria.",
    ]

    // MARK: - Arabic

    private static let arabic: [String: String] = [
        "eritrosit": "عدد خلايا الدم الحمراء (كريات الدم الحمراء). تنقل الأكسجين من الرئتين إلى جميع أنسجة الجسم. انخفاض العدد قد يشير إلى فقر الدم؛ ارتفاعه قد يشير إلى احمرار الدم أو الجفاف.",
        "rbc": "عدد خلايا الدم الحمراء. تنقل الأكسجين. انخفاض القيمة قد يدل على فقر الدم.",
        "hemoglobin": "البروتين الحاوي على الحديد في خلايا الدم الحمراء الذي ينقل الأكسجين. المؤشر الرئيسي لفقر الدم.",
        "hgb": "مستوى الهيموغلوبين. المؤشر الرئيسي لفقر الدم.",
        "wbc": "عدد خلايا الدم البيضاء. خلايا الجهاز المناعي. ارتفاعه يشير للعدوى؛ انخفاضه يشير لضعف المناعة.",
        "lökosit": "عدد الكريات البيض. ارتفاعه يشير للعدوى أو الالتهاب؛ انخفاضه يشير لضعف المناعة.",
        "trombosit": "عدد الصفائح الدموية. مسؤولة عن تخثر الدم. انخفاضها يزيد خطر النزيف؛ ارتفاعها يزيد خطر الجلطة.",
        "alt": "ناقلة أمين الألانين — إنزيم الكبد. ارتفاعه يدل على تلف الكبد أو التهاب الكبد.",
        "tsh": "هرمون تحفيز الغدة الدرقية. ارتفاعه يدل على قصور الغدة الدرقية؛ انخفاضه يدل على فرط نشاطها.",
        "kreatinin": "نفاية من استقلاب العضلات تفرزها الكلى. ارتفاع الكرياتينين يدل على قصور وظائف الكلى.",
        "ldl": "كوليسترول البروتين الدهني منخفض الكثافة — 'الكوليسترول الضار'. ارتفاعه يزيد خطر أمراض القلب.",
        "hdl": "كوليسترول البروتين الدهني عالي الكثافة — 'الكوليسترول الجيد'. ارتفاعه يحمي صحة القلب.",
        "ferritin": "بروتين تخزين الحديد. انخفاض الفيريتين يشير لنضوب مخازن الحديد.",
        "crp": "بروتين سي التفاعلي — يُنتج عند الإصابة بعدوى أو التهاب. ارتفاعه يدل على وجود التهاب.",
        "hba1c": "الهيموغلوبين السكري (HbA1c) — يعكس متوسط التحكم في نسبة السكر في الدم خلال 2-3 أشهر.",
        "d vitamini": "فيتامين د ضروري لصحة العظام ووظيفة الجهاز المناعي.",
    ]

    // MARK: - Russian

    private static let russian: [String: String] = [
        "eritrosit": "Количество эритроцитов (красных кровяных телец). Они переносят кислород из лёгких ко всем тканям. Низкое значение может указывать на анемию; высокое — на полицитемию или обезвоживание.",
        "rbc": "Количество эритроцитов. Переносчики кислорода. Низкое значение — возможная анемия.",
        "hemoglobin": "Железосодержащий белок в эритроцитах, переносящий кислород. Основной показатель анемии.",
        "hgb": "Уровень гемоглобина. Главный показатель анемии.",
        "wbc": "Количество лейкоцитов. Клетки иммунной системы. Повышен при инфекции; снижен при иммунодефиците.",
        "lökosit": "Количество лейкоцитов. Повышен при инфекции или воспалении; снижен при иммунодефиците.",
        "trombosit": "Количество тромбоцитов. Отвечают за свёртываемость крови. Низкое — риск кровотечения; высокое — риск тромбоза.",
        "alt": "Аланинаминотрансфераза — фермент печени. Повышенная АЛТ указывает на повреждение печени или гепатит.",
        "tsh": "Тиреотропный гормон. Высокий ТТГ — гипотиреоз; низкий — гипертиреоз.",
        "kreatinin": "Продукт распада мышц, фильтруемый почками. Повышенный креатинин указывает на нарушение функции почек.",
        "ldl": "ЛПНП-холестерин — 'плохой холестерин'. Высокие значения увеличивают риск сердечных заболеваний.",
        "hdl": "ЛПВП-холестерин — 'хороший холестерин'. Защищает сердце.",
        "ferritin": "Белок хранения железа. Низкий ферритин означает истощение запасов железа.",
        "crp": "С-реактивный белок — вырабатывается при инфекции или воспалении. Высокий CRP указывает на воспаление.",
        "hba1c": "Гликированный гемоглобин — отражает средний уровень сахара в крови за 2–3 месяца.",
        "d vitamini": "Витамин D необходим для здоровья костей и иммунной функции.",
    ]
}
