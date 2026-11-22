import SetzerSyntax

extension MarkdownParser {
    internal func parseInlines(_ document: Document) -> Document {
        var references: [ReferenceLabel: InlineParser.Reference] = [:]
        for node in document.nodes {
            if case .referenceDefinition(let definition) = node.data {
                let key = InlineDecoding.label(definition.rawLabel)
                if let previous = references[key], previous.sourceOffset <= node.range.lowerBound { continue }
                references[key] = InlineParser.Reference(sourceOffset: node.range.lowerBound,
                        destination: InlineDecoding.decode(definition.rawDestination),
                        title: definition.rawTitle.map { InlineDecoding.decode($0) })
            }
        }
        var triggers = ByteSet()
        for active in resolvedInlineRules { triggers.insert(active.rule.trigger) }
        let preparedRules = resolvedInlineRules.map { active in
            var prepared = active
            prepared.matcher = active.rule.prepare?(document) ?? active.rule.match
            return prepared
        }
        let inlineRules = Dictionary(grouping: preparedRules, by: { $0.rule.trigger })
        var builder = DocumentBuilder(source: document.source, collectSyntaxDetails: document.tokens != nil)
        builder.reserveCapacity(document.nodes.count * 3)
        for diagnostic in document.diagnostics { builder.report(diagnostic) }
        var mapped = [Int](repeating: -1, count: document.nodes.count)
        mapped[0] = 0
        var inline = InlineParser(input: InlineInput(), references: references, collectSyntax: collectSyntaxDetails,
                                  source: document.source, rules: inlineRules, triggers: triggers, maximumDepth: limits.maximumInlineExtensionDepth)
        inline.enableGFM(strikethrough: registry.contains(.strikethrough), autolink: registry.contains(.autolink))
        let gfm = GFMInlineTriggers(strikethrough: inline.strikethrough, autolink: inline.autolink)
        var pending = document.children(of: 0).reversed().map { ($0, 0) }
        // These buffers are local to one parse. Their contents never escape
        // into the resulting tree or the inline controller's projected input.
        var children: [Int] = []
        var events: [(Int, Int)] = []
        var tokenOrder: [Int] = []
        while let (old, parent) = pending.popLast() {
            let node = document.nodes[old]
            let data: NodeData
            if case .codeBlock(let info, let literal) = node.data {
                data = .codeBlock(info: info.map { InlineDecoding.decode($0) }, literal: literal)
            } else { data = node.data }
            let index = try! builder.append(data, range: node.range, segments: node.segments,
                                            fallbackLiteral: document.customLeafFallbacks[old], to: parent)
            mapped[old] = index
            document.children(of: old, into: &children)
            let inlineBlock: Bool
            switch node.data { case .paragraph, .heading, .tableCell: inlineBlock = true; default: inlineBlock = false }
            if inlineBlock, !children.isEmpty,
               children.allSatisfy({
                   switch document.nodes[$0].data { case .text, .softBreak: true; default: false }
               }),
               needsInlineParsing(children, document: document, triggers: triggers, hasRules: !inlineRules.isEmpty, gfm: gfm) {
                // Block transforms may already have annotated original text.
                // Preserve those exact ranges on the containing inline block.
                for child in children { mapped[child] = index }
                let input = InlineInput(document, children: children)
                inline.reset(to: input)
                inline.parse()
                // Provisional items bound the emitted count, including any
                // delimiter/link items later unlinked by the controller.
                builder.reserveAdditionalCapacity(inline.items.count)
                for diagnostic in inline.diagnostics { builder.report(diagnostic) }
                if let first = inline.first { events.append((first, index)) }
                while let (itemIndex, owner) = events.popLast() {
                    let item = inline.items[itemIndex]
                    let mapped = input.mapped(item.start, item.end)
                    let data: NodeData
                    if case .text("") = item.data {
                        data = .text(String(decoding: input.bytes[item.start..<item.end], as: UTF8.self))
                    } else { data = item.data }
                    let inlineIndex = try! builder.append(data, range: mapped.range,
                                                          segments: mapped.segments, fallbackLiteral: item.fallback, to: owner)
                    if collectSyntaxDetails {
                        // Arena links run backwards. Reuse one small buffer to
                        // preserve per-item insertion order and tree order.
                        tokenOrder.removeAll(keepingCapacity: true)
                        var tokenIndex = item.lastToken
                        while tokenIndex >= 0 {
                            tokenOrder.append(tokenIndex)
                            tokenIndex = inline.tokens[tokenIndex].previous
                        }
                        for tokenIndex in tokenOrder.reversed() {
                            let token = inline.tokens[tokenIndex]
                            switch input.mapped(token.start, token.end).segments {
                            case .none: break
                            case .one(let range):
                                builder.record(SyntaxToken(token.role, range: range, owner: inlineIndex))
                            case .many(let ranges):
                                for range in ranges { builder.record(SyntaxToken(token.role, range: range, owner: inlineIndex)) }
                            }
                        }
                    }
                    if let next = item.next { events.append((next, owner)) }
                    if let child = item.firstChild { events.append((child, inlineIndex)) }
                }
            } else {
                for child in children.reversed() { pending.append((child, index)) }
            }
        }
        for token in document.tokens ?? [] {
            let owner = mapped[token.owner]
            if owner >= 0 { builder.record(SyntaxToken(token.role, range: token.range, owner: owner)) }
        }
        return try! builder.build()
    }

    private func needsInlineParsing(_ children: [Int], document: Document,
                                    triggers: ByteSet, hasRules: Bool, gfm: GFMInlineTriggers) -> Bool {
        for child in children {
            guard case .text(let text) = document.nodes[child].data else { continue }
            // Block projection already repaired bytes and retained soft breaks.
            // Plain leaves need neither another projection nor another decode.
            if text.utf8.last == 32 || text.utf8.last == 9 { return true }
            guard gfm.strikethrough || gfm.autolink else {
                for byte in text.utf8 {
                    switch byte {
                    case 92, 38, 96, 42, 95, 91, 33, 60: return true
                    default: if hasRules && triggers.contains(byte) { return true }
                    }
                }
                continue
            }
            var previous: (UInt8, UInt8, UInt8) = (0, 0, 0)
            for byte in text.utf8 {
                switch byte {
                case 92, 38, 96, 42, 95, 91, 33, 60: return true
                case 126 where gfm.strikethrough: return true
                // An email needs '@'; www and URL autolinks need "www." or "://".
                case 64 where gfm.autolink: return true
                case 46 where gfm.autolink && previous == (119, 119, 119): return true
                case 47 where gfm.autolink && previous.1 == 58 && previous.2 == 47: return true
                default: if hasRules && triggers.contains(byte) { return true }
                }
                if gfm.autolink { previous = (previous.1, previous.2, byte) }
            }
        }
        return false
    }
}

/// Which GFM inline features can turn plain text into nodes.
internal struct GFMInlineTriggers {
    let strikethrough: Bool
    let autolink: Bool

}
