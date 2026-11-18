import AppKit
import SwiftUI

private let blue = AppTheme.accent
private let textInk = AppTheme.text
private let lineColor = AppTheme.outline
private let greenStatus = Color(red: 0.20, green: 0.73, blue: 0.34)

struct AccountManagerView: View {
    @ObservedObject var store: AccountStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header.padding(.bottom, 22)
                if store.isLoading {
                    HStack { Spacer(); ProgressView("Carregando contas…"); Spacer() }.frame(height: 210)
                } else {
                    HStack(spacing: 14) {
                        Button { store.sheet = .customize } label: {
                            AccountMascot(variant: store.mascotVariant).frame(width: 116, height: 68)
                        }
                        .buttonStyle(.plain).help("Personalizar mascote")
                        .accessibilityLabel("Personalizar mascote")
                        Text(store.showsArchived ? "Seus logins continuam guardados." : runningSummary)
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 17).padding(.vertical, 12)
                            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 17))
                            .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(lineColor))
                        Spacer(minLength: 0)
                    }
                    .padding(.bottom, 14)
                    if store.snapshot.profiles.count > 6 || !store.search.isEmpty {
                        HStack(spacing: 9) {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            TextField("Buscar conta", text: $store.search).textFieldStyle(.plain)
                        }
                        .padding(12).background(AppTheme.field, in: RoundedRectangle(cornerRadius: 10)).padding(.bottom, 15)
                    }
                    if store.visibleProfiles.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(store.visibleProfiles) { profile in
                                AccountListRow(profile: profile, running: store.snapshot.runningIDs.contains(profile.id), archived: store.showsArchived,
                                               open: { store.launch(profile) }, edit: { store.sheet = .edit(profile) },
                                               archive: { store.archiveCandidate = profile }, restore: { store.restore(profile) })
                            }
                        }
                    }
                    connections.padding(.top, 29)
                }
                footer.padding(.top, 22)
            }
            .padding(.horizontal, 30).padding(.top, 39).padding(.bottom, 25)
        }
        .background(AppTheme.background)
        .foregroundColor(textInk)
        .font(.system(size: 13))
        .tint(blue)
        .frame(minWidth: 640, minHeight: 560)
        .preferredColorScheme(.dark)
        .overlay {
            if let title = store.working {
                ZStack {
                    Color.black.opacity(0.66)
                    VStack(spacing: 15) {
                        ProgressView()
                        Text(title).font(.system(size: 16, weight: .semibold))
                        Text("Só um instante.").foregroundColor(.secondary)
                    }
                    .padding(32).frame(width: 320)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(lineColor))
                    .shadow(color: .black.opacity(0.07), radius: 24, y: 8)
                }.accessibilityElement(children: .combine)
            }
        }
        .sheet(item: $store.sheet) { sheet in
            switch sheet {
            case .add: AccountEditor(store: store, profile: nil)
            case .edit(let profile): AccountEditor(store: store, profile: profile)
            case .help: HelpView(store: store)
            case .diagnostics(let text): DiagnosticsView(store: store, text: text)
            case .customize: MascotPickerView(store: store)
            }
        }
        .alert(item: $store.notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.text), dismissButton: .default(Text("Entendi")))
        }
        .confirmationDialog("Arquivar \(store.archiveCandidate?.displayName ?? "conta")?", isPresented: Binding(
            get: { store.archiveCandidate != nil }, set: { if !$0 { store.archiveCandidate = nil } }
        ), titleVisibility: .visible, presenting: store.archiveCandidate) { profile in
            Button("Arquivar conta") { store.archive(profile) }
            Button("Cancelar", role: .cancel) { store.archiveCandidate = nil }
        } message: { _ in
            Text("Você poderá restaurá-la em Arquivadas. O login e as conversas serão mantidos. Se a janela estiver aberta, ela continuará aberta.")
        }
    }

    private var runningSummary: String {
        let count = store.snapshot.runningIDs.intersection(Set(store.snapshot.profiles.map(\.id))).count
        return "\(count) de \(store.snapshot.profiles.count) abertas."
    }

    private var versionSummary: String {
        let count = (store.showsArchived ? store.snapshot.archived : store.snapshot.profiles).count
        let description = "\(count) \(count == 1 ? "conta" : "contas")"
        if let path = store.snapshot.configuration?.appPath,
           let version = Bundle(path: path)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return description + " · Codex " + version
        }
        return description + " · MultiCodex 1.0"
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.showsArchived ? "Contas arquivadas" : "Contas Codex")
                    .font(.system(size: 32, weight: .bold)).tracking(-0.9)
                Text(versionSummary).font(.system(size: 15)).foregroundColor(.secondary)
            }
            Spacer(minLength: 5)
            if store.showsArchived {
                Button { store.showsArchived = false; store.search = "" } label: { Label("Voltar", systemImage: "arrow.left") }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button { store.addAccount() } label: {
                    HStack(spacing: 9) { Image(systemName: "plus").font(.system(size: 17, weight: .regular)); Text("Adicionar conta") }
                }
                .buttonStyle(PrimaryButtonStyle()).keyboardShortcut("n", modifiers: .command)
                .disabled(store.isBusy || store.isLoading)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: store.showsArchived ? "archivebox" : "person.crop.circle.badge.plus")
                .font(.system(size: 32, weight: .light)).foregroundColor(.secondary)
            Text(store.search.isEmpty ? (store.showsArchived ? "Nenhuma conta arquivada" : "Adicione sua próxima conta") : "Nenhuma conta encontrada")
                .font(.system(size: 18, weight: .semibold))
            Text(store.showsArchived ? "As contas que você arquivar aparecerão aqui." : "A conta que você já usa será reconhecida como principal.")
                .font(.system(size: 12)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).frame(height: 185)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private var connections: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONEXÕES").font(.system(size: 11, weight: .semibold)).tracking(1.0).foregroundColor(.secondary).padding(.leading, 4)
            HStack(spacing: 17) {
                Image(systemName: "link").font(.system(size: 23, weight: .medium)).foregroundColor(.secondary).frame(width: 32)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Conecte na conta certa").font(.system(size: 16, weight: .semibold))
                    Text("Ao conectar um plugin, escolha a janela que iniciou a conexão.")
                        .font(.system(size: 12)).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                Button { store.sheet = .help } label: { Image(systemName: "questionmark.circle").font(.system(size: 21)).foregroundColor(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Ajuda sobre conexões")
            }
            .padding(.horizontal, 21).padding(.vertical, 21)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(lineColor))
        }
    }

    private var footer: some View {
        VStack(spacing: 15) {
            if let text = store.toast {
                HStack(spacing: 9) {
                    Image(systemName: "checkmark.circle.fill").foregroundColor(greenStatus)
                    Text(text).font(.system(size: 11))
                    Spacer(minLength: 4)
                    Button { store.toast = nil } label: { Image(systemName: "xmark").font(.system(size: 9)) }.buttonStyle(.plain)
                }
                .padding(12).background(greenStatus.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            HStack(spacing: 16) {
                Button { store.refresh() } label: { Label("Atualizar", systemImage: "arrow.clockwise") }
                    .keyboardShortcut("r", modifiers: .command)
                if !store.showsArchived {
                    Button { store.showsArchived = true; store.search = "" } label: { Text("Arquivadas (\(store.snapshot.archived.count))") }
                }
                Spacer(minLength: 5)
                Button { store.sheet = .customize } label: { Label("Personalizar", systemImage: "slider.horizontal.3") }
                Button { store.sheet = .help } label: { Text("Ajuda") }
                Text("·").foregroundColor(.secondary.opacity(0.5))
                Text("Coradini").font(.system(size: 10, weight: .medium)).foregroundColor(.secondary.opacity(0.65))
            }
            .buttonStyle(.plain).font(.system(size: 11)).foregroundColor(.secondary).disabled(store.isBusy)
        }
    }
}

private struct AccountListRow: View {
    let profile: AccountProfile
    let running: Bool
    let archived: Bool
    let open: () -> Void
    let edit: () -> Void
    let archive: () -> Void
    let restore: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            InitialAvatar(profile: profile).frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 8) {
                Text(profile.displayName).font(.system(size: 22, weight: .semibold)).tracking(-0.4)
                    .lineLimit(1).truncationMode(.middle).help(profile.displayName)
                HStack(spacing: 6) {
                    Circle().fill(running && !archived ? greenStatus : Color.gray.opacity(0.45)).frame(width: 7, height: 7)
                    Text(archived ? "Arquivada" : (running ? "Em execução" : "Não está aberta"))
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(running && !archived ? greenStatus : .secondary)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background((running && !archived ? greenStatus : Color.gray).opacity(0.09), in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: archived ? restore : open) { Text(archived ? "Restaurar" : (running ? "Mostrar" : "Abrir")) }
                .font(.system(size: 16, weight: .medium)).buttonStyle(.plain)
                .foregroundColor(running && !archived ? textInk : blue)
                .padding(.horizontal, 20).frame(height: 38)
                .background(running && !archived ? AppTheme.elevated : blue.opacity(0.15), in: Capsule())
                .accessibilityLabel(archived ? "Restaurar \(profile.displayName)" : "Abrir \(profile.displayName)")
            if !archived {
                Menu {
                    Button("Editar nome e cor…", action: edit)
                    if let path = profile.launcherPath {
                        Button("Mostrar aplicativo no Finder") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
                    }
                    if profile.id != "1" { Divider(); Button("Arquivar conta…", action: archive) }
                } label: { Image(systemName: "ellipsis").font(.system(size: 19, weight: .medium)).frame(width: 25, height: 30) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("Opções de \(profile.displayName)")
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 19)
        .frame(maxWidth: .infinity)
        .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(lineColor))
    }
}

struct InitialAvatar: View {
    let profile: AccountProfile
    private var avatarColor: Color {
        profile.color == .white ? Color(red: 0.05, green: 0.61, blue: 0.72) : Color(nsColor: profile.color.color)
    }
    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [avatarColor.opacity(0.78), avatarColor], startPoint: .topLeading, endPoint: .bottomTrailing))
            .shadow(color: avatarColor.opacity(0.23), radius: 9, y: 4)
            .overlay(Text(String(profile.displayName.prefix(1)).uppercased()).font(.system(size: 27, weight: .semibold))
                .foregroundColor(profile.color == .yellow ? AppTheme.darkInk : .white))
            .accessibilityHidden(true)
    }
}

