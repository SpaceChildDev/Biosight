import Foundation

/// PDF'den çıkarılan ham metin → yapılandırılmış tahlil değerleri.
/// Tamamen cihaz üzerinde çalışır, hiçbir veri dışarıya gönderilmez.
struct LabValueParser {

    struct ParsedValue: Identifiable {
        var id = UUID()
        var valueName: String
        var value: String
        var unit: String
        var referenceRange: String
        var isAbnormal: Bool
        var category: String
        var type: String
    }

    static func parse(from text: String) -> [ParsedValue] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 4 }

        var results: [ParsedValue] = []
        for line in lines {
            if let parsed = parseLine(line) {
                results.append(parsed)
            }
        }
        return deduplicate(results)
    }

    // MARK: - Line Parsing

    private static func parseLine(_ line: String) -> ParsedValue? {
        // Skip header / metadata lines
        let lower = line.lowercased(with: Locale(identifier: "tr_TR"))
        let skipPrefixes = ["test adı", "sonuç", "birim", "referans aralığı",
                            "parameter", "result", "unit", "reference range",
                            "hasta:", "doktor:", "barkod:", "rapor no",
                            "not:", "imza", "onay", "tarih:", "adı soyadı"]
        if skipPrefixes.contains(where: { lower.hasPrefix($0) }) { return nil }

        // Must contain a known unit
        guard let (unit, unitRange) = findUnit(in: line) else { return nil }

        let beforeUnit = String(line[..<unitRange.lowerBound]).trimmingCharacters(in: .whitespaces)
        let afterUnit  = String(line[unitRange.upperBound...]).trimmingCharacters(in: .whitespaces)

        // Last number before the unit = result value
        guard let (rawValue, valueRange) = findLastNumber(in: beforeUnit),
              let numericValue = Double(rawValue.replacingOccurrences(of: ",", with: "."))
        else { return nil }

        // Sanity check (avoid matching years, page numbers, etc.)
        if numericValue > 100_000 || numericValue < 0 { return nil }

        // Name = everything before the value
        var name = String(beforeUnit[..<valueRange.lowerBound])
            .trimmingCharacters(in: .whitespaces)
        name = cleanName(name)
        guard name.count >= 2 else { return nil }

        // Reference range
        let refRange = findReferenceRange(in: afterUnit)
                    ?? findReferenceRange(in: line)  // fallback: search whole line

        // Abnormal
        let isAbnormal = determineAbnormal(
            value: numericValue,
            refRange: refRange,
            statusText: afterUnit
        )

        return ParsedValue(
            valueName: name,
            value: rawValue.replacingOccurrences(of: ",", with: "."),
            unit: unit,
            referenceRange: refRange ?? "",
            isAbnormal: isAbnormal,
            category: mapToCategory(name),
            type: detectType(in: line)
        )
    }

    // MARK: - Unit Detection
    // Ordered longest → shortest to avoid partial matches
    private static let knownUnits: [String] = [
        "10^3/µL","10^3/uL","10^6/µL","10^6/uL","10³/µL","10⁶/µL",
        "mIU/mL","mIU/L","kIU/L","IU/mL","IU/L",
        "µmol/L","nmol/L","pmol/L","mmol/L",
        "µg/dL","µg/mL","µg/L","ug/dL","ug/mL",
        "ng/mL","ng/dL","ng/L",
        "pg/mL","pg/dL",
        "mg/dL","mg/L",
        "g/dL","g/L",
        "mEq/L","meq/L",
        "U/L","U/l",
        "mm/sa","mm/h",
        "K/µL","K/uL",
        "M/µL","M/uL",
        "/µL","/uL",
        "fL","fl",
        "INR","sn","%",
    ]

    private static func findUnit(in line: String) -> (String, Range<String.Index>)? {
        for unit in knownUnits {
            guard let range = line.range(of: unit, options: .caseInsensitive) else { continue }
            // Ensure it's not inside a longer token (e.g., "mEq/L" shouldn't match inside "mmEq/L")
            let charBefore: Character? = range.lowerBound > line.startIndex
                ? line[line.index(before: range.lowerBound)] : nil
            if let c = charBefore, c.isLetter || c.isNumber { continue }
            return (unit, range)
        }
        return nil
    }

    // MARK: - Number Extraction

    private static func findLastNumber(in text: String) -> (String, Range<String.Index>)? {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+[,.]?\d*)"#) else { return nil }
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        guard let last = matches.last,
              let range = Range(last.range(at: 1), in: text) else { return nil }
        return (String(text[range]), range)
    }

    // MARK: - Reference Range

    private static func findReferenceRange(in text: String) -> String? {
        // "70-100", "13.5 - 17.5", "13,5-17,5"
        let rangePattern = #"(\d+[,.]?\d*)\s*[-–]\s*(\d+[,.]?\d*)"#
        if let regex = try? NSRegularExpression(pattern: rangePattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let r1 = Range(match.range(at: 1), in: text),
           let r2 = Range(match.range(at: 2), in: text) {
            let low  = String(text[r1]).replacingOccurrences(of: ",", with: ".")
            let high = String(text[r2]).replacingOccurrences(of: ",", with: ".")
            // Sanity: both must be plausible numbers and low < high
            if let lo = Double(low), let hi = Double(high), lo < hi {
                return "\(low)-\(high)"
            }
        }
        // "< 5.0" or "> 3.5"
        if let regex = try? NSRegularExpression(pattern: #"[<>]\s*\d+[,.]?\d*"#),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let r = Range(match.range, in: text) {
            return String(text[r]).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    // MARK: - Abnormal Detection

    private static func determineAbnormal(value: Double, refRange: String?, statusText: String) -> Bool {
        let upper = statusText.uppercased()
        if ["NORMAL","NEGATİF","NEGATIVE"].contains(where: { upper.contains($0) }) { return false }
        if ["YÜKSEK","DÜŞÜK","HIGH","LOW"," H "," L ","!!","↑","↓","ANORMAL"].contains(where: { upper.contains($0) }) {
            return true
        }
        guard let ref = refRange else { return false }
        let parts = ref.components(separatedBy: "-")
        if parts.count == 2,
           let lo = Double(parts[0]), let hi = Double(parts[1]) {
            return value < lo || value > hi
        }
        if ref.hasPrefix("<"), let lim = Double(ref.dropFirst().trimmingCharacters(in: .whitespaces)) {
            return value >= lim
        }
        if ref.hasPrefix(">"), let lim = Double(ref.dropFirst().trimmingCharacters(in: .whitespaces)) {
            return value <= lim
        }
        return false
    }

    // MARK: - Name Cleanup

    private static func cleanName(_ raw: String) -> String {
        var name = raw
        // Remove leading line numbers like "1.", "12 "
        if let regex = try? NSRegularExpression(pattern: #"^\d+[.\s]\s*"#) {
            name = regex.stringByReplacingMatches(
                in: name, range: NSRange(name.startIndex..., in: name), withTemplate: "")
        }
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: ":-•*|_.").union(.whitespaces))
        // Collapse multiple spaces
        if let regex = try? NSRegularExpression(pattern: #"\s+"#) {
            name = regex.stringByReplacingMatches(
                in: name, range: NSRange(name.startIndex..., in: name), withTemplate: " ")
        }
        // If ALL_CAPS, convert to Title Case
        if name == name.uppercased() && name.count > 2 {
            name = name.capitalized(with: Locale(identifier: "tr_TR"))
        }
        return name
    }

    // MARK: - Category Mapping

    private static func mapToCategory(_ name: String) -> String {
        let lower = name.lowercased(with: Locale(identifier: "tr_TR"))

        let map: [(keys: [String], cat: String)] = [
            (["hemoglobin","hgb"," hb ","hematokrit","hct","eritrosit","rbc",
              "lökosit","wbc","trombosit","plt","mcv","mch","mchc","rdw","mpv",
              "nötrofil","lenfosit","monosit","eozinofil","bazofil","retikülosit",
              "inr","pt ","ptt","aptt","fibrinojen","d-dimer"], "Hemogram"),

            (["alt","sgpt","ast","sgot","alp","alkalen","ggt","gamma",
              "ldh","bilirubin","total protein","albumin","globulin"], "Karaciğer"),

            (["kreatinin","creatinin","üre","urea","bun","ürik asit","uric acid",
              "gfr","egfr","sistein"], "Böbrek"),

            (["tsh","ft3","ft4","serbest t3","serbest t4","anti-tpo",
              "anti-tg","tiroglobulin"], "Tiroid"),

            (["kolesterol","cholesterol","hdl","ldl","trigliserit",
              "triglycerid","vldl","apolipoprotein"], "Lipid"),

            (["glukoz","glucose","hba1c","insülin","insulin","c-peptit",
              "demir"," fe ","ferritin","transferrin","tibc"], "Kan Değerleri"),

            (["b12","folik","folat","d vitamini","25-oh","vitamin d",
              "vitamin b","vitamin c","vitamin e","vitamin k"], "Vitamin"),

            (["kortizol","testosteron","östradiol","estradiol","prolaktin",
              "fsh","lh","dhea","progesteron","androstenedion","shbg","igf"], "Hormon"),

            (["crp","c reaktif","troponin","ck-mb","bnp","nt-pro",
              "homosistein","sedimentasyon","esr"], "Kardiyovasküler"),

            (["idrar","protein/kreatinin","mikroalbumin"], "İdrar"),
        ]

        for (keys, cat) in map {
            if keys.contains(where: { lower.contains($0) }) { return cat }
        }
        return "Diğer"
    }

    // MARK: - Type Detection

    private static func detectType(in line: String) -> String {
        let lower = line.lowercased(with: Locale(identifier: "tr_TR"))
        if lower.contains("idrar") || lower.contains("urine") { return "İdrar" }
        return "Kan"
    }

    // MARK: - Deduplication

    private static func deduplicate(_ values: [ParsedValue]) -> [ParsedValue] {
        var seen = Set<String>()
        return values.filter { v in
            let key = "\(v.valueName.lowercased())_\(v.value)"
            return seen.insert(key).inserted
        }
    }
}
