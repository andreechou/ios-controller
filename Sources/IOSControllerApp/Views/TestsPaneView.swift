import SwiftUI
import IOSControllerCore

/// Painel direito: Steps (feed ao vivo) | Tests (testes declarados, criar/rodar).
struct TestsPaneView: View {
    @Environment(AppState.self) private var state
    @AppStorage("rightTab") private var rightTab = RightTab.steps
    @State private var store = TestStore()
    @State private var editing: TestCase?

    enum RightTab: String {
        case steps, tests
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Painel", selection: $rightTab) {
                Text("Steps").tag(RightTab.steps)
                Text("Tests").tag(RightTab.tests)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(8)

            switch rightTab {
            case .steps:
                StepFeedView()
            case .tests:
                testsList
            }
        }
        .sheet(item: $editing) { test in
            TestEditorView(test: test) { saved in
                store.upsert(saved)
            } onDelete: { id in
                store.remove(id)
            }
        }
    }

    private var testsList: some View {
        VStack(spacing: 0) {
            if store.tests.isEmpty {
                ContentUnavailableView {
                    Label("Nenhum teste", systemImage: "checklist")
                } description: {
                    Text("Crie um teste com objetivo + persona e rode com o provider que quiser.")
                } actions: {
                    Button("Novo teste") { editing = TestCase() }
                }
                .frame(maxHeight: .infinity)
            } else {
                List(store.tests) { test in
                    row(test)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = test }
                }
                .listStyle(.inset)

                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(height: 1)
                HStack {
                    Button {
                        editing = TestCase()
                    } label: {
                        Label("Novo teste", systemImage: "plus")
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func row(_ test: TestCase) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(test.name).font(.callout.weight(.medium))
                Text(test.goal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\(test.provider.rawValue) · \(test.bundleId)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            Spacer()
            Button {
                run(test)
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .disabled(state.isRunning)
            .help("Roda este teste no loop interno (API)")
        }
        .padding(.vertical, 2)
    }

    private func run(_ test: TestCase) {
        let udid = UserDefaults.standard.string(forKey: "defaultUDID") ?? "booted"
        state.start(
            config: RunConfig(
                goal: test.goal, persona: test.persona, udid: udid,
                bundleId: test.bundleId, provider: test.provider,
                model: ProviderRegistry.defaultModel(for: test.provider),
                maxSteps: test.maxSteps),
            apiKey: Keychain.load(account: test.provider.rawValue))
        rightTab = .steps   // acompanha o run ao vivo
    }
}

/// Editor de um teste (sheet). Salva no TestStore; chaves ficam no Settings.
struct TestEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var test: TestCase
    var onSave: (TestCase) -> Void
    var onDelete: (TestCase.ID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Teste") {
                    TextField("Nome", text: $test.name)
                    TextField("Objetivo", text: $test.goal, axis: .vertical)
                        .lineLimit(2...5)
                    TextField("Persona", text: $test.persona, axis: .vertical)
                        .lineLimit(1...3)
                }
                Section("Alvo") {
                    TextField("Bundle ID", text: $test.bundleId)
                    Stepper("Máx. de passos: \(test.maxSteps)", value: $test.maxSteps, in: 5...120, step: 5)
                }
                Section("Cérebro") {
                    Picker("Provider", selection: $test.provider) {
                        ForEach(ProviderID.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Button(role: .destructive) {
                    onDelete(test.id)
                    dismiss()
                } label: {
                    Text("Apagar")
                }
                Spacer()
                Button("Cancelar") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Salvar") {
                    onSave(test)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(test.goal.isEmpty || test.bundleId.isEmpty)
            }
            .padding(12)
        }
        .frame(width: 440, height: 460)
    }
}
