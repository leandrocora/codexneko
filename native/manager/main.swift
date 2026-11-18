import AppKit
import SwiftUI

final class ManagerAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var window: NSWindow!
    let store = AccountStore()
    var refreshTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        buildMenus()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 740), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "MultiCodex"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 600)
        window.delegate = self
        window.contentView = NSHostingView(rootView: AccountManagerView(store: store).environment(\.colorScheme, .dark))
        window.backgroundColor = AppTheme.windowBackground
        window.center()
        window.setFrameAutosaveName("MultiCodexManagerWindow")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        store.applyDockIcon()
        store.refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: true) { [weak self] _ in
            guard let self = self, NSApp.isActive, self.store.sheet == nil else { return }
            self.store.refresh(silent: true)
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) { store.refresh(silent: true) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        window?.makeKeyAndOrderFront(nil)
        return true
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard store.isBusy else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Uma operação ainda está em andamento."
        alert.informativeText = "Aguarde a conclusão para fechar o gerenciador. Suas janelas do Codex continuarão abertas."
        alert.addButton(withTitle: "Aguardar")
        alert.runModal()
        return .terminateCancel
    }

    func buildMenus() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "MultiCodex")
        appMenu.addItem(withTitle: "Sobre o MultiCodex", action: #selector(about), keyEquivalent: "").target = self
        appMenu.addItem(withTitle: "Personalizar…", action: #selector(customize), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Ocultar MultiCodex", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Sair do MultiCodex", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let accountMenu = NSMenu(title: "Contas")
        accountMenu.addItem(withTitle: "Adicionar conta…", action: #selector(add), keyEquivalent: "n").target = self
        accountMenu.addItem(withTitle: "Atualizar contas", action: #selector(refresh), keyEquivalent: "r").target = self
        let accountItem = NSMenuItem(); accountItem.submenu = accountMenu; main.addItem(accountItem)
        let editMenu = NSMenu(title: "Editar")
        editMenu.addItem(withTitle: "Desfazer", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Refazer", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Recortar", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copiar", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Colar", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Selecionar tudo", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem(); editItem.submenu = editMenu; main.addItem(editItem)
        let windowMenu = NSMenu(title: "Janela")
        windowMenu.addItem(withTitle: "Minimizar", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Fechar", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowItem = NSMenuItem(); windowItem.submenu = windowMenu; main.addItem(windowItem)
        NSApp.windowsMenu = windowMenu
        let helpMenu = NSMenu(title: "Ajuda")
        helpMenu.addItem(withTitle: "Como funciona", action: #selector(help), keyEquivalent: "?").target = self
        let helpItem = NSMenuItem(); helpItem.submenu = helpMenu; main.addItem(helpItem)
        NSApp.mainMenu = main
    }
    @objc func add() { if store.sheet == nil { store.addAccount() } }
    @objc func refresh() { store.refresh() }
    @objc func help() { if !store.isBusy { store.sheet = .help } }
    @objc func customize() { if !store.isBusy && store.sheet == nil { store.sheet = .customize } }
    @objc func about() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "MultiCodex",
            .applicationVersion: "1.0.0 beta 3",
            .credits: NSAttributedString(string: "Interface para macOS por Coradini.\nGerenciador de perfis: am-will/multi-codex-app v0.2.1 (MIT).\nProjeto independente, sem vínculo com a OpenAI.")
        ])
    }
}

if CommandLine.arguments.contains("--self-test") {
    exit(runManagerSelfTests())
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let appDelegate = ManagerAppDelegate()
application.delegate = appDelegate
application.run()
