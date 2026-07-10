import SwiftUI

/// Orquestación de agentes: tronco secuencial → abanico paralelo → convergencia.
struct OrchestrationView: View {
    @Bindable var session: ChangeSession

    private static let canvasSize = CGSize(width: 820, height: 330)
    private static let nodeSize = CGSize(width: 156, height: 64)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            head
            legend

            GeometryReader { geo in
                let scale = min(geo.size.width / Self.canvasSize.width,
                                geo.size.height / Self.canvasSize.height,
                                1.25)
                diagram
                    .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
                    .scaleEffect(scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.background.secondary.opacity(0.5), in: .rect(cornerRadius: FoldMetrics.cardRadius))
        }
    }

    private var head: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agentes en convergencia")
                    .font(.headline)
                Text("\(session.orchClosedCount)/3 ramas cerradas · \(mergeDone ? String(localized: "listo para mergear") : String(localized: "esperando para mergear"))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                session.orchAdvance()
            } label: {
                Label(
                    session.orchStep == 2 ? String(localized: "reiniciar") : String(localized: "simular avance"),
                    systemImage: session.orchStep == 2 ? "arrow.counterclockwise" : "play.fill"
                )
            }
            .buttonStyle(.glass)
        }
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .foldSuccess, label: String(localized: "cerrada"))
            legendItem(color: .foldInfo, label: String(localized: "trabajando"))
            legendItem(color: .gray, label: String(localized: "en cola"))
            Spacer()
            Text("tronco secuencial → abanico paralelo → convergencia")
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var mergeDone: Bool {
        session.orchNodes.first(where: { $0.id == "merge" })?.status == .done
    }

    // MARK: - Diagrama

    private static let edges: [(from: String, to: String)] = [
        ("1.1", "1.2"),
        ("1.2", "1.3"), ("1.2", "2.1"), ("1.2", "2.2"),
        ("1.3", "merge"), ("2.1", "merge"), ("2.2", "merge"),
    ]

    private var diagram: some View {
        ZStack {
            Canvas { context, _ in
                for edge in Self.edges {
                    guard let from = node(edge.from), let to = node(edge.to) else { continue }
                    var path = Path()
                    let isVertical = from.column == to.column
                    let start: CGPoint
                    let end: CGPoint
                    if isVertical {
                        start = CGPoint(x: from.position.x, y: from.position.y + Self.nodeSize.height / 2)
                        end = CGPoint(x: to.position.x, y: to.position.y - Self.nodeSize.height / 2)
                    } else {
                        start = CGPoint(x: from.position.x + Self.nodeSize.width / 2, y: from.position.y)
                        end = CGPoint(x: to.position.x - Self.nodeSize.width / 2, y: to.position.y)
                    }
                    path.move(to: start)
                    if isVertical {
                        path.addLine(to: end)
                    } else {
                        let midX = (start.x + end.x) / 2
                        path.addCurve(
                            to: end,
                            control1: CGPoint(x: midX, y: start.y),
                            control2: CGPoint(x: midX, y: end.y)
                        )
                    }
                    let color = edgeColor(to: to)
                    context.stroke(
                        path,
                        with: .color(color.opacity(0.65)),
                        style: StrokeStyle(lineWidth: 1.5, dash: to.status == .pending ? [4, 4] : [])
                    )
                }
            }

            ForEach(session.orchNodes) { node in
                OrchNodeView(node: node, isMergeReady: mergeDone)
                    .frame(width: Self.nodeSize.width, height: Self.nodeSize.height)
                    .position(node.position)
            }
        }
    }

    private func node(_ id: String) -> OrchNode? {
        session.orchNodes.first { $0.id == id }
    }

    private func edgeColor(to node: OrchNode) -> Color {
        switch node.status {
        case .done: .foldSuccess
        case .running: .foldInfo
        case .pending: .gray
        }
    }
}

private struct OrchNodeView: View {
    let node: OrchNode
    let isMergeReady: Bool

    private var tint: Color {
        switch node.status {
        case .done: .foldSuccess
        case .running: .foldInfo
        case .pending: .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(node.agentLabel)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)

            if node.column == .merge {
                Text(node.taskLabel)
                    .font(.callout.weight(.semibold))
                Text(isMergeReady ? "✓ listo" : "espera")
                    .font(.caption2.monospaced())
                    .foregroundStyle(isMergeReady ? Color.foldSuccess : .secondary)
            } else {
                Text(node.taskLabel)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)

                Capsule()
                    .fill(tint.opacity(0.8))
                    .frame(width: progressWidth, height: 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Capsule().fill(.quaternary.opacity(0.5)))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background, in: .rect(cornerRadius: 10))
        .overlay {
            if node.column == .merge {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        (isMergeReady ? Color.foldSuccess : Color.gray).opacity(0.6),
                        style: StrokeStyle(lineWidth: 1.5, dash: isMergeReady ? [] : [5, 4])
                    )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(tint.opacity(0.55), lineWidth: 1.5)
            }
        }
        .animation(.spring(duration: 0.5), value: node.status)
    }

    private var progressWidth: CGFloat {
        switch node.status {
        case .done: 128
        case .running: 72
        case .pending: 18
        }
    }
}
