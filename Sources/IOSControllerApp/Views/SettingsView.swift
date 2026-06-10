import SwiftUI
import IOSControllerCore

/// Settings nativo (⌘,): chaves de API no Keychain + defaults do alvo.
struct SettingsView: View {
    @AppStorage("defaultUDID") private var udid = "booted"
    @AppStorage("defaultBundleId") private var bundleId = ""
    @AppStorage("projectDir") private var projectDir =
        NSHomeDirectory() + "/Projects/ios-controller"

    @State private var keys: [ProviderID: String] = [:]

    var body: some View {
        Form {
            Section("API keys (Keychain)") {
                ForEach(ProviderID.allCases, id: \.self) { provider in
                    SecureField(ProviderRegistry.envVar(for: provider),
                                text: binding(for: provider))
                }
                Text("Vazio = usa a variável de ambiente, se existir.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Alvo padrão") {
                TextField("Simulator UDID", text: $udid)
                TextField("Bundle ID", text: $bundleId)
                Text("Usados pelas abas de chat via API e pelos testes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Projeto") {
                TextField("Diretório do iOS Controller", text: $projectDir)
                Text("cwd do terminal embutido e raiz do start-wda.sh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .onAppear {
            for provider in ProviderID.allCases {
                keys[provider] = Keychain.load(account: provider.rawValue)
            }
        }
    }

    private func binding(for provider: ProviderID) -> Binding<String> {
        Binding(
            get: { keys[provider] ?? "" },
            set: { value in
                keys[provider] = value
                Keychain.save(value, account: provider.rawValue)
            })
    }
}

#Preview {
    SettingsView()
}
