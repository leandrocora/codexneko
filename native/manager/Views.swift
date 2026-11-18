import AppKit
import SwiftUI

// Select the property wrapper explicitly for compatibility with newer Swift SDKs.
private typealias ViewState<Value> = SwiftUI.State<Value>
private let accent = AppTheme.accent
private let mint = AppTheme.accent
private let canvas = AppTheme.background
private let ink = AppTheme.text

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 13 : 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 17 : 20)
            .frame(height: compact ? 37 : 42)
            .background(AppTheme.action.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(Capsule())
    }
}

struct ProfileIcon: View {
    let color: AccountColor
    let root: URL
    var size: CGFloat = 48
    var body: some View {
        Group {
            if let image = NSImage(contentsOf: root.appendingPathComponent("icons/" + color.rawValue + ".png")) ??
                Bundle.main.url(forResource: color.rawValue, withExtension: "png", subdirectory: "ProfileIcons").flatMap({ NSImage(contentsOf: $0) }) {
                Image(nsImage: image).resizable().interpolation(.high)
            } else {
                ZStack {
                    Color(nsColor: color.color)
                    Image(systemName: "person.crop.rectangle").font(.system(size: size * 0.48)).foregroundColor(color == .white || color == .yellow ? AppTheme.darkInk : .white)
                }
            }
        }
        .frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.23))
        .overlay(RoundedRectangle(cornerRadius: size * 0.23).strokeBorder(AppTheme.outline))
        .accessibilityLabel("Ícone \(color.title)")
    }
}

struct AccountEditor: View {
    @ObservedObject var store: AccountStore
    let profile: AccountProfile?
    @ViewState private var name: String
    @ViewState private var color: AccountColor
    @ViewState private var validation = ""
    @FocusState private var nameFocused: Bool

    init(store: AccountStore, profile: AccountProfile?) {
        self.store = store
        self.profile = profile
        _name = State(initialValue: profile?.displayName ?? store.suggestedName)
        let next = (store.snapshot.profiles + store.snapshot.archived).compactMap { Int($0.id) }.max() ?? 1
        _color = State(initialValue: profile?.color ?? AccountColor.allCases[next % AccountColor.allCases.count])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                ProfileIcon(color: color, root: store.backend.root, size: 64)
                Spacer()
                Button { store.sheet = nil } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 21)).foregroundColor(.secondary.opacity(0.5)) }
                    .buttonStyle(.plain).accessibilityLabel("Fechar")
            }
            .padding(.bottom, 24)
            Text(profile == nil ? "Uma nova conta.\nUma nova janela." : "Do seu jeito.")
                .font(.system(size: 29, weight: .semibold)).tracking(-0.9).fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 11)
            Text(profile == nil ? "Escolha um nome e uma cor. Depois, entre com a outra conta na janela do Codex que abrir." : "Use um nome e uma cor para reconhecer esta conta.")
                .font(.system(size: 12)).foregroundColor(.secondary).lineSpacing(4).fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 27)
            Text("NOME DA CONTA").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundColor(.secondary).padding(.bottom, 9)
            TextField("Ex.: Pessoal, Trabalho, Projeto…", text: $name)
                .font(.system(size: 14)).textFieldStyle(.plain).padding(13)
                .background(AppTheme.field, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(accent.opacity(nameFocused ? 0.5 : 0.15)))
                .focused($nameFocused).onSubmit(save)
                .accessibilityLabel("Nome da conta")
                .onChange(of: name) { _ in validation = "" }
            Text(validation.isEmpty ? "Um apelido para identificar a conta. Você fará o login depois." : validation)
                .font(.system(size: 10)).foregroundColor(validation.isEmpty ? .secondary : .red)
                .fixedSize(horizontal: false, vertical: true).padding(.top, 8).frame(minHeight: 30, alignment: .topLeading)
            Text("COR DO ÍCONE").font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundColor(.secondary).padding(.top, 16).padding(.bottom, 12)
            HStack(spacing: 15) {
                ForEach(AccountColor.allCases) { value in
                    Button { color = value } label: {
                        Circle().fill(Color(nsColor: value.color)).frame(width: 31, height: 31)
                            .overlay(Circle().strokeBorder(.white.opacity(0.16)))
                            .padding(4)
                            .overlay(Circle().strokeBorder(color == value ? accent : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain).accessibilityLabel(value.title).accessibilityValue(color == value ? "Selecionada" : "")
                    .help(value.title)
                }
                Spacer()
            }
            Divider().padding(.top, 26).padding(.bottom, 20)
            HStack {
                Button("Cancelar") { store.sheet = nil }.keyboardShortcut(.cancelAction).buttonStyle(.plain).foregroundColor(.secondary)
                Spacer()
                Button(action: save) { Label(profile == nil ? "Criar e abrir" : "Salvar alterações", systemImage: profile == nil ? "plus" : "checkmark") }
                    .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(32)
        .frame(width: 424)
        .background(canvas)
        .foregroundColor(ink)
        .onAppear { nameFocused = true }
    }

    private func save() {
        do {
            let value = try validatedName(name, profiles: store.snapshot.profiles, excluding: profile?.id)
            if let profile = profile { store.edit(profile, name: value, color: color) }
            else { store.create(name: value, color: color) }
        } catch { validation = error.localizedDescription }
    }
}

struct HelpView: View {
    @ObservedObject var store: AccountStore
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Uma conta em cada janela.").font(.system(size: 25, weight: .semibold)).tracking(-0.6)
            instruction("1", "Adicione uma conta", "Clique em Adicionar conta, escolha um nome e uma cor e confirme em Criar e abrir.")
            instruction("2", "Entre na nova janela", "Use o login da outra conta no Codex. O MultiCodex não pede sua senha.")
            instruction("3", "Abra quando precisar", "Volte aqui e clique em Abrir ou Mostrar. As janelas podem ficar abertas ao mesmo tempo.")
            Text("Os perfis existentes são reconhecidos automaticamente. Fechar o MultiCodex não fecha suas janelas do Codex.")
                .font(.system(size: 12)).foregroundColor(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Menu("Manutenção") {
                    Button("Verificar instalação", action: store.diagnostics)
                    Button("Reparar instalação", action: store.repair).disabled(store.snapshot.configuration == nil)
                    Button("Mostrar aplicativos no Finder") {
                        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications"))
                    }
                }.fixedSize()
                Spacer()
                Button("Entendi") { store.sheet = nil }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }
        .padding(32).frame(width: 460).background(canvas).foregroundColor(ink)
    }
    private func instruction(_ number: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number).font(.system(size: 12, weight: .semibold)).foregroundColor(accent)
                .frame(width: 28, height: 28).background(mint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(text).font(.system(size: 12)).foregroundColor(.secondary).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct DiagnosticsView: View {
    @ObservedObject var store: AccountStore
    let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Verificação da instalação").font(.system(size: 23, weight: .semibold))
            ScrollView { Text(text).font(.system(size: 11, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(15) }
                .frame(height: 240).background(AppTheme.field, in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button("Reparar instalação", action: store.repair).disabled(store.snapshot.configuration == nil)
                Spacer()
                Button("Fechar") { store.sheet = nil }.buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }
        .padding(30).frame(width: 510).background(canvas).foregroundColor(ink)
    }
}
