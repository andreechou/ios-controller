import SwiftUI
import IOSControllerCore

/// Live feed of the agent's steps + accumulated friction. Native List.
struct StepFeedView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        List {
            Section("Steps") {
                if state.steps.isEmpty {
                    Text("No steps yet").foregroundStyle(.secondary)
                }
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
        .navigationTitle("Feed")
    }
}
