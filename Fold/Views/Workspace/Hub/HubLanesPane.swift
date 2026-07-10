import SwiftUI

/// Tab "Ramas en curso": carriles con el estado de cada change activo.
struct HubLanesPane: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 10) {
            if appState.isRealProject {
                if realLanes.isEmpty {
                    Text("No hay changes en curso. Empieza explorando o proponiendo un cambio desde la tab Hacer.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(realLanes) { item in
                        LaneRow(lane: item.lane) { _ in
                            appState.openChange(id: item.changeID)
                        }
                    }
                }
            } else {
                ForEach(SampleData.workLanes) { lane in
                    LaneRow(lane: lane) { actionLabel in
                        if actionLabel == String(localized: "Abrir change") {
                            appState.openChange(id: SampleData.addAppleLogin.id)
                        } else {
                            appState.toasts.show(actionLabel)
                        }
                    }
                }
            }
        }
    }

    private struct RealLane: Identifiable {
        let id: String
        let changeID: String
        let lane: WorkLane
    }

    private var realLanes: [RealLane] {
        (appState.openSpecState?.changes ?? []).map { info in
            let done = info.tasks.filter(\.done).count
            let total = info.tasks.count
            let status: WorkLane.Status = (total > 0 && done == total) ? .readyToMerge : .needsRevision
            return RealLane(
                id: info.id,
                changeID: info.id,
                lane: WorkLane(
                    status: status,
                    name: info.id,
                    taskInfo: total == 0
                        ? String(localized: "sin tasks definidas")
                        : String(localized: "\(done)/\(total) tasks hechas"),
                    agentInfo: info.title,
                    actions: [String(localized: "Abrir change")]
                )
            )
        }
    }
}

private struct LaneRow: View {
    let lane: WorkLane
    let perform: (String) -> Void

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 2)
                .fill(lane.status.tint)
                .frame(width: 3, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(lane.name)
                        .font(.body.weight(.semibold).monospaced())
                    Text(lane.status.label)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(lane.status.tint.opacity(0.14), in: .capsule)
                        .foregroundStyle(lane.status.tint)
                }
                Text("\(lane.taskInfo) · \(lane.agentInfo)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                ForEach(Array(lane.actions.enumerated()), id: \.offset) { index, action in
                    Button(action) { perform(action) }
                        .buttonStyle(.glass)
                        .controlSize(.small)
                        .tint(index == 0 ? lane.status.tint : nil)
                }
            }
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
    }
}
