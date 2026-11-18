import AppKit
import CryptoKit
import Darwin
import Foundation

struct CommandOutput {
    var status: Int32
    var text: String
}

protocol CommandExecuting {
    func run(_ executable: String, arguments: [String], environment: [String: String], timeout: TimeInterval) throws -> CommandOutput
}

final class ProcessCommandRunner: CommandExecuting {
    func run(_ executable: String, arguments: [String], environment: [String: String], timeout: TimeInterval = 90) throws -> CommandOutput {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("multicodex-operation-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("output.txt")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw ManagerError.message("Não foi possível preparar a operação no seu Mac.")
        }
        let output = try FileHandle(forWritingTo: outputURL)
        defer { try? output.close() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output
        process.standardError = output
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if finished.wait(timeout: .now() + 3) == .timedOut { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw ManagerError.timeout
        }
        process.waitUntilExit()
        let data = try Data(contentsOf: outputURL)
        return CommandOutput(status: process.terminationStatus,
                             text: String(decoding: data.prefix(131_072), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

final class AccountBackend {
    let root: URL
    let bundledCLI: String
    let runner: CommandExecuting
    let appOverride: String?
    let inspectRunningApps: Bool

    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Multi Codex"),
         bundledCLI: String = Bundle.main.url(forResource: "multi-codex-app", withExtension: nil)?.path ?? "",
         runner: CommandExecuting = ProcessCommandRunner(), appOverride: String? = nil, inspectRunningApps: Bool = true) {
        self.root = root
        self.bundledCLI = bundledCLI
        self.runner = runner
        self.appOverride = appOverride
        self.inspectRunningApps = inspectRunningApps
    }

    var configURL: URL { root.appendingPathComponent("config.json") }
    var environment: [String: String] {
        var value = ProcessInfo.processInfo.environment
        for key in ["CODEX_HOME", "CODEX_ELECTRON_USER_DATA_PATH", "CODEX_DESKTOP_RELAUNCH_OPEN_EVENTS", "MULTI_CODEX_ROOT", "ELECTRON_RUN_AS_NODE"] {
            value.removeValue(forKey: key)
        }
        value["MULTI_CODEX_ROOT"] = root.path
        value["NO_COLOR"] = "1"
        return value
    }

    func loadConfiguration() throws -> AccountConfiguration? {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return nil }
        do {
            let config = try JSONDecoder().decode(AccountConfiguration.self, from: Data(contentsOf: configURL))
            try config.validate()
            return config
        } catch let error as ManagerError { throw error }
        catch { throw ManagerError.message("Não foi possível ler sua lista de contas. A configuração existente foi preservada.\n\n" + error.localizedDescription) }
    }

    func executable() throws -> String {
        let installed = root.appendingPathComponent("bin/multi-codex-app").path
        if FileManager.default.isExecutableFile(atPath: installed) { return installed }
        if FileManager.default.isExecutableFile(atPath: bundledCLI) { return bundledCLI }
        throw ManagerError.message("O gerenciador de perfis não foi encontrado. Abra uma cópia completa do CodexNeko.app.")
    }

    @discardableResult
    func command(_ arguments: [String], timeout: TimeInterval = 90) throws -> String {
        let result = try runner.run(try executable(), arguments: ["--root", root.path] + arguments, environment: environment, timeout: timeout)
        guard result.status == 0 else { throw ManagerError.command(result.text, result.status) }
        return result.text
    }

    func installedApp(_ configuration: AccountConfiguration? = nil) throws -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [appOverride, configuration?.appPath, "/Applications/ChatGPT.app", "/Applications/Codex.app",
                          home + "/Applications/ChatGPT.app", home + "/Applications/Codex.app"].compactMap { $0 }
        for path in candidates {
            if Bundle(path: path)?.bundleIdentifier == "com.openai.codex" { return path }
        }
        throw ManagerError.message("O aplicativo oficial do Codex não foi encontrado. Instale o Codex e clique em Adicionar conta novamente.")
    }

    func snapshot() throws -> AccountSnapshot {
        let configuration = try loadConfiguration()
        guard inspectRunningApps, let config = configuration else { return AccountSnapshot(configuration: configuration) }
        let apps = NSWorkspace.shared.runningApplications.filter {
            $0.bundleURL?.standardizedFileURL.path == URL(fileURLWithPath: config.appPath).standardizedFileURL.path
        }
        var commands: [String] = []
        for app in apps {
            if let result = try? runner.run("/bin/ps", arguments: ["-ww", "-p", String(app.processIdentifier), "-o", "command="], environment: environment, timeout: 5), result.status == 0 {
                commands.append(result.text)
            }
        }
        let ids = config.profiles.filter { profile in
            commands.contains { matchesProfileCommand($0, profile: profile) }
        }.map(\.id)
        return AccountSnapshot(configuration: config, runningIDs: Set(ids))
    }

    func withMutationLock<T>(_ action: () throws -> T) throws -> T {
        let digest = SHA256.hash(data: Data(root.standardizedFileURL.path.utf8)).prefix(12).map { String(format: "%02x", $0) }.joined()
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("multicodex-manager-\(getuid())-\(digest).lock").path
        let fd = open(path, O_CREAT | O_RDWR | O_NOFOLLOW, mode_t(0o600))
        guard fd >= 0 else { throw ManagerError.message("Não foi possível iniciar a operação. Tente novamente.") }
        defer { close(fd) }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            throw ManagerError.message("Outra janela do CodexNeko está alterando as contas. Aguarde a conclusão e tente novamente.")
        }
        defer { flock(fd, LOCK_UN) }
        return try action()
    }

    func create(name input: String, color: AccountColor) throws -> MutationOutcome {
        try withMutationLock {
            let previous = try loadConfiguration()
            let name = try validatedName(input, profiles: previous?.profiles ?? [])
            guard (previous?.profiles.count ?? 0) < 100 else { throw ManagerError.message("O limite é de 100 contas ativas. Arquive uma conta antes de adicionar outra.") }
            let before = Set((previous?.profiles ?? []).map(\.id))
            var created: AccountProfile?
            do {
                if previous == nil {
                    try command(["setup", "--count", "2", "--app", try installedApp(), "--no-dock"])
                } else {
                    _ = try installedApp(previous)
                    try command(["add", "--count", "1", "--no-dock"])
                }
                guard let after = try loadConfiguration() else { throw ManagerError.message("A instalação não retornou uma lista de contas.") }
                let candidates = after.profiles.filter { !before.contains($0.id) && (previous != nil || $0.id != "1") }
                guard candidates.count == 1, let new = candidates.first else {
                    throw ManagerError.message("A lista mudou durante a criação. Confira as contas antes de adicionar outra.")
                }
                created = new
                try command(["rename", new.id, name])
                try command(["icon", new.id, color.rawValue])
                do {
                    try command(["launch", new.id], timeout: 30)
                    return MutationOutcome(profileID: new.id, notice: nil)
                } catch {
                    return MutationOutcome(profileID: new.id, notice: "A conta foi criada. Não foi possível abrir sua janela agora; clique em Abrir conta.\n\n" + error.localizedDescription)
                }
            } catch {
                if created == nil, let after = try? loadConfiguration() {
                    created = after.profiles.first { !before.contains($0.id) && (previous != nil || $0.id != "1") }
                }
                if let profile = created {
                    return MutationOutcome(profileID: profile.id, notice: "O perfil \(profile.displayName) já foi criado. Uma etapa ficou pendente; confira a conta na lista antes de criar outra.\n\n" + error.localizedDescription)
                }
                throw error
            }
        }
    }

    func edit(id: String, name input: String, color: AccountColor) throws -> MutationOutcome {
        try withMutationLock {
            guard let config = try loadConfiguration(), let profile = config.profiles.first(where: { $0.id == id }) else {
                throw ManagerError.message("Esta conta não está mais na lista. Atualize e tente novamente.")
            }
            let name = try validatedName(input, profiles: config.profiles, excluding: id)
            if profile.name != name { try command(["rename", id, name]) }
            if profile.color != color { try command(["icon", id, color.rawValue]) }
            return MutationOutcome(profileID: id, notice: nil)
        }
    }

    func launch(id: String) throws -> MutationOutcome {
        guard let config = try loadConfiguration(), config.profiles.contains(where: { $0.id == id }) else {
            throw ManagerError.message("Esta conta não está disponível. Atualize a lista.")
        }
        try command(["launch", id], timeout: 30)
        return MutationOutcome(profileID: id, notice: nil)
    }

    func archive(id: String) throws -> MutationOutcome {
        try withMutationLock {
            guard let config = try loadConfiguration(), let profile = config.profiles.first(where: { $0.id == id }) else {
                throw ManagerError.message("Esta conta não está mais na lista.")
            }
            guard id != "1" else { throw ManagerError.message("A conta principal permanece disponível para preservar o acesso à sua instalação original.") }
            guard profile.shareChats != true, profile.shareMemories != true else {
                throw ManagerError.message("Esta conta usa compartilhamento de dados. Desative o compartilhamento antes de arquivar.")
            }
            try command(["remove", id])
            return MutationOutcome(profileID: nil, notice: nil)
        }
    }

    func restore(id: String) throws -> MutationOutcome {
        try withMutationLock {
            guard let config = try loadConfiguration(), let profile = config.removedProfiles?.first(where: { $0.id == id }) else {
                throw ManagerError.message("Esta conta não está mais arquivada.")
            }
            _ = try validatedName(profile.name, profiles: config.profiles)
            try command(["restore", id])
            return MutationOutcome(profileID: id, notice: nil)
        }
    }

    func repair() throws -> MutationOutcome {
        try withMutationLock {
            guard let config = try loadConfiguration() else { throw ManagerError.message("Adicione uma conta para configurar o CodexNeko.") }
            try command(["setup", "--count", String(max(1, config.profiles.count)), "--app", try installedApp(config), "--no-dock"])
            return MutationOutcome(profileID: nil, notice: nil)
        }
    }

    func diagnostics() throws -> String { try command(["doctor"], timeout: 30) }
}

func matchesProfileCommand(_ command: String, profile: AccountProfile) -> Bool {
    if profile.userDataDir.isEmpty {
        return !command.contains("--user-data-dir") && !command.contains("--user-data-path")
    }
    guard let range = command.range(of: "--user-data-dir=" + profile.userDataDir) else { return false }
    let remainder = command[range.upperBound...]
    return remainder.isEmpty || remainder.hasPrefix(" --")
}
