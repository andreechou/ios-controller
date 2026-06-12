import SwiftUI

/// Settings nativo (⌘,): alvo padrão do simulador + diretório do projeto.
struct SettingsView: View {
    @AppStorage("defaultUDID") private var udid = "booted"
    @AppStorage("defaultBundleId") private var bundleId = ""
    @AppStorage("projectDir") private var projectDir =
        NSHomeDirectory() + "/Projects/ios-controller"

    var body: some View {
        Form {
            Section("Alvo padrão") {
                TextField("Simulator UDID", text: $udid)
                TextField("Bundle ID", text: $bundleId)
                Text("Usados pelo screenshot, gravação e Atlas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Projeto") {
                TextField("Diretório do iOS Controller", text: $projectDir)
                Text("Raiz do scripts/start-wda.sh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
    }
}

#Preview {
    SettingsView()
}
