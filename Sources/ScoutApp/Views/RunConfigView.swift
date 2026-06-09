import SwiftUI
import ScoutCore

/// Config panel — native Form (System Settings style).
struct RunConfigView: View {
    @Environment(AppState.self) private var state

    @State private var goal = "Sign up and create my first list"
    @State private var persona = "First-time user, has never seen the app"
    @State private var udid = "booted"
    @State private var bundleId = "design.chou.carretel.ios"
    @State private var provider: ProviderID = .anthropic
    @State private var apiKey = ""

    var body: some View {
        Form {
            Section("Test") {
                TextField("Goal", text: $goal, axis: .vertical).lineLimit(2...5)
                TextField("Persona", text: $persona, axis: .vertical).lineLimit(1...3)
            }

            Section("Target") {
                TextField("Simulator UDID", text: $udid)
                TextField("Bundle ID", text: $bundleId)
            }

            Section("Model") {
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
                    Label(state.isRunning ? "Running…" : "Start run", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.isRunning || udid.isEmpty || bundleId.isEmpty)

                Button {
                    state.startPreview(udid: udid)
                } label: {
                    Label("Mirror simulator", systemImage: "eye")
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
