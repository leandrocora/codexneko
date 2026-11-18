import AppKit
import SwiftUI

enum MascotVariant: String, CaseIterable, Identifiable {
    case male, female
    static let preferenceKey = "mascot.variant"
    var id: String { rawValue }
    var title: String { self == .male ? "Macho" : "Fêmea" }
    var subtitle: String { self == .male ? "Robô azul · padrão" : "Robô rosa · laço metálico" }
    var mascotResource: String { self == .male ? "CatMale" : "CatFemale" }
    var iconResource: String { self == .male ? "AppIconMale" : "AppIconFemale" }
    var highlight: Color { self == .male ? AppTheme.accent : Color(red: 1, green: 0.50, blue: 0.59) }

    static func saved(in defaults: UserDefaults = .standard) -> MascotVariant {
        defaults.string(forKey: preferenceKey).flatMap(MascotVariant.init(rawValue:)) ?? .male
    }

    func image(icon: Bool = false) -> NSImage? {
        guard let url = Bundle.main.url(forResource: icon ? iconResource : mascotResource, withExtension: "png", subdirectory: "BrandAssets") else { return nil }
        return NSImage(contentsOf: url)
    }
}

struct AccountMascot: View {
    var variant: MascotVariant = .male
    var body: some View {
        Group {
            if let image = variant.image() {
                Image(nsImage: image).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "cat.fill").resizable().scaledToFit().foregroundColor(.white)
            }
        }
        .accessibilityLabel("Gato robô branco dormindo, luzes vermelhas, \(variant.title.lowercased())")
    }
}

private typealias MascotViewState<Value> = SwiftUI.State<Value>

struct MascotPickerView: View {
    @ObservedObject var store: AccountStore
    @MascotViewState private var selection: MascotVariant

    init(store: AccountStore) {
        self.store = store
        _selection = State(initialValue: store.mascotVariant)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Do seu jeito.").font(.system(size: 29, weight: .bold)).tracking(-0.7)
                Spacer()
                Button { store.sheet = nil } label: { Image(systemName: "xmark.circle.fill").font(.system(size: 21)).foregroundColor(AppTheme.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Fechar personalização")
            }
            Text("Escolha quem vai cuidar das suas contas.")
                .font(.system(size: 13)).foregroundColor(AppTheme.secondary).padding(.top, 9).padding(.bottom, 25)
            HStack(spacing: 15) {
                ForEach(MascotVariant.allCases) { variant in
                    Button { selection = variant } label: {
                        VStack(spacing: 10) {
                            AccountMascot(variant: variant).frame(width: 165, height: 112)
                            HStack(spacing: 7) {
                                Image(systemName: selection == variant ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selection == variant ? variant.highlight : AppTheme.secondary)
                                Text(variant.title).font(.system(size: 16, weight: .semibold))
                            }
                            Text(variant.subtitle).font(.system(size: 10)).foregroundColor(AppTheme.secondary)
                        }
                        .padding(.vertical, 21).frame(maxWidth: .infinity)
                        .background(selection == variant ? variant.highlight.opacity(0.08) : AppTheme.surface, in: RoundedRectangle(cornerRadius: 19))
                        .overlay(RoundedRectangle(cornerRadius: 19).strokeBorder(selection == variant ? variant.highlight : AppTheme.outline, lineWidth: selection == variant ? 1.7 : 1))
                        .contentShape(RoundedRectangle(cornerRadius: 19))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Mascote \(variant.title.lowercased())")
                    .accessibilityValue(selection == variant ? "Selecionado" : "Não selecionado")
                }
            }
            HStack(spacing: 9) {
                Image(systemName: "dock.rectangle").foregroundColor(AppTheme.accent)
                Text("O mascote do app e o ícone no Dock acompanham sua escolha.")
                    .font(.system(size: 11)).foregroundColor(AppTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 19)
            Divider().padding(.top, 23).padding(.bottom, 20)
            HStack {
                Button("Cancelar") { store.sheet = nil }.buttonStyle(.plain).foregroundColor(AppTheme.secondary).keyboardShortcut(.cancelAction)
                Spacer()
                Button { store.setMascot(selection); store.sheet = nil } label: { Label("Salvar escolha", systemImage: "checkmark") }
                    .buttonStyle(PrimaryButtonStyle()).keyboardShortcut(.defaultAction)
            }
        }
        .padding(30).frame(width: 464)
        .background(AppTheme.background).foregroundColor(AppTheme.text)
        .preferredColorScheme(.dark)
    }
}
