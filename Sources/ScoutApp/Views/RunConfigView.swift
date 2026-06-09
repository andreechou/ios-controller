import SwiftUI
import ScoutCore

struct RunConfigView: View {
    @Environment(AppState.self) private var state

    @State private var goal = "Cadastrar e criar minha primeira lista"
    @State private var persona = "Usuário de primeira viagem, nunca viu o app"
    @State private var udid = "booted"
    @State private var bundleId = ""
    @State private var provider: ProviderID = .anthropic
    @State private var apiKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("scout").font(.title2).bold().foregroundStyle(Theme.accent)
            Text("teste de usuário dirigido por IA")
                .font(Theme.monoSmall).foregroundStyle(Theme.muted)

            field("OBJETIVO") { TextEditor(text: $goal).frame(height: 60) }
            field("PERSONA") { TextEditor(text: $persona).frame(height: 50) }
            field("SIMULATOR UDID") { TextField("booted", text: $udid) }
            field("BUNDLE ID") { TextField("com.exemplo.app", text: $bundleId) }
            field("PROVIDER") {
                Picker("", selection: $provider) {
                    ForEach(ProviderID.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.labelsHidden()
            }
            field("API KEY · \(provider.rawValue)") {
                SecureField("sk-… (vazio = usa env)", text: $apiKey)
            }

            Button(state.isRunning ? "rodando…" : "▶ iniciar run") {
                state.start(config: RunConfig(
                    goal: goal, persona: persona, udid: udid, bundleId: bundleId,
                    provider: provider,
                    model: ProviderRegistry.defaultModel(for: provider)),
                    apiKey: apiKey)
            }
            .disabled(state.isRunning || udid.isEmpty || bundleId.isEmpty)
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)

            Button("👁 espelhar simulador") { state.startPreview(udid: udid) }
                .disabled(udid.isEmpty)
                .buttonStyle(.bordered)

            Spacer()
        }
        .padding(16)
        .background(Theme.surface)
        .onAppear {
            state.startPreview(udid: udid)
            apiKey = Keychain.load(account: provider.rawValue)
        }
        .onChange(of: provider) { _, p in apiKey = Keychain.load(account: p.rawValue) }
        .onChange(of: apiKey) { _, k in Keychain.save(k, account: provider.rawValue) }
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(Theme.monoSmall).foregroundStyle(Theme.muted)
            content().textFieldStyle(.roundedBorder).font(Theme.monoSmall)
        }
    }
}
