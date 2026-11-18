import AppKit
import Combine
import Foundation

enum ManagerSheet: Identifiable {
    case add, edit(AccountProfile), help, diagnostics(String), customize
    var id: String {
        switch self {
        case .add: return "add"
        case .edit(let profile): return "edit-" + profile.id
        case .help: return "help"
        case .diagnostics: return "diagnostics"
        case .customize: return "customize"
        }
    }
}

struct ManagerNotice: Identifiable {
    let id = UUID()
    var title: String
    var text: String
}

final class AccountStore: ObservableObject {
    let backend: AccountBackend
    private let queue = DispatchQueue(label: "com.coradini.multicodex.operations", qos: .userInitiated)
    @Published var snapshot = AccountSnapshot(configuration: nil)
    @Published var isLoading = true
    @Published var working: String?
    @Published var sheet: ManagerSheet?
    @Published var notice: ManagerNotice?
    @Published var toast: String?
    @Published var showsArchived = false
    @Published var search = ""
    @Published var archiveCandidate: AccountProfile?
    @Published private(set) var mascotVariant: MascotVariant = MascotVariant.saved()
    var isBusy: Bool { working != nil }
    private var refreshing = false

    init(backend: AccountBackend = AccountBackend()) { self.backend = backend }

    func setMascot(_ variant: MascotVariant) {
        mascotVariant = variant
        UserDefaults.standard.set(variant.rawValue, forKey: MascotVariant.preferenceKey)
        applyDockIcon()
        showToast("Mascote \(variant.title.lowercased()) selecionado.")
    }

    func applyDockIcon() {
        if let image = mascotVariant.image(icon: true) { NSApplication.shared.applicationIconImage = image }
    }

    var visibleProfiles: [AccountProfile] {
        let list = showsArchived ? snapshot.archived : snapshot.profiles
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return list.filter { query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query) || $0.id == query }
            .sorted { (Int($0.id) ?? 0) < (Int($1.id) ?? 0) }
    }

    var suggestedName: String {
        let profiles = snapshot.profiles + snapshot.archived
        var number = max(2, (profiles.compactMap { Int($0.id) }.max() ?? 1) + 1)
        while profiles.contains(where: { $0.name.caseInsensitiveCompare("Conta \(number)") == .orderedSame }) { number += 1 }
        return "Conta \(number)"
    }

    func refresh(silent: Bool = false) {
        guard !isBusy, !refreshing else { return }
        refreshing = true
        queue.async { [self] in
            let result = Result { try backend.snapshot() }
            DispatchQueue.main.async { [self] in
                refreshing = false
                isLoading = false
                switch result {
                case .success(let value): if !isBusy { snapshot = value }
                case .failure(let error): if !silent { notice = ManagerNotice(title: "Não foi possível carregar as contas", text: error.localizedDescription) }
                }
            }
        }
    }

    func addAccount() { guard !isBusy else { return }; sheet = .add }

    func perform(_ title: String, success: String, operation: @escaping () throws -> MutationOutcome) {
        guard !isBusy else { return }
        working = title
        sheet = nil
        queue.async { [self] in
            let result = Result { try operation() }
            let current = try? backend.snapshot()
            DispatchQueue.main.async { [self] in
                working = nil
                isLoading = false
                if let current = current { snapshot = current }
                switch result {
                case .success(let outcome):
                    if let message = outcome.notice {
                        notice = ManagerNotice(title: "Confira sua conta", text: message)
                    } else {
                        showToast(success)
                    }
                case .failure(let error):
                    notice = ManagerNotice(title: "Não foi possível concluir", text: error.localizedDescription)
                }
            }
        }
    }

    func create(name: String, color: AccountColor) {
        showsArchived = false
        search = ""
        perform("Criando sua nova conta…", success: "Conta criada. Entre com a outra conta na nova janela.") {
            try self.backend.create(name: name, color: color)
        }
    }

    func edit(_ profile: AccountProfile, name: String, color: AccountColor) {
        perform("Salvando as alterações…", success: "Conta atualizada.") {
            try self.backend.edit(id: profile.id, name: name, color: color)
        }
    }

    func launch(_ profile: AccountProfile) {
        perform("Abrindo \(profile.displayName)…", success: "Janela de \(profile.displayName) aberta.") {
            try self.backend.launch(id: profile.id)
        }
    }

    func archive(_ profile: AccountProfile) {
        archiveCandidate = nil
        perform("Arquivando a conta…", success: "Conta arquivada. O login e os dados foram mantidos.") {
            try self.backend.archive(id: profile.id)
        }
    }

    func restore(_ profile: AccountProfile) {
        perform("Restaurando a conta…", success: "Conta restaurada. Ela voltou para Suas contas.") {
            try self.backend.restore(id: profile.id)
        }
    }

    func repair() {
        perform("Conferindo e reparando a instalação…", success: "Instalação reparada. Suas contas continuam disponíveis.") {
            try self.backend.repair()
        }
    }

    func diagnostics() {
        guard !isBusy else { return }
        working = "Verificando a instalação…"
        sheet = nil
        queue.async { [self] in
            let result = Result { try backend.diagnostics() }
            DispatchQueue.main.async { [self] in
                working = nil
                switch result {
                case .success(let text): sheet = .diagnostics("Instalação verificada.\n\n" + text)
                case .failure(let error): sheet = .diagnostics(error.localizedDescription)
                }
            }
        }
    }

    func showToast(_ text: String) {
        toast = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
            if self?.toast == text { self?.toast = nil }
        }
    }
}
