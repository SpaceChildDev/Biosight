import SwiftUI
import SwiftData

struct ProfileManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Person.createdAt) private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""
    @AppStorage("userTier") private var userTierRaw: String = "free"

    @State private var showAddProfile = false
    @State private var editingProfile: Person?
    @State private var showDeleteConfirm = false
    @State private var profileToDelete: Person?

    private var isPremium: Bool {
        userTierRaw == "premium"
    }

    private var maxProfiles: Int {
        isPremium ? 5 : 1
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(profiles) { profile in
                        ProfileRow(
                            profile: profile,
                            isActive: profile.id.uuidString == activePersonID,
                            onSelect: { selectProfile(profile) },
                            onEdit: { editingProfile = profile },
                            onDelete: {
                                profileToDelete = profile
                                showDeleteConfirm = true
                            }
                        )
                    }

                    if profiles.count < maxProfiles {
                        Button {
                            showAddProfile = true
                        } label: {
                            Label("Yeni Profil Ekle", systemImage: "plus.circle.fill")
                        }
                    } else if !isPremium {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.purple)
                            Text("Birden fazla profil için Premium'a geçin")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Profiller (\(profiles.count)/\(maxProfiles))")
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Aile Üyeleri", systemImage: "person.3.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.accentColor)
                        Text("Her profil kendi tahlil sonuçlarını ve sağlık verilerini ayrı tutar. Profiller arasında geçiş yaparak farklı kişilerin verilerini takip edebilirsiniz.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Profil Yönetimi")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(isPresented: $showAddProfile) {
                ProfileEditView(onSave: { name, icon, birthDate, gender in
                    let person = Person(name: name, birthDate: birthDate, gender: gender, avatarEmoji: icon)
                    modelContext.insert(person)
                    if profiles.isEmpty {
                        activePersonID = person.id.uuidString
                    }
                })
            }
            .sheet(item: $editingProfile) { profile in
                ProfileEditView(
                    name: profile.name,
                    icon: profile.avatarEmoji,
                    birthDate: profile.birthDate,
                    gender: profile.gender,
                    onSave: { name, icon, birthDate, gender in
                        profile.name = name
                        profile.avatarEmoji = icon
                        profile.birthDate = birthDate
                        profile.gender = gender
                    }
                )
            }
            .alert("Profili Sil", isPresented: $showDeleteConfirm) {
                Button("Sil", role: .destructive) {
                    if let profile = profileToDelete {
                        deleteProfile(profile)
                    }
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                if let profile = profileToDelete {
                    Text("\"\(profile.name)\" profili ve tüm tahlil sonuçları kalıcı olarak silinecek.")
                }
            }
            .onAppear {
                ensureDefaultProfile()
            }
        }
    }

    private func selectProfile(_ profile: Person) {
        activePersonID = profile.id.uuidString
    }

    private func deleteProfile(_ profile: Person) {
        let wasActive = profile.id.uuidString == activePersonID
        modelContext.delete(profile)

        if wasActive {
            // Başka profil varsa ona geç
            if let first = profiles.first(where: { $0.id != profile.id }) {
                activePersonID = first.id.uuidString
            } else {
                activePersonID = ""
            }
        }
    }

    private func ensureDefaultProfile() {
        if profiles.isEmpty {
            let defaultPerson = Person(name: "Ben", avatarEmoji: "hi-man")
            modelContext.insert(defaultPerson)
            activePersonID = defaultPerson.id.uuidString
        } else if activePersonID.isEmpty {
            activePersonID = profiles.first?.id.uuidString ?? ""
        }
    }
}

// MARK: - Profile Row

struct ProfileRow: View {
    let profile: Person
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ProfileIconView(iconName: profile.avatarEmoji, size: 36)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(profile.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("\(profile.labResults.count) kayıt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Sil", systemImage: "trash")
            }
            Button { onEdit() } label: {
                Label("Düzenle", systemImage: "pencil")
            }
            .tint(.orange)
        }
    }
}

// MARK: - Profile Edit

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var name: String
    @State var icon: String
    @State var birthDate: Date?
    @State var gender: String?
    @State private var birthDay = ""
    @State private var birthMonth = ""
    @State private var birthYear = ""

    let onSave: (String, String, Date?, String?) -> Void

    private let avatarIcons = [
        "hi-boy-0105y", "hi-girl-0105y",
        "hi-boy-1015y", "hi-girl-1015y",
        "hi-man", "hi-woman",
        "hi-old-man", "hi-old-woman"
    ]
    private let genders = ["Erkek", "Kadın", "Diğer"]

    init(name: String = "", icon: String = "hi-man", birthDate: Date? = nil, gender: String? = nil, onSave: @escaping (String, String, Date?, String?) -> Void) {
        _name = State(initialValue: name)
        _icon = State(initialValue: icon)
        _birthDate = State(initialValue: birthDate)
        _gender = State(initialValue: gender)
        self.onSave = onSave

        if let birthDate {
            let cal = Calendar.current
            _birthDay = State(initialValue: String(cal.component(.day, from: birthDate)))
            _birthMonth = State(initialValue: String(cal.component(.month, from: birthDate)))
            _birthYear = State(initialValue: String(cal.component(.year, from: birthDate)))
        }
    }

    private var parsedBirthDate: Date? {
        guard let day = Int(birthDay), let month = Int(birthMonth), let year = Int(birthYear),
              day >= 1, day <= 31, month >= 1, month <= 12, year >= 1900
        else { return nil }
        var components = DateComponents()
        components.day = day
        components.month = month
        components.year = year
        return Calendar.current.date(from: components)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profil Bilgileri") {
                    TextField("İsim", text: $name)

                    // İkon seçici
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Avatar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(avatarIcons, id: \.self) { iconName in
                                ProfileIconView(iconName: iconName, size: 40)
                                    .foregroundColor(icon == iconName ? .white : .primary)
                                    .padding(8)
                                    .background(icon == iconName ? Color.accentColor : Color(.tertiarySystemGroupedBackground))
                                    .cornerRadius(10)
                                    .onTapGesture { icon = iconName }
                            }
                        }
                    }
                }

                Section("Opsiyonel") {
                    Picker("Cinsiyet", selection: Binding(
                        get: { gender ?? "" },
                        set: { gender = $0.isEmpty ? nil : $0 }
                    )) {
                        Text("Belirtilmemiş").tag("")
                        ForEach(genders, id: \.self) { g in
                            Text(g).tag(g)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Doğum Tarihi")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            TextField("Gün", text: $birthDay)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 55)
                            Text("/").foregroundColor(.secondary)
                            TextField("Ay", text: $birthMonth)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 55)
                            Text("/").foregroundColor(.secondary)
                            TextField("Yıl", text: $birthYear)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 70)
                        }
                    }
                }
            }
            .navigationTitle(name.isEmpty ? "Yeni Profil" : name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        onSave(name, icon, parsedBirthDate ?? birthDate, gender)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
