import AppKit
import Foundation

enum AccountColor: String, CaseIterable, Identifiable {
    case white, yellow, blue, purple, teal
    var id: String { rawValue }
    var title: String {
        switch self {
        case .white: return "Branco"
        case .yellow: return "Amarelo"
        case .blue: return "Azul"
        case .purple: return "Roxo"
        case .teal: return "Verde"
        }
    }
    var color: NSColor {
        switch self {
        case .white: return NSColor(srgbRed: 0.95, green: 0.95, blue: 0.93, alpha: 1)
        case .yellow: return NSColor(srgbRed: 0.98, green: 0.80, blue: 0.18, alpha: 1)
        case .blue: return NSColor(srgbRed: 0.20, green: 0.36, blue: 0.88, alpha: 1)
        case .purple: return NSColor(srgbRed: 0.48, green: 0.25, blue: 0.83, alpha: 1)
        case .teal: return NSColor(srgbRed: 0.08, green: 0.48, blue: 0.42, alpha: 1)
        }
    }
}

struct AccountProfile: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var codexHome: String
    var userDataDir: String
    var launcherPath: String?
    var iconColor: String?
    var shareChats: Bool?
    var shareMemories: Bool?

    var color: AccountColor {
        if let value = iconColor, let color = AccountColor(rawValue: value) { return color }
        return AccountColor.allCases[max(0, (Int(id) ?? 1) - 1) % AccountColor.allCases.count]
    }
    var displayName: String {
        if id == "1" && name == "Primary" { return "Principal" }
        if id == "2" && name == "Secondary" { return "Conta 2" }
        return name
    }
}

struct AccountConfiguration: Codable {
    var version: Int
    var appPath: String
    var cliPath: String
    var profiles: [AccountProfile]
    var removedProfiles: [AccountProfile]?

    func validate() throws {
        guard version == 1 else { throw ManagerError.message("Esta configuração usa uma versão incompatível. Seus perfis foram preservados.") }
        let all = profiles + (removedProfiles ?? [])
        let ids = all.map(\.id)
        guard Set(ids).count == ids.count,
              all.allSatisfy({ profile in
                  guard let number = Int(profile.id) else { return false }
                  return number > 0 && String(number) == profile.id
              }) else {
            throw ManagerError.message("A lista de contas contém identificadores inválidos. Use Verificar instalação para conferir.")
        }
        guard appPath.hasPrefix("/"), cliPath.hasPrefix("/"), all.allSatisfy({
            $0.codexHome.hasPrefix("/") && ($0.id == "1" || $0.userDataDir.hasPrefix("/"))
        }) else { throw ManagerError.message("A configuração contém caminhos inválidos. Seus dados não foram alterados.") }
    }
}

struct AccountSnapshot {
    var configuration: AccountConfiguration?
    var runningIDs: Set<String> = []
    var profiles: [AccountProfile] { configuration?.profiles ?? [] }
    var archived: [AccountProfile] { configuration?.removedProfiles ?? [] }
}

struct MutationOutcome {
    var profileID: String?
    var notice: String?
}

enum ManagerError: LocalizedError {
    case message(String)
    case command(String, Int32)
    case timeout
    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        case .command(let output, _):
            if output.contains("operation not permitted") || output.contains("permission denied") {
                return "O macOS não permitiu concluir esta operação. Abra o CodexNeko normalmente pelo Finder e tente novamente.\n\n" + output
            }
            return output.isEmpty ? "Não foi possível concluir a operação. Tente Verificar instalação." : output
        case .timeout: return "A operação demorou mais que o esperado e foi interrompida. A lista será atualizada para mostrar o que já foi criado."
        }
    }
}

func canonicalLauncherName(_ name: String) -> String {
    let lower = name.lowercased()
    return lower.hasPrefix("codex ") || lower.hasPrefix("codex(") ? name : "Codex " + name
}

func validatedName(_ input: String, profiles: [AccountProfile], excluding: String? = nil) throws -> String {
    let name = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, name.unicodeScalars.count <= 80,
          name.rangeOfCharacter(from: CharacterSet(charactersIn: "/\\:*?\"<>|").union(.controlCharacters)) == nil,
          !name.hasSuffix("."), name.lowercased() != "codex" else {
        throw ManagerError.message("Escolha um nome de 1 a 80 caracteres, sem / \\ : * ? \" < > |. Por exemplo: Pessoal ou Trabalho.")
    }
    guard !profiles.contains(where: {
        $0.id != excluding && canonicalLauncherName($0.name).caseInsensitiveCompare(canonicalLauncherName(name)) == .orderedSame
    }) else { throw ManagerError.message("Já existe uma conta com esse nome. Escolha outro para identificar a nova janela.") }
    return name
}
