import SwiftUI
import SwiftData

struct EasyModeHomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabResult.date, order: .reverse) private var labResults: [LabResult]
    @Query(sort: \Person.createdAt) private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""
    @AppStorage("easyMode") private var easyMode = false

    @State private var showScanDocument = false
    @State private var showPDFUpload = false
    @State private var showAllResults = false
    @State private var showDashboard = false
    @State private var showProfile = false
    @State private var showHealthImport = false

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    private var activeResults: [LabResult] {
        guard let person = activePerson else { return labResults }
        return labResults.filter { $0.person == nil || $0.person?.id == person.id }
    }

    private var abnormalCount: Int {
        activeResults.filter { $0.isAbnormal }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Greeting
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.path.ecg.rectangle.fill")
                                .font(.title2)
                                .foregroundStyle(.linearGradient(
                                    colors: [.accentColor, .accentColor.opacity(0.7)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Biosight")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(1)
                                Text("Merhaba, \(activePerson?.name ?? "")!")
                                    .font(.title2.bold())
                            }
                            Spacer()
                        }

                        if !activeResults.isEmpty {
                            HStack(spacing: 16) {
                                statBadge(
                                    value: "\(activeResults.count)",
                                    label: "Kayıt",
                                    color: .blue
                                )
                                if abnormalCount > 0 {
                                    statBadge(
                                        value: "\(abnormalCount)",
                                        label: "İzleme",
                                        color: .orange
                                    )
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)

                    // Main actions
                    VStack(spacing: 16) {
                        bigButton(
                            icon: "camera.viewfinder",
                            title: "Tahlil Tara",
                            subtitle: "Kamera ile tahlil belgenizi tarayın",
                            color: .blue
                        ) {
                            showScanDocument = true
                        }

                        bigButton(
                            icon: "doc.badge.plus",
                            title: "Tahlil Yükle",
                            subtitle: "Tahlil belgenizi seçin",
                            color: .orange
                        ) {
                            showPDFUpload = true
                        }

                        bigButton(
                            icon: "list.clipboard.fill",
                            title: "Sonuçlarım",
                            subtitle: "\(activeResults.count) kayıt mevcut",
                            color: .green
                        ) {
                            showAllResults = true
                        }

                        bigButton(
                            icon: "heart.text.square.fill",
                            title: "Sağlık Özeti",
                            subtitle: "Genel durumunuzu görün",
                            color: .purple
                        ) {
                            showDashboard = true
                        }
                    }
                    .padding(.horizontal, 24)

                    // Apple Health — küçük link
                    Button {
                        showHealthImport = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.fill")
                                .font(.subheadline)
                                .foregroundColor(.pink)
                            Text("Apple Health'ten Aktar")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        showProfile = true
                    } label: {
                        HStack(spacing: 4) {
                            ProfileIconView(iconName: activePerson?.avatarEmoji ?? "hi-man", size: 24)
                                .foregroundColor(.accentColor)
                            Image(systemName: "gearshape.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showScanDocument) {
                ScanDocumentView()
            }
            .sheet(isPresented: $showPDFUpload) {
                PDFUploadView()
            }
            .sheet(isPresented: $showHealthImport) {
                HealthImportView()
            }
            .sheet(isPresented: $showAllResults) {
                NavigationStack {
                    AllResultsView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Kapat") { showAllResults = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showDashboard) {
                NavigationStack {
                    DashboardView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Kapat") { showDashboard = false }
                            }
                        }
                }
            }
            .sheet(isPresented: $showProfile) {
                UserProfileView()
            }
            .onAppear {
                ensureDefaultProfile()
            }
        }
    }

    private func bigButton(icon: String, title: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(color)
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
    }

    private func statBadge(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }

    private func ensureDefaultProfile() {
        if profiles.isEmpty {
            let person = Person(name: "Ben", avatarEmoji: "hi-man")
            modelContext.insert(person)
            activePersonID = person.id.uuidString
        } else if activePersonID.isEmpty {
            activePersonID = profiles.first?.id.uuidString ?? ""
        }
    }
}

#Preview {
    EasyModeHomeView()
        .modelContainer(for: [Person.self, LabResult.self], inMemory: true)
}
