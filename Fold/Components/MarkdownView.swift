import SwiftUI

/// Render sencillo de markdown por bloques: headings, párrafos, bullets,
/// código, blockquotes y tablas (en mono). Markdown es la verdad; esto es la traducción.
struct MarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(MarkdownBlock.parse(markdown)) { block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.kind {
        case .heading(let level, let text):
            Text(inline(text))
                .font(headingFont(level))
                .padding(.top, level == 1 ? 0 : 4)
        case .paragraph(let text):
            Text(inline(text))
                .font(.body)
                .lineSpacing(3)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("·").foregroundStyle(.secondary)
                        Text(inline(item)).font(.body)
                    }
                }
            }
        case .code(let text):
            Text(text)
                .font(.callout.monospaced())
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.45), in: .rect(cornerRadius: 8))
        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.foldAction.opacity(0.6))
                    .frame(width: 3)
                Text(inline(text))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        case .table(let rows):
            tableView(rows)
        }
    }

    /// Tabla markdown renderizada como Grid real (cabecera + filas).
    private func tableView(_ rows: [String]) -> some View {
        let parsed = rows.map { row in
            row.split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }.filter { !$0.isEmpty }

        return Grid(alignment: .topLeading, horizontalSpacing: 14, verticalSpacing: 6) {
            ForEach(Array(parsed.enumerated()), id: \.offset) { rowIndex, cells in
                GridRow {
                    ForEach(Array(cells.enumerated()), id: \.offset) { _, cell in
                        Text(inline(cell))
                            .font(rowIndex == 0 ? .caption.weight(.semibold) : .caption)
                            .foregroundStyle(rowIndex == 0 ? .primary : .secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .gridColumnAlignment(.leading)
                    }
                }
                if rowIndex == 0 {
                    Divider()
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 8))
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title2.weight(.semibold)
        case 2: .title3.weight(.semibold)
        default: .headline
        }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

/// Bloque parseado de markdown.
struct MarkdownBlock: Identifiable {
    enum Kind {
        case heading(Int, String)
        case paragraph(String)
        case bullets([String])
        case code(String)
        case quote(String)
        case table([String])
    }

    let id: Int
    let kind: Kind

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [Kind] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var table: [String] = []
        var codeLines: [String] = []
        var inCode = false

        func flushParagraph() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph = []
            }
        }
        func flushBullets() {
            if !bullets.isEmpty {
                blocks.append(.bullets(bullets))
                bullets = []
            }
        }
        func flushTable() {
            if !table.isEmpty {
                blocks.append(.table(table))
                table = []
            }
        }
        func flushAll() {
            flushParagraph()
            flushBullets()
            flushTable()
        }

        for rawLine in markdown.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                } else {
                    flushAll()
                    inCode = true
                }
                continue
            }
            if inCode {
                codeLines.append(rawLine)
                continue
            }
            if line.isEmpty {
                flushAll()
                continue
            }
            if line.hasPrefix("#") {
                flushAll()
                let level = line.prefix(while: { $0 == "#" }).count
                let text = line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
                blocks.append(.heading(min(level, 3), text))
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flushParagraph()
                flushTable()
                bullets.append(String(line.dropFirst(2)))
                continue
            }
            if line.hasPrefix("> ") {
                flushAll()
                blocks.append(.quote(String(line.dropFirst(2))))
                continue
            }
            if line.hasPrefix("|") {
                flushParagraph()
                flushBullets()
                // Saltar la fila separadora |---|---|
                if !line.replacingOccurrences(of: "|", with: "")
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: ":", with: "")
                    .trimmingCharacters(in: .whitespaces).isEmpty || line.contains(where: \.isLetter) {
                    table.append(line)
                }
                continue
            }
            paragraph.append(line)
        }
        if inCode, !codeLines.isEmpty {
            blocks.append(.code(codeLines.joined(separator: "\n")))
        }
        flushAll()

        return blocks.enumerated().map { MarkdownBlock(id: $0.offset, kind: $0.element) }
    }
}
