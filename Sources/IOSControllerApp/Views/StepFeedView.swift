import SwiftUI
import AppKit
import IOSControllerCore

/// Live feed of the agent's steps + accumulated friction. Native List.
struct StepFeedView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Group {
            if state.steps.isEmpty && state.friction.isEmpty {
                ContentUnavailableView {
                    Label("Sem passos ainda", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("Dirija o simulador (wda.sh / MCP / Claude) — cada ação aparece aqui.")
                }
            } else {
                feed
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var feed: some View {
        List {
            Section("Steps") {
                ForEach(state.steps) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("#\(row.index)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            if let ok = row.ok {
                                Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(ok ? .green : .red)
                            }
                        }
                        Text(row.reasoning).font(.callout)
                        if let action = row.action {
                            Text(action).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        if let path = row.imagePath, let img = NSImage(contentsOfFile: path) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .onTapGesture {
                                    NSWorkspace.shared.open(URL(fileURLWithPath: path))
                                }
                                .help("Clique pra abrir em tamanho real")
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if !state.friction.isEmpty {
                Section("Friction (\(state.friction.count))") {
                    ForEach(state.friction, id: \.self) { f in
                        Label(f, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
    }
}
