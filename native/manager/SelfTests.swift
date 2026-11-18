import Foundation

private enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)
    var description: String { switch self { case .assertion(let text): return text } }
}

private func check(_ condition: @autoclosure () throws -> Bool, _ text: String) throws {
    if try !condition() { throw TestFailure.assertion(text) }
}

private func expectFailure(_ action: () throws -> Void) throws {
    do { try action() } catch { return }
    throw TestFailure.assertion("Expected operation to fail")
}

// Synthetic installation only: no real account, credential, app, or LaunchAgent is changed.
private final class FixtureRunner: CommandExecuting {
    enum Fault { case none, beforeAdd, afterAdd, rename, launch }
    let root: URL
    let appPath: String
    var fault: Fault = .none
    var commands: [[String]] = []
    var environments: [[String: String]] = []
    var configURL: URL { root.appendingPathComponent("config.json") }
    var originalHome: String { root.appendingPathComponent("original-codex").path }

    init(root: URL, appPath: String) { self.root = root; self.appPath = appPath }

    func write(_ config: [String: Any]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: config, options: [.sortedKeys, .prettyPrinted]).write(to: configURL)
    }
    func read() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as! [String: Any]
    }
    func profile(_ id: Int, name: String? = nil) -> [String: Any] {
        ["id": String(id), "name": name ?? (id == 1 ? "Primary" : "Profile \(id)"),
         "codexHome": id == 1 ? originalHome : root.appendingPathComponent("profiles/\(id)/codex").path,
         "userDataDir": id == 1 ? "" : root.appendingPathComponent("profiles/\(id)/desktop").path]
    }
    func seed(count: Int = 2, archivedID: Int? = nil) throws {
        var config: [String: Any] = ["version": 1, "appPath": appPath, "cliPath": "/usr/bin/true",
                                   "profiles": (1...count).map { profile($0) }, "previousHandler": "com.openai.codex",
                                   "futureSetting": ["keep": true]]
        if let archivedID = archivedID { config["removedProfiles"] = [profile(archivedID, name: "Antiga")] }
        try write(config)
        try FileManager.default.createDirectory(atPath: originalHome, withIntermediateDirectories: true)
        try Data("synthetic-original-auth-marker".utf8).write(to: URL(fileURLWithPath: originalHome).appendingPathComponent("auth.json"))
    }

    func run(_ executable: String, arguments: [String], environment: [String: String], timeout: TimeInterval) throws -> CommandOutput {
        commands.append(arguments); environments.append(environment)
        guard arguments.count >= 3, arguments[0] == "--root", arguments[1] == root.path else {
            throw TestFailure.assertion("Every operation must explicitly target its installation")
        }
        let args = Array(arguments.dropFirst(2))
        switch args[0] {
        case "setup":
            if !FileManager.default.fileExists(atPath: configURL.path) { try seed() }
        case "add":
            if fault == .beforeAdd { return CommandOutput(status: 1, text: "synthetic add failure") }
            var config = try read()
            var profiles = config["profiles"] as! [[String: Any]]
            let removed = config["removedProfiles"] as? [[String: Any]] ?? []
            let maximum = (profiles + removed).compactMap { Int($0["id"] as! String) }.max() ?? 0
            profiles.append(profile(maximum + 1)); config["profiles"] = profiles; try write(config)
            if fault == .afterAdd { return CommandOutput(status: 1, text: "synthetic integration failure after saving") }
        case "rename", "icon":
            if args[0] == "rename" && fault == .rename { return CommandOutput(status: 1, text: "synthetic rename failure") }
            var config = try read()
            var profiles = config["profiles"] as! [[String: Any]]
            let index = profiles.firstIndex { $0["id"] as? String == args[1] }!
            profiles[index][args[0] == "rename" ? "name" : "iconColor"] = args[2]
            config["profiles"] = profiles; try write(config)
        case "launch":
            if fault == .launch { return CommandOutput(status: 1, text: "synthetic launch failure") }
        case "remove":
            var config = try read()
            var profiles = config["profiles"] as! [[String: Any]]
            var removed = config["removedProfiles"] as? [[String: Any]] ?? []
            let index = profiles.firstIndex { $0["id"] as? String == args[1] }!
            removed.append(profiles.remove(at: index)); config["profiles"] = profiles; config["removedProfiles"] = removed; try write(config)
        case "restore":
            var config = try read()
            var profiles = config["profiles"] as! [[String: Any]]
            var removed = config["removedProfiles"] as! [[String: Any]]
            let index = removed.firstIndex { $0["id"] as? String == args[1] }!
            profiles.append(removed.remove(at: index)); config["profiles"] = profiles; config["removedProfiles"] = removed; try write(config)
        default: throw TestFailure.assertion("Unexpected synthetic command: \(args)")
        }
        return CommandOutput(status: 0, text: "OK")
    }
}

