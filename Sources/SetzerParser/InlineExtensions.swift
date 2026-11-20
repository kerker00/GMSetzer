import SetzerSyntax

extension InlineParser {
    struct CustomOpener {
        let handle: DelimiterHandle
        let identifier: String
        let item: Int
        let bottom: Int
        let bracketDepth: Int
        let tokens: [BlockToken]
    }

    mutating func customMatch() -> Bool {
        guard let candidates = rules[bytes[cursor]] else { return false }
        if cursor >= customRunEnd || bytes[cursor] != customRunMarker {
            customRunMarker = bytes[cursor]
            customRunEnd = cursor + 1
            while customRunEnd < bytes.count && bytes[customRunEnd] == customRunMarker { customRunEnd += 1 }
        }
        let end = customRunEnd
        let before = scalar(before: cursor)
        let after = scalar(at: end)
        let canOpen = !whitespace(after) && (!punctuation(after) || whitespace(before) || punctuation(before))
        let canClose = !whitespace(before) && (!punctuation(before) || whitespace(after) || punctuation(after))
        for active in candidates {
            let eligible = customOpeners.filter {
                $0.identifier == active.identifier && $0.bracketDepth == brackets.count
            }.map(\.handle)
            let context = InlineContext(source: source, input: bytes, offset: cursor, options: active.options,
                canOpen: canOpen, canClose: canClose, runLength: end - cursor, openers: eligible, projection: input)
            guard let match = active.rule.match(context) else { continue }
            guard accepts(match, context: context, active: active) else {
                diagnostics.append(ParseDiagnostic(.invalidExtensionResult(active.identifier), range: input.range(cursor, end)))
                continue
            }
            let start = cursor
            cursor += match.consumed
            switch match.delimiter {
            case .none:
                let item = append(match.data, start, cursor)
                record(match.tokens, on: item)
                if let children = match.children, !children.isEmpty {
                    if depth >= maximumDepth {
                        let child = items.count
                        items.append(Item(data: .text(InlineDecoding.decode(bytes[children.lowerBound..<children.upperBound], escapes: false, entities: false)),
                                          start: children.lowerBound, end: children.upperBound))
                        items[item].firstChild = child
                        diagnostics.append(ParseDiagnostic(.nestingLimitExceeded(maximumDepth), range: input.range(start, cursor)))
                    } else {
                        var nested = InlineParser(input: input.slice(children), references: references, collectSyntax: collectSyntax,
                            source: source, rules: rules, triggers: triggers, maximumDepth: maximumDepth, depth: depth + 1)
                        nested.enableGFM(strikethrough: strikethrough, autolink: autolink)
                        nested.parse()
                        let base = items.count
                        for var child in nested.items {
                            child.start += children.lowerBound; child.end += children.lowerBound
                            child.previous = child.previous.map { $0 + base }
                            child.next = child.next.map { $0 + base }
                            child.firstChild = child.firstChild.map { $0 + base }
                            child.tokens = child.tokens.map { ($0.0, $0.1 + children.lowerBound, $0.2 + children.lowerBound) }
                            items.append(child)
                        }
                        items[item].firstChild = nested.first.map { $0 + base }
                        diagnostics.append(contentsOf: nested.diagnostics)
                    }
                } else {
                    items[item].fallback = InlineDecoding.decode(bytes[start..<cursor], escapes: false, entities: false)
                }
            case .open(let width):
                let item = append(.text(String(decoding: bytes[start..<cursor], as: UTF8.self)), start, cursor)
                let handle = DelimiterHandle(owner: active.descriptor.identifier, offset: start, width: width)
                customOpeners.append(CustomOpener(handle: handle, identifier: active.identifier, item: item,
                    bottom: delimiters.count, bracketDepth: brackets.count, tokens: match.tokens))
            case .close(let handle, _):
                let openerIndex = customOpeners.firstIndex { $0.handle == handle }!
                let opener = customOpeners[openerIndex]
                emphasis(bottom: opener.bottom)
                let item = wrap(match.data, opener: opener.item, closer: nil, start: opener.handle.offset, end: cursor)
                record(opener.tokens, on: item)
                record(match.tokens, on: item)
                unlink(opener.item)
                customOpeners.removeSubrange(openerIndex...)
            }
            return true
        }
        return false
    }

    func accepts(_ match: InlineMatch, context: InlineContext, active: ActiveInlineRule) -> Bool {
        guard match.consumed > 0, match.consumed <= bytes.count - cursor,
              case .custom(let kind, .inline, _) = match.data,
              active.descriptor.owns(kind.name), active.descriptor.nodeKinds.contains(kind) else { return false }
        let range = SourceRange(cursor, cursor + match.consumed)
        guard match.tokens.allSatisfy({ active.descriptor.owns($0.role) && range.contains($0.range) }) else { return false }
        if let children = match.children, !range.contains(children) || children == range { return false }
        switch match.delimiter {
        case .none: return true
        case .open(let width):
            return match.children == nil && context.canOpen && width == context.runLength && width == match.consumed
        case .close(let opener, let width):
            return match.children == nil && context.canClose && width == context.runLength && width == match.consumed
                && width == opener.width && opener.owner == active.descriptor.identifier && context.openers.contains(opener)
        }
    }

    mutating func record(_ tokens: [BlockToken], on item: Int) {
        for t in tokens { token(item, t.role, t.range.lowerBound, t.range.upperBound) }
    }
}
