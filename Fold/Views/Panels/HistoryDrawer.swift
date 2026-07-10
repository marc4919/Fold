import SwiftUI

/// Drawer de historia: timeline del change por etapas, en el inspector.
struct HistoryDrawer: View {
    let session: ChangeSession

    /// Real: timeline persistido en history.json; demo: datos de ejemplo.
    private var stages: [HistoryStage] {
        session.isReal ? session.realHistoryStages : session.change.historyStages
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Historia del change")
                        .font(.headline)
                    Text("\(session.change.id) · \(session.change.createdLabel)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 14) {
                    legendItem(.human)
                    legendItem(.agent)
                    legendItem(.system)
                }

                if stages.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("Todavía no hay historia: los eventos se registran a medida que exploras, planificas y el agente trabaja.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }

                ForEach(stages) { stage in
                    CollapsibleLane(
                        iconLetter: String(stage.name.prefix(1)),
                        iconTint: .foldInfo,
                        title: stage.name,
                        countLabel: stage.durationLabel,
                        startsExpanded: stage.id == stages.first?.id
                    ) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(stage.events) { event in
                                eventRow(event, isLast: event.id == stage.events.last?.id)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
    }

    private func legendItem(_ actor: HistoryEvent.Actor) -> some View {
        HStack(spacing: 5) {
            Circle().fill(actor.tint).frame(width: 7, height: 7)
            Text(actor.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func eventRow(_ event: HistoryEvent, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(event.timeLabel)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
                .frame(width: 38, alignment: .trailing)

            VStack(spacing: 0) {
                Circle()
                    .fill(event.actor.tint)
                    .frame(width: 7, height: 7)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(event.actor.tint.opacity(0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    // Quién hizo qué, de un vistazo: el actor lleva su color.
                    Text(event.actor.label)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(event.actor.tint.opacity(0.16), in: .capsule)
                        .foregroundStyle(event.actor.tint)
                    Text(LocalizedStringKey(event.text))
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let detail = event.detail {
                    Text(detail)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(event.actor.tint.opacity(0.07), in: .rect(cornerRadius: 5))
                        .lineLimit(3)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(event.actor.tint.opacity(0.05), in: .rect(cornerRadius: 8))
            .padding(.bottom, isLast ? 0 : 10)

            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
