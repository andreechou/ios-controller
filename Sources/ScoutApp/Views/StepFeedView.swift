import SwiftUI
import ScoutCore

struct StepFeedView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FEED").font(Theme.monoSmall).foregroundStyle(Theme.muted).padding(12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(state.steps) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(row.index)").foregroundStyle(Theme.accent)
                                if let ok = row.ok {
                                    Image(systemName: ok ? "checkmark" : "xmark")
                                        .foregroundStyle(ok ? Theme.success : Theme.danger)
                                }
                            }.font(Theme.monoSmall)
                            Text(row.reasoning).font(Theme.monoSmall)
                            if let action = row.action {
                                Text(action).font(Theme.monoSmall).foregroundStyle(Theme.muted)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }.padding(12)
            }

            if !state.friction.isEmpty {
                Divider().overlay(Theme.border)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FRICÇÃO (\(state.friction.count))")
                        .font(Theme.monoSmall).foregroundStyle(Theme.danger)
                    ForEach(state.friction, id: \.self) { f in
                        Text("• \(f)").font(Theme.monoSmall).foregroundStyle(Theme.text)
                    }
                }.padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
    }
}
