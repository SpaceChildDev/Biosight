import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("easyMode") private var easyMode = false
    @AppStorage("activePersonID") private var activePersonID: String = ""

    @State private var selectedMode: Bool? = nil
    @State private var currentPage = 0

    // Profile fields
    @State private var usageType: UsageType? = nil
    @State private var profileName = ""
    @State private var birthDay = ""
    @State private var birthMonth = ""
    @State private var birthYear = ""
    @State private var gender: String? = nil
    @State private var heightCm = ""
    @State private var weightKg = ""
    @State private var avatarIcon = "hi-man"

    @FocusState private var birthFocus: BirthField?

    enum BirthField {
        case day, month, year
    }

    private let totalPages = 8

    enum UsageType: String, CaseIterable {
        case myself = "Kendim için"
        case family = "Aile yakınım için"
        case other = "Başka biri için"

        var icon: String {
            switch self {
            case .myself: return "person.fill"
            case .family: return "person.2.fill"
            case .other: return "person.badge.plus"
            }
        }
    }

    private var parsedBirthDate: Date? {
        guard let day = Int(birthDay), let month = Int(birthMonth), let year = Int(birthYear),
              day >= 1, day <= 31, month >= 1, month <= 12, year >= 1900, year <= Calendar.current.component(.year, from: .now)
        else { return nil }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        return Calendar.current.date(from: components)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pages
            Group {
                switch currentPage {
                case 0: welcomePage
                case 1: usageTypePage
                case 2: namePage
                case 3: birthDatePage
                case 4: genderPage
                case 5: bodyMeasurementsPage
                case 6: modeSelectionPage
                case 7: previewPage
                default: EmptyView()
                }
            }
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
            .animation(.easeInOut(duration: 0.35), value: currentPage)

            // Page indicators + button
            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach(0..<totalPages, id: \.self) { i in
                        Capsule()
                            .fill(i == currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                            .frame(width: i == currentPage ? 20 : 8, height: 8)
                            .animation(.easeInOut(duration: 0.2), value: currentPage)
                    }
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        if currentPage < totalPages - 1 {
                            currentPage += 1
                        } else {
                            completeOnboarding()
                        }
                    }
                } label: {
                    Text(currentPage == totalPages - 1 ? "Başla" : "Devam")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(buttonDisabled ? Color.gray : Color.accentColor)
                        )
                }
                .disabled(buttonDisabled)
                .padding(.horizontal, 32)

                if currentPage > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            currentPage -= 1
                        }
                    } label: {
                        Text("Geri")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }

    private var buttonDisabled: Bool {
        switch currentPage {
        case 1: return usageType == nil
        case 2: return profileName.trimmingCharacters(in: .whitespaces).isEmpty
        case 6: return selectedMode == nil
        default: return false
        }
    }

    private func completeOnboarding() {
        let person = Person(
            name: profileName.trimmingCharacters(in: .whitespaces),
            birthDate: parsedBirthDate,
            gender: gender,
            avatarEmoji: avatarIcon,
            height: Double(heightCm),
            weight: Double(weightKg)
        )
        modelContext.insert(person)
        activePersonID = person.id.uuidString
        easyMode = selectedMode ?? false
        hasCompletedOnboarding = true
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image("hi-stethoscope")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.linearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Biosight'a Hoş Geldin")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Tahlil sonuçlarınızı tarayın, kaydedin ve zaman içindeki değişimlerini kolayca takip edin.")
                .font(.title3)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                Text("Bu uygulama tıbbi teşhis veya tedavi amaçlı değildir. Tahlil değerlerinizi kayıt altına alır ve değişimlerini takip etmenizi kolaylaştırır.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.orange.opacity(0.08))
            )
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: Usage Type

    private var usageTypePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Kimin için kullanacaksınız?")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("Daha sonra birden fazla profil ekleyebilirsiniz.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                ForEach(UsageType.allCases, id: \.rawValue) { type in
                    Button {
                        usageType = type
                        if type == .myself {
                            profileName = ""
                        }
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: type.icon)
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(usageType == type ? Color.accentColor : Color.gray)
                                .cornerRadius(12)

                            Text(type.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: usageType == type ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(usageType == type ? .accentColor : .gray.opacity(0.3))
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(usageType == type ? Color.accentColor : .clear, lineWidth: 2)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 3: Name

    private var namePage: some View {
        VStack(spacing: 24) {
            Spacer()

            ProfileIconView(iconName: avatarIcon, size: 80)
                .foregroundColor(.accentColor)

            Text(usageType == .myself ? "Adınız nedir?" : "Kişinin adı nedir?")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            TextField(usageType == .myself ? "Adınız" : "Kişinin adı", text: $profileName)
                .font(.title3)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
                .padding(.horizontal, 32)
                .submitLabel(.done)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 4: Birth Date

    private var birthDatePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Doğum Tarihi")
                .font(.title.bold())

            Text("Opsiyonel — daha sonra da girebilirsiniz.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("Gün")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("01", text: $birthDay)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .frame(width: 70)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .focused($birthFocus, equals: .day)
                        .onChange(of: birthDay) { _, newValue in
                            if newValue.count >= 2 {
                                birthDay = String(newValue.prefix(2))
                                birthFocus = .month
                            }
                        }
                }

                VStack(spacing: 4) {
                    Text("Ay")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("06", text: $birthMonth)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .frame(width: 70)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .focused($birthFocus, equals: .month)
                        .onChange(of: birthMonth) { _, newValue in
                            if newValue.count >= 2 {
                                birthMonth = String(newValue.prefix(2))
                                birthFocus = .year
                            }
                        }
                }

                VStack(spacing: 4) {
                    Text("Yıl")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("1990", text: $birthYear)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .frame(width: 90)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .focused($birthFocus, equals: .year)
                        .onChange(of: birthYear) { _, newValue in
                            if newValue.count >= 4 {
                                birthYear = String(newValue.prefix(4))
                                birthFocus = nil
                            }
                        }
                }
            }

            if let date = parsedBirthDate {
                Text(date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.green)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 5: Gender

    private var genderPage: some View {
        VStack(spacing: 24) {
            Spacer()

            ProfileIconView(iconName: avatarIcon, size: 80)
                .foregroundColor(.accentColor)

            Text("Cinsiyet")
                .font(.title.bold())

            Text("Profil ikonunuz cinsiyete göre ayarlanır.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                genderCard("Erkek", value: "Erkek", icon: "hi-man")
                genderCard("Kadın", value: "Kadın", icon: "hi-woman")
                genderCard("Belirtmek İstemiyorum", value: "Diğer", icon: "hi-man")
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    private func genderCard(_ title: String, value: String, icon: String) -> some View {
        Button {
            gender = value
            updateAvatarForSelection()
        } label: {
            HStack(spacing: 16) {
                ProfileIconView(iconName: icon, size: 36)
                    .foregroundColor(gender == value ? .white : .primary)

                Text(title)
                    .font(.headline)
                    .foregroundColor(gender == value ? .white : .primary)

                Spacer()

                if gender == value {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(gender == value ? Color.accentColor : Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 6: Body Measurements

    private var bodyMeasurementsPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "ruler.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Boy ve Kilo")
                .font(.title.bold())

            Text("Opsiyonel — daha sonra da girebilirsiniz.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("Boy (cm)")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    TextField("175", text: $heightCm)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                }

                VStack(spacing: 6) {
                    Text("Kilo (kg)")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)
                    TextField("70", text: $weightKg)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.title2)
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                }
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 7: Mode Selection

    private var modeSelectionPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Nasıl kullanmak istersiniz?")
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text("İstediğiniz zaman ayarlardan değiştirebilirsiniz.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                // Kolay Mod — önerilen, daha büyük
                Button {
                    selectedMode = true
                } label: {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            Text("Önerilen")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                        .padding(.bottom, 8)

                        HStack(spacing: 16) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .frame(width: 64, height: 64)
                                .background(Color.green)
                                .cornerRadius(16)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kolay Mod")
                                    .font(.title3.bold())
                                    .foregroundColor(.primary)
                                Text("Büyük butonlar, sade ekran.\nHerkes için kolay kullanım.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Image(systemName: selectedMode == true ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundColor(selectedMode == true ? .green : .gray.opacity(0.3))
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(selectedMode == true ? Color.green : .clear, lineWidth: 2.5)
                            )
                    )
                }
                .buttonStyle(.plain)

                // Standart Mod — daha küçük
                modeCard(
                    title: "Standart Mod",
                    description: "Tüm özellikler ve detaylı ayarlar.",
                    icon: "slider.horizontal.3",
                    color: .blue,
                    isSelected: selectedMode == false
                ) {
                    selectedMode = false
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 8: Preview

    private var previewPage: some View {
        VStack(spacing: 24) {
            Spacer()

            ProfileIconView(iconName: avatarIcon, size: 80)
                .foregroundColor(.accentColor)

            Text("Hazırsın, \(profileName)!")
                .font(.title.bold())

            Text("İlk adım: bir tahlil belgesi tarayın veya yükleyin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Tek eylem — tahlil tara
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .cornerRadius(14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tahlil Tara")
                            .font(.title3.bold())
                        Text("Kamera ile tahlil belgenizi tarayın")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )

                HStack(spacing: 16) {
                    Image(systemName: "doc.badge.plus")
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.orange)
                        .cornerRadius(14)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tahlil Yükle")
                            .font(.title3.bold())
                        Text("Tahlil belgenizi seçin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            .padding(.horizontal, 32)

            Text("Ayarlardan istediğiniz zaman değiştirebilirsiniz.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
    }

    // MARK: - Avatar Logic

    private func updateAvatarForSelection() {
        let age: Int?
        if let year = Int(birthYear), year > 1900 {
            age = Calendar.current.component(.year, from: .now) - year
        } else {
            age = nil
        }

        let isFemale = gender == "Kadın"

        if let age {
            if age < 6 {
                avatarIcon = isFemale ? "hi-girl-0105y" : "hi-boy-0105y"
            } else if age < 16 {
                avatarIcon = isFemale ? "hi-girl-1015y" : "hi-boy-1015y"
            } else if age < 60 {
                avatarIcon = isFemale ? "hi-woman" : "hi-man"
            } else {
                avatarIcon = isFemale ? "hi-old-woman" : "hi-old-man"
            }
        } else {
            avatarIcon = isFemale ? "hi-woman" : "hi-man"
        }
    }

    private func modeCard(title: String, description: String, icon: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(color)
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? color : .gray.opacity(0.3))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? color : .clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Profile Icon View (Reusable)

struct ProfileIconView: View {
    let iconName: String
    var size: CGFloat = 40

    var body: some View {
        if iconName.hasPrefix("hi-") {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            // Legacy emoji fallback
            Text(iconName)
                .font(.system(size: size * 0.7))
        }
    }
}

// MARK: - Category Icon View (Reusable)

/// Kategori ikonlarını healthicons asset'ten gösterir, yoksa SF Symbol fallback
struct CategoryIconView: View {
    let category: String
    var size: CGFloat = 22

    /// Açık petrol yeşili — tüm kategori ikonları için tek renk
    static let iconColor = Color(red: 0.0, green: 0.60, blue: 0.56)

    private var iconInfo: (asset: String?, sfSymbol: String) {
        switch category {
        case "Böbrek":         return ("hi-kidneys",        "drop.fill")
        case "Karaciğer":      return ("hi-liver",          "cross.vial.fill")
        case "Hemogram":       return ("hi-blood-cells",    "drop.triangle.fill")
        case "Tiroid":         return ("hi-thyroid",        "waveform.path.ecg")
        case "Lipid":          return ("hi-blood-bag",      "chart.bar.fill")
        case "Hormon":         return ("hi-medicines",      "pills.fill")
        case "Vitamin":        return ("hi-pills",          "leaf.fill")
        case "Kardiyovasküler": return ("hi-heart-organ",   "heart.fill")
        case "Tansiyon":       return ("hi-blood-pressure", "gauge.with.dots.needle.bottom.50percent")
        case "Kan Değerleri":  return ("hi-blood-drop",     "drop.degreesign.fill")
        case "Vücut Ölçüleri": return ("hi-weight",         "figure.stand")
        case "Solunum":        return ("hi-lungs",          "lungs.fill")
        case "Aktivite":       return ("hi-running",        "figure.run")
        case "Beslenme":       return ("hi-nutrition",      "fork.knife")
        case "Uyku":           return (nil,                 "bed.double.fill")
        default:               return (nil,                 "chart.line.uptrend.xyaxis")
        }
    }

    var body: some View {
        let info = iconInfo
        if let asset = info.asset {
            Image(asset)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(Self.iconColor)
        } else {
            Image(systemName: info.sfSymbol)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundColor(Self.iconColor)
        }
    }

    /// SF Symbol adı (Label gibi bileşenler için fallback)
    static func sfSymbol(for category: String) -> String {
        switch category {
        case "Böbrek":         return "drop.fill"
        case "Karaciğer":      return "cross.vial.fill"
        case "Hemogram":       return "drop.triangle.fill"
        case "Tiroid":         return "waveform.path.ecg"
        case "Lipid":          return "chart.bar.fill"
        case "Hormon":         return "pills.fill"
        case "Vitamin":        return "leaf.fill"
        case "Kardiyovasküler": return "heart.fill"
        case "Tansiyon":       return "gauge.with.dots.needle.bottom.50percent"
        case "Kan Değerleri":  return "drop.degreesign.fill"
        case "Vücut Ölçüleri": return "figure.stand"
        case "Solunum":        return "lungs.fill"
        case "Aktivite":       return "figure.run"
        case "Beslenme":       return "fork.knife"
        case "Uyku":           return "bed.double.fill"
        default:               return "chart.line.uptrend.xyaxis"
        }
    }
}

#Preview {
    OnboardingView()
        .modelContainer(for: [Person.self, LabResult.self], inMemory: true)
}
