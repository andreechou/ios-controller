import SwiftUI
import ScoutCore

/// Painel de configuração — Form nativo (estilo System Settings).
struct RunConfigView: View {
    @Environment(AppState.self) private var state

    @State private var goal = "Cadastrar e criar minha primeira lista"
    @State private var persona = "Usuário de primeira viagem, nunca viu o app"
    @State private var udid = "booted"
    @State private var bundleId = "design.chou.carretel.ios"
    @State private var provider: ProviderID = .anthropic
    @State private var apiKey = ""

    var body: some View {
        Form {
            Section("Teste") {
                TextField("Objetivo", text: $goal, axis: .vertical).lineLimit(2...5)
                TextField("Persona", text: $persona, axis: .vertical).lineLimit(1...3)
            }

            Section("Alvo") {
                TextField("Simulator UDID", text: $udid)
                TextField("Bundle ID", text: $bundleId)
            }

            Section("Modelo") {
                Picker("Provider", selection: $provider) {
                    ForEach(ProviderID.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                SecureField("API key", text: $apiKey)
            }

            Section {
                Button {
                    state.start(config: RunConfig(
                        goal: goal, persona: persona, udid: udid, bundleId: bundleId,
                        provider: provider,
                        model: ProviderRegistry.defaultModel(for: provider)),
                        apiKey: apiKey)
                } label: {
                    Label(state.isRunning ? "Rodando…" : "Iniciar run", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.isRunning || udid.isEmpty || bundleId.isEmpty)

                Button {
                    state.startPreview(udid: udid)
                } label: {
                    Label("Espelhar simulador", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                }
                .disabled(udid.isEmpty)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Scout")
        .onAppear {
            state.startPreview(udid: udid)
            apiKey = Keychain.load(account: provider.rawValue)
        }
        .onChange(of: provider) { _, p in apiKey = Keychain.load(account: p.rawValue) }
        .onChange(of: apiKey) { _, k in Keychain.save(k, account: provider.rawValue) }
    }
}