func runManagerSelfTests() -> Int32 {
    let workspace = FileManager.default.temporaryDirectory.appendingPathComponent("multicodex-tests-" + UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: workspace) }
    var passed = 0
    var failed = 0
    func test(_ title: String, _ action: () throws -> Void) {
        do { try action(); print("PASS \(title)"); passed += 1 }
        catch { print("FAIL \(title): \(error)"); failed += 1 }
    }
    func fixture(_ name: String, seed: Bool = true, archived: Int? = nil) throws -> (AccountBackend, FixtureRunner) {
        let root = workspace.appendingPathComponent(name)
        let bundleURL = workspace.appendingPathComponent("Official Codex.app")
        try FileManager.default.createDirectory(at: bundleURL.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true)
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "com.openai.codex", "CFBundleExecutable": "Codex", "CFBundlePackageType": "APPL"], format: .xml, options: 0)
            .write(to: bundleURL.appendingPathComponent("Contents/Info.plist"))
        let runner = FixtureRunner(root: root, appPath: bundleURL.path)
        if seed { try runner.seed(archivedID: archived) }
        let backend = AccountBackend(root: root, bundledCLI: "/usr/bin/true", runner: runner, appOverride: bundleURL.path, inspectRunningApps: false)
        return (backend, runner)
    }

    test("Existing accounts and unknown configuration fields survive edits") {
        let (backend, runner) = try fixture("existing")
        let original = try backend.loadConfiguration()!.profiles[0]
        _ = try backend.edit(id: "2", name: "Trabalho", color: .purple)
        let after = try backend.loadConfiguration()!
        try check(after.profiles[0] == original, "Original account changed")
        try check(after.profiles[1].name == "Trabalho" && after.profiles[1].color == .purple, "Edit not applied")
        try check((try runner.read())["futureSetting"] != nil, "Unknown fields lost")
    }
    test("Add creates exactly one separate profile and launches its own ID") {
        let (backend, runner) = try fixture("create")
        let outcome = try backend.create(name: "Pessoal", color: .teal)
        let config = try backend.loadConfiguration()!
        let created = config.profiles.first { $0.id == outcome.profileID }!
        try check(config.profiles.count == 3 && created.id == "3", "Wrong profile allocation")
        try check(created.name == "Pessoal" && created.color == .teal, "Appearance not applied")
        try check(created.codexHome != config.profiles[0].codexHome && created.userDataDir != config.profiles[1].userDataDir, "Isolation lost")
        try check(!FileManager.default.fileExists(atPath: created.codexHome + "/auth.json"), "Authentication copied")
        try check(runner.commands.last?.suffix(2) == ["launch", "3"], "Wrong account launched")
        try check(runner.environments.allSatisfy { $0["CODEX_HOME"] == nil && $0["CODEX_ELECTRON_USER_DATA_PATH"] == nil && $0["MULTI_CODEX_ROOT"] == backend.root.path }, "Inherited account environment leaked")
    }
    test("Fresh setup keeps original account and creates the requested second account") {
        let (backend, runner) = try fixture("fresh", seed: false)
        let result = try backend.create(name: "Outra conta", color: .blue)
        try check(result.profileID == "2", "Initial account incorrectly selected")
        try check(try backend.loadConfiguration()!.profiles.count == 2, "Wrong initial count")
        try check(runner.commands.filter { $0.contains("setup") }.count == 1 && !runner.commands.contains { $0.contains("add") }, "Setup was repeated")
    }
    test("Archived IDs are never reused") {
        let (backend, _) = try fixture("ids", archived: 8)
        let result = try backend.create(name: "Nova", color: .yellow)
        try check(result.profileID == "9", "Archived ID reused")
    }
    test("Duplicate launcher names and invalid paths are rejected before mutation") {
        let (backend, runner) = try fixture("validation")
        _ = try backend.edit(id: "2", name: "Trabalho", color: .yellow)
        runner.commands.removeAll()
        try expectFailure { _ = try backend.create(name: "codex trabalho", color: .white) }
        try expectFailure { _ = try backend.create(name: "Pasta/Conta", color: .white) }
        try expectFailure { _ = try backend.create(name: "\n", color: .white) }
        try check(runner.commands.isEmpty, "Invalid name caused a mutation")
    }
    test("Failed add preserves configuration and is never retried") {
        let (backend, runner) = try fixture("failed-add")
        let original = try Data(contentsOf: backend.configURL)
        runner.fault = .beforeAdd
        try expectFailure { _ = try backend.create(name: "Nova", color: .white) }
        try check(try Data(contentsOf: backend.configURL) == original, "Configuration changed on failure")
        try check(runner.commands.count == 1, "Add retried")
    }
    test("Partial installation reports the existing profile instead of creating a duplicate") {
        let (backend, runner) = try fixture("partial-add")
        runner.fault = .afterAdd
        let result = try backend.create(name: "Nova", color: .white)
        try check(result.profileID == "3" && result.notice != nil, "Partial profile hidden")
        let count = try backend.loadConfiguration()!.profiles.count
        try check(runner.commands.count == 1 && count == 3, "Partial add retried")
    }
    test("Rename failure leaves the created profile visible and recoverable") {
        let (backend, runner) = try fixture("partial-rename")
        runner.fault = .rename
        let result = try backend.create(name: "Nova", color: .white)
        try check(result.profileID == "3" && result.notice != nil, "Created profile not reported")
        try check(!runner.commands.contains { $0.contains("launch") }, "Incomplete account launched")
    }
    test("Launch failure retains a fully configured account") {
        let (backend, runner) = try fixture("partial-launch")
        runner.fault = .launch
        let result = try backend.create(name: "Nova", color: .purple)
        let created = try backend.loadConfiguration()!.profiles.first { $0.id == "3" }!
        try check(result.notice != nil && created.name == "Nova" && created.color == .purple, "Profile lost after launch failure")
    }
    test("Archiving and restoring preserve profile ID, home, and authentication") {
        let (backend, runner) = try fixture("archive")
        let original = try backend.loadConfiguration()!.profiles[1]
        let marker = URL(fileURLWithPath: original.codexHome).appendingPathComponent("auth.json")
        try FileManager.default.createDirectory(at: marker.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("synthetic-secondary-auth-marker".utf8).write(to: marker)
        _ = try backend.archive(id: "2")
        try check(try backend.loadConfiguration()!.removedProfiles?.first == original, "Archived profile changed")
        _ = try backend.restore(id: "2")
        try check(try backend.loadConfiguration()!.profiles.contains(original), "Restored profile changed")
        try check(try String(contentsOf: marker, encoding: .utf8) == "synthetic-secondary-auth-marker", "Authentication changed")
        try check((try runner.read())["futureSetting"] != nil, "Unknown fields lost")
    }
    test("Original account cannot be archived") {
        let (backend, runner) = try fixture("primary")
        try expectFailure { _ = try backend.archive(id: "1") }
        try check(runner.commands.isEmpty, "Original account was modified")
    }
    test("Malformed configurations are preserved and never replaced by fresh setup") {
        let (backend, runner) = try fixture("malformed")
        let invalid = Data("{bad json".utf8)
        try invalid.write(to: backend.configURL)
        try expectFailure { _ = try backend.create(name: "Nova", color: .white) }
        try check(try Data(contentsOf: backend.configURL) == invalid, "Malformed configuration overwritten")
        try check(runner.commands.isEmpty, "Setup ran over existing configuration")
    }
    test("Two manager operations cannot mutate the same installation simultaneously") {
        let (backend, runner) = try fixture("locking")
        try backend.withMutationLock {
            try expectFailure { _ = try backend.create(name: "Outra", color: .white) }
        }
        try check(runner.commands.isEmpty, "Concurrent mutation ran")
    }
    test("Profile matching handles spaces and does not confuse account 2 with account 20") {
        let profile = AccountProfile(id: "2", name: "Test", codexHome: "/test/2/codex", userDataDir: "/Users/Test Name/Library/Multi Codex/profiles/2/desktop")
        try check(matchesProfileCommand("ChatGPT --user-data-dir=\(profile.userDataDir) --flag", profile: profile), "Spaced path did not match")
        try check(!matchesProfileCommand("ChatGPT --user-data-dir=\(profile.userDataDir)0 --flag", profile: profile), "Prefix collision matched")
    }
    test("Noncanonical profile IDs are rejected") {
        let (backend, runner) = try fixture("invalid-id")
        var config = try runner.read()
        var profiles = config["profiles"] as! [[String: Any]]
        profiles[1]["id"] = "02"; config["profiles"] = profiles; try runner.write(config)
        try expectFailure { _ = try backend.loadConfiguration() }
    }
    test("Subprocess arguments preserve accents, spaces, quotes and shell metacharacters literally") {
        let arguments = ["Pessoal com espaço", "$(touch /tmp/DO-NOT-CREATE)", "Trabalho ' Cliente", "Conta \"A\"", "nome`literal`"]
        let result = try ProcessCommandRunner().run("/usr/bin/python3", arguments: ["-c", "import json,sys; print(json.dumps(sys.argv[1:]))"] + arguments,
                                                  environment: ProcessInfo.processInfo.environment, timeout: 15)
        let received = try JSONDecoder().decode([String].self, from: Data(result.text.utf8))
        try check(result.status == 0 && received == arguments, "Arguments were interpolated")
    }
    test("Subprocess failures include stderr and the original exit code") {
        let result = try ProcessCommandRunner().run("/usr/bin/python3", arguments: ["-c", "import sys; print('synthetic stderr',file=sys.stderr); sys.exit(7)"], environment: ProcessInfo.processInfo.environment, timeout: 15)
        try check(result.status == 7 && result.text.contains("synthetic stderr"), "Failure details lost")
    }
    test("Subprocess timeout stops a stuck command") {
        let start = Date()
        try expectFailure {
            _ = try ProcessCommandRunner().run("/usr/bin/python3", arguments: ["-c", "import time; time.sleep(10)"], environment: ProcessInfo.processInfo.environment, timeout: 0.3)
        }
        try check(Date().timeIntervalSince(start) < 5, "Timeout failed to stop command")
    }
    test("Bundled upstream CLI reads the same account schema") {
        let (backend, _) = try fixture("real-cli")
        guard let cli = Bundle.main.url(forResource: "multi-codex-app", withExtension: nil)?.path else {
            throw TestFailure.assertion("Bundled CLI missing")
        }
        let result = try ProcessCommandRunner().run(cli, arguments: ["--root", backend.root.path, "list"], environment: backend.environment, timeout: 15)
        try check(result.status == 0 && result.text.contains("Primary") && result.text.contains("Profile 2"), "Schema does not match the actual backend")
    }
    print("\n\(passed) passed; \(failed) failed. Synthetic data only; real accounts untouched.")
    return failed == 0 ? 0 : 1
}
