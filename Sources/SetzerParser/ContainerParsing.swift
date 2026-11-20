import SetzerSyntax

// Implements CommonMark's open-container and lazy-continuation strategy.
// This is an original Swift implementation; specification and cmark behavior
// are references, not copied source. All nesting and traversal are iterative.
internal enum ContainerPrefix: Sendable {
    case quote
    case list
    case item(padding: Int, acceptsBlank: Bool)
}

internal struct OpenContainer {
    enum Kind { case quote, list(ListStyle), item(padding: Int) }
    let node: Int
    let kind: Kind
    let start: Int
    var end: Int
    var childCount = 0
    var pendingBlank = false
    var lastChildEndsBlank = false
    var loose = false
    /// GFM task list item state, set when its checkbox is recognised.
    var task: Bool?

    var prefix: ContainerPrefix {
        switch kind {
        case .quote: .quote
        case .list: .list
        case .item(let padding): .item(padding: padding, acceptsBlank: true)
        }
    }
}

internal struct OpenLeaf {
    enum Kind { case paragraph, fenced(BlockParser.Fence), indented, html(HTMLBlockKind), table }
    let kind: Kind
    let parent: Int
    let start: Int
    /// Content lines. Every physical line either continues the open leaf or
    /// finishes it before anything else happens, so the lines are always
    /// contiguous; a range avoids a heap-allocated index list per block.
    var indices: Range<Int>
    /// GFM: a paragraph that failed the table check is never rechecked, as in
    /// cmark-gfm. Table state lives in `BlockParser.openTable`, keeping this
    /// leaf free of reference-counted storage.
    var tableChecked = false
}

extension BlockParser {
    mutating func parse() -> Document {
        var index = 0
        while index < lines.count {
            let matched = matchOpenContainers(at: index)
            if continueOpenLeaf(at: index, matchedContainers: matched) {
                index += 1
                continue
            }
            finishLeaf()
            closeContainers(to: matched)
            if consumeBlankLine(at: index) {
                index += 1
                continue
            }
            switch openContainers(at: index) {
            case .consumed(let nextLine):
                index = nextLine
            case .startLeaf(let depthLimited):
                touchContainers(through: index)
                if !isBlank(index) { startLeaf(at: index, depthLimited: depthLimited) }
                index += 1
            }
        }
        finishLeaf()
        closeContainers(to: 0)
        // M1-D audit: callbacks are validated before mutation; append/import
        // preserves topology and source order. Keep full release validation:
        // a failed invariant must surface as a parser bug, never hidden recovery.
        return try! builder.build()
    }

    /// Project the current physical line through the still-open containers.
    private mutating func matchOpenContainers(at index: Int) -> Int {
        var view = lines[index]  // still physical; see BlockParser.lines
        var matched = 0
        let leafParent = leaf?.parent
        for position in containers.indices {
            let next: SourceLine?
            switch containers[position].kind {
            case .quote:
                if let marker = Self.quoteMarker(view, source: source) {
                    next = marker.content
                    if collectSyntaxDetails {
                        builder.record(SyntaxToken("core.blockQuote.marker", range: marker.range,
                            owner: containers[position].node))
                    }
                } else { next = nil }
            case .list: next = view
            case .item(let padding):
                let acceptsBlank = containers[position].childCount > 0 || leafParent == containers[position].node
                next = Self.itemContent(view, source: source, padding: padding, acceptsBlank: acceptsBlank)
            }
            guard let next else { break }
            view = next
            matched += 1
        }
        lines[index] = view
        return matched
    }

    @inline(__always)
    private mutating func extendLeaf(_ index: Int) {
        // Contiguity is a parser invariant; see OpenLeaf.indices.
        assert(leaf?.indices.upperBound == index)
        if let lower = leaf?.indices.lowerBound { leaf?.indices = lower..<(index + 1) }
    }

    /// Read only kind and parent; do not copy OpenLeaf's growing
    /// indices array before appending, which would defeat its unique storage.
    private mutating func continueOpenLeaf(at index: Int, matchedContainers: Int) -> Bool {
        // Paragraph lines need the first content byte several times.
        var paragraphFirst: (byte: UInt8?, columns: Int)?
        if matchedContainers == containers.count, let kind = leaf?.kind {
            switch kind {
            case .fenced(let fence):
                touchContainers(through: index)
                if closesFence(index, fence) { finishLeaf(closingLine: index) }
                else { extendLeaf(index) }
                return true
            case .indented:
                if isBlank(index) || indentation(index).columns >= 4 {
                    extendLeaf(index)
                    touchContainers(through: index)
                    return true
                }
            case .paragraph:
                let first = firstByte(index)
                paragraphFirst = first
                if registry.contains(.setextHeading), first.columns <= 3, first.byte == 61 || first.byte == 45,
                   let level = setextLevel(index) {
                    touchContainers(through: index)
                    guard let parent = leaf?.parent else { return false }
                    if !finishLeaf(headingLevel: level, closingLine: index) {
                        // Removing only definitions leaves the underline
                        // as paragraph text; it is not a fresh list marker.
                        leaf = OpenLeaf(kind: .paragraph, parent: parent, start: index, indices: index..<(index + 1))
                    }
                    return true
                }
            case .html(let kind):
                if (kind != .blockTag && kind != .completeTag) || !isBlank(index) {
                    extendLeaf(index)
                    touchContainers(through: index)
                    if endsHTMLBlock(index, kind: kind) { finishLeaf() }
                    return true
                }
            case .table:
                if continueTable(at: index) {
                    extendLeaf(index)
                    touchContainers(through: index)
                    return true
                }
            }
        }

        // A line without content after indentation is blank.
        if case .paragraph? = leaf?.kind, case let first = paragraphFirst ?? firstByte(index), first.byte != nil,
           !interruptsParagraph(index, matchedContainers: matchedContainers, first: first) {
            // A GFM delimiter row turns the paragraph's last line into a table
            // header; like cmark-gfm, only after every other block start.
            if matchedContainers == containers.count, registry.contains(.table), leaf?.tableChecked == false,
               first.columns <= 3, let byte = first.byte, byte == 124 || byte == 58 || byte == 45,
               startTable(at: index) {
                touchContainers(through: index)
                return true
            }
            // Missing quote/item prefixes may only continue an existing
            // paragraph; they cannot extend a fence, heading or code block.
            if matchedContainers < containers.count { lazyParagraphLine = index }
            extendLeaf(index)
            touchContainers(through: index)
            return true
        }
        return false
    }

    private mutating func consumeBlankLine(at index: Int) -> Bool {
        guard isBlank(index) else { return false }
        touchContainers(through: index)
        if let last = containers.indices.last {
            if case .quote = containers[last].kind { containers[last].pendingBlank = false }
            else { containers[last].pendingBlank = true }
        }
        return true
    }

    private enum ContainerOpening {
        case consumed(nextLine: Int)
        case startLeaf(depthLimited: Bool)
    }

    /// Retain the existing extension/quote/list precedence and depth fallback.
    private mutating func openContainers(at index: Int) -> ContainerOpening {
        // A list opened on this line reuses its marker for the first item
        // instead of scanning the same line again.
        var openedMarker: ListMarker?
        opening: while true {
            // A list without an open item accepts only a compatible marker.
            if let last = containers.last, case .list(let style) = last.kind {
                let candidate: ListMarker?
                if let known = openedMarker {
                    candidate = known
                    openedMarker = nil
                } else if Self.mayStartListItem(firstByte(index)), let found = listMarker(index, interrupting: false),
                          !(registry.contains(.thematicBreak) && thematicBreak(index)) {
                    candidate = found
                } else { candidate = nil }
                if let marker = candidate, Self.sameList(style, marker.style) {
                    guard hasRoom(for: 1, at: index) else {
                        closeContainers(to: containers.count - 1)
                        return .startLeaf(depthLimited: true)
                    }
                    beginChild()
                    let node = append(.listItem, range: SourceRange(lines[index].range.lowerBound, lines[index].range.lowerBound))
                    containers.append(OpenContainer(node: node, kind: .item(padding: marker.padding),
                                                    start: lines[index].range.lowerBound, end: lines[index].range.upperBound))
                    if collectSyntaxDetails {
                        builder.record(SyntaxToken("core.list.marker", range: marker.range, owner: node))
                    }
                    lines[index] = marker.content
                    if registry.contains(.taskList), let task = taskListMarker(index) {
                        // cmark-gfm stops opening blocks after the checkbox:
                        // the rest of the line is paragraph text.
                        containers[containers.count - 1].task = task.checked
                        if collectSyntaxDetails { builder.record(SyntaxToken("gfm.tasklist.marker", range: task.range, owner: node)) }
                        var cursor = SourceCursor(line: lines[index])
                        for _ in 0..<3 { cursor.advanceASCII() }
                        lines[index] = cursor.view
                        forcedParagraphLine = index
                        return .startLeaf(depthLimited: false)
                    }
                    continue
                }
                closeContainers(to: containers.count - 1)
                continue
            }
            for entry in registry.opening {
                switch entry {
                case .custom(let ruleIndex):
                    if let resolved = extensionMatch(at: index, interrupting: false, candidate: registry.custom[ruleIndex]) {
                        let match = resolved.match
                        beginChild()
                        let end = index + match.consumedLines
                        let range = SourceRange(lines[index].range.lowerBound, lines[end - 1].range.upperBound)
                        let owner = append(match.data, range: range, segments: match.sourceSegments,
                            fallbackLiteral: match.children == nil ? extensionFallback(resolved.lines) : nil)
                        for token in match.tokens { builder.record(SyntaxToken(token.role, range: token.range, owner: owner)) }
                        for diagnostic in match.diagnostics { builder.report(diagnostic) }
                        if collectSyntaxDetails {
                            // Accepted multi-line rules skip the normal loop.
                            // Record their enclosing quote prefixes only now,
                            // after validation, never during callback lookahead.
                            for continuation in (index + 1)..<end {
                                _ = matchOpenContainers(at: continuation)
                            }
                        }
                        if let children = match.children, !children.isEmpty {
                            if extensionDepth + containers.count + 1 < limits.maximumContainerDepth {
                                var parser = BlockParser(source: source, registry: registry, limits: limits,
                                    collectSyntaxDetails: collectSyntaxDetails, projectedLines: children,
                                    extensionDepth: extensionDepth + containers.count + 1)
                                appendChildren(parser.parse(), to: owner)
                            } else {
                                builder.report(ParseDiagnostic(.nestingLimitExceeded(limits.maximumContainerDepth), range: range))
                                // Keep overflow syntax as literal inline content in the custom container.
                                append(.text(extensionFallback(children)), range: range, to: owner)
                            }
                        }
                        touchContainers(through: end - 1)
                        return .consumed(nextLine: end)
                    }
                case .core(.blockQuote):
                    if firstByte(index).byte == 62, let marker = Self.quoteMarker(lines[index], source: source) {
                        guard hasRoom(for: 1, at: index) else { return .startLeaf(depthLimited: true) }
                        beginChild()
                        let start = lines[index].range.lowerBound
                        let node = append(.blockQuote, range: SourceRange(start, start))
                        containers.append(OpenContainer(node: node, kind: .quote, start: start, end: lines[index].range.upperBound))
                        if collectSyntaxDetails {
                            builder.record(SyntaxToken("core.blockQuote.marker", range: marker.range, owner: node))
                        }
                        lines[index] = marker.content
                        if isBlank(index) { return .startLeaf(depthLimited: false) }
                        continue opening
                    }
                case .core(.list):
                    if Self.mayStartListItem(firstByte(index)), !(registry.contains(.thematicBreak) && thematicBreak(index)),
                       let marker = listMarker(index, interrupting: false) {
                        guard hasRoom(for: 2, at: index) else { return .startLeaf(depthLimited: true) }
                        beginChild()
                        let start = lines[index].range.lowerBound
                        let node = append(.list(ListAttributes(style: marker.style)), range: SourceRange(start, start))
                        containers.append(OpenContainer(node: node, kind: .list(marker.style), start: start, end: lines[index].range.upperBound))
                        openedMarker = marker
                        // Next iteration opens the first item through the same path
                        // used for subsequent siblings.
                        continue opening
                    }
                case .core: break
                }
            }
            break
        }
        return .startLeaf(depthLimited: false)
    }

    private mutating func startLeaf(at index: Int, depthLimited: Bool) {
        let parent = containers.last?.node ?? 0
        if !depthLimited && forcedParagraphLine != index {
            // Each scanner below rejects a line whose first non-space byte
            // cannot start it; checking that byte first skips the scan.
            let first = firstByte(index)
            for rule in registry.leaves {
                switch rule {
                case .indentedCode where first.columns >= 4:
                    beginChild()
                    leaf = OpenLeaf(kind: .indented, parent: parent, start: index, indices: index..<(index + 1))
                    return
                case .fencedCode:
                    if first.columns <= 3, first.byte == 96 || first.byte == 126, let fence = openingFence(index) {
                        beginChild()
                        leaf = OpenLeaf(kind: .fenced(fence), parent: parent, start: index, indices: (index + 1)..<(index + 1))
                        return
                    }
                case .atxHeading:
                    if first.columns <= 3, first.byte == 35, let heading = atxHeading(index) {
                        beginChild()
                        let node = append(.heading(level: heading.level), range: lines[index].range,
                            segments: heading.content.isEmpty ? .none : .one(heading.content))
                        appendText(heading.content, to: node)
                        return
                    }
                case .thematicBreak where first.columns <= 3 && (first.byte == 42 || first.byte == 45 || first.byte == 95) && thematicBreak(index):
                    beginChild()
                    append(.thematicBreak, range: lines[index].range)
                    return
                case .htmlBlock:
                    if first.columns <= 3, first.byte == 60, let kind = htmlBlockStart(index, interrupting: false) {
                        beginChild()
                        leaf = OpenLeaf(kind: .html(kind), parent: parent, start: index, indices: index..<(index + 1))
                        if endsHTMLBlock(index, kind: kind) { finishLeaf() }
                        return
                    }
                default: break
                }
            }
        }
        leaf = OpenLeaf(kind: .paragraph, parent: parent, start: index, indices: index..<(index + 1))
    }

    mutating func interruptsParagraph(_ index: Int, matchedContainers: Int,
                                      first: (byte: UInt8?, columns: Int)) -> Bool {
        // Every core and extension block start allows at most three columns
        // of indentation, and each core scanner requires a specific first
        // byte. Plain paragraph text therefore needs a single byte dispatch.
        guard first.columns <= 3, let byte = first.byte else { return false }
        switch byte {
        case 35:
            if registry.contains(.atxHeading) && atxHeading(index) != nil { return true }
        case 96, 126:
            if registry.contains(.fencedCode) && openingFence(index) != nil { return true }
        case 42, 45, 95:
            if registry.contains(.thematicBreak) && thematicBreak(index) { return true }
        case 62:
            if registry.contains(.blockQuote), Self.quoteContent(lines[index], source: source) != nil { return true }
        case 60:
            if registry.contains(.htmlBlock), htmlBlockStart(index, interrupting: matchedContainers == containers.count) != nil { return true }
        default: break
        }
        // At an unmatched outer container this begins a new block there; it
        // does not interrupt that outer container's existing paragraph.
        if Self.mayStartListItem(first), registry.contains(.list),
           listMarker(index, interrupting: matchedContainers == containers.count) != nil { return true }
        guard registry.mayInterrupt(byte) else { return false }
        return extensionMatch(at: index, interrupting: true, prefixCount: matchedContainers) != nil
    }

    /// First byte after indentation and its column count, as seen by every
    /// block scanner. `byte` is nil for a line without content.
    @inline(__always)
    func firstByte(_ index: Int) -> (byte: UInt8?, columns: Int) {
        let indent = indentation(index)
        return (indent.offset < lines[index].contentRange.upperBound ? source[indent.offset] : nil, indent.columns)
    }

    @inline(__always)
    static func mayStartListItem(_ first: (byte: UInt8?, columns: Int)) -> Bool {
        guard first.columns <= 3, let byte = first.byte else { return false }
        return byte == 42 || byte == 43 || byte == 45 || (48...57).contains(byte)
    }

    /// Import a fully validated subtree without copying or rebasing source bytes.
    /// Builder insertion order is preorder, so each parent exists before its child.
    private mutating func appendChildren(_ document: Document, to owner: Int) {
        var pending = document.children(of: 0).reversed().map { ($0, owner) }
        var owners: [Int: Int] = [:]
        while let (index, parent) = pending.popLast() {
            let node = document.nodes[index]
            let target = append(node.data, range: node.range, segments: node.segments,
                fallbackLiteral: document.customLeafFallbacks[index], to: parent)
            owners[index] = target
            for child in document.children(of: index).reversed() { pending.append((child, target)) }
        }
        for token in document.tokens ?? [] {
            if let target = owners[token.owner] { builder.record(SyntaxToken(token.role, range: token.range, owner: target)) }
        }
        for diagnostic in document.diagnostics { builder.report(diagnostic) }
    }

    mutating func hasRoom(for count: Int, at index: Int) -> Bool {
        guard extensionDepth + containers.count + count <= limits.maximumContainerDepth else {
            builder.report(ParseDiagnostic(.nestingLimitExceeded(limits.maximumContainerDepth), range: lines[index].range))
            return false
        }
        return true
    }

    mutating func touchContainers(through index: Int) {
        // Projection keeps a line's upper bound, so any table entry works.
        let end = lines[index].range.upperBound
        for position in containers.indices { containers[position].end = end }
    }

    /// Blank separation matters at the list item's direct-child boundary;
    /// blank lines inside a quote or fence do not loosen an enclosing list.
    mutating func beginChild() {
        guard let last = containers.indices.last else { return }
        let separated = containers[last].pendingBlank || containers[last].lastChildEndsBlank
        if containers[last].childCount > 0 && separated {
            switch containers[last].kind {
            case .list: containers[last].loose = true
            case .item:
                if last > 0, case .list = containers[last - 1].kind { containers[last - 1].loose = true }
            case .quote: break
            }
        }
        containers[last].childCount += 1
        containers[last].pendingBlank = false
        containers[last].lastChildEndsBlank = false
    }

    mutating func closeContainers(to count: Int) {
        while containers.count > count {
            let container = containers.removeLast()
            let data: NodeData
            let endsBlank: Bool
            switch container.kind {
            case .quote: data = .blockQuote; endsBlank = false
            case .list(let style):
                data = .list(ListAttributes(style: style, isTight: !container.loose))
                endsBlank = container.pendingBlank || container.lastChildEndsBlank
            case .item:
                data = container.task.map { .taskListItem(checked: $0) } ?? .listItem
                endsBlank = container.pendingBlank || container.lastChildEndsBlank
            }
            // Only nodes returned by append enter containers; root never does.
            try! builder.finish(container.node, data: data, range: SourceRange(container.start, container.end))
            if let parent = containers.indices.last { containers[parent].lastChildEndsBlank = endsBlank }
        }
    }

    @discardableResult
    mutating func finishLeaf(headingLevel: Int? = nil, closingLine: Int? = nil, tablePreamble: Bool = false) -> Bool {
        guard let active = leaf else { return false }
        leaf = nil
        switch active.kind {
        case .paragraph:
            let paragraphLines = active.indices
            if tablePreamble {
                finishTablePreamble(paragraphLines, parent: active.parent)
                return true
            }
            if paragraphLines.count == 1 {
                // Single-line paragraphs and list item texts are the common
                // case; finish them without a segment array.
                let index = paragraphLines.lowerBound
                let segment = SourceRange(indentation(index).offset, lines[index].contentRange.upperBound)
                if !(registry.contains(.referenceDefinition) && segment.lowerBound < segment.upperBound
                     && source[segment.lowerBound] == 91) {
                    beginChild()
                    let content = trimmed(segment.lowerBound, segment.upperBound)
                    let endLine = closingLine ?? index
                    let node = append(headingLevel.map { .heading(level: $0) } ?? .paragraph,
                                      range: SourceRange(lines[index].range.lowerBound, lines[endLine].range.upperBound),
                                      segments: .one(content), to: active.parent)
                    appendText(content, to: node)
                    return true
                }
            }
            var segments: [SourceRange] = []
            segments.reserveCapacity(paragraphLines.count)
            for index in paragraphLines {
                segments.append(SourceRange(indentation(index).offset, lines[index].contentRange.upperBound))
            }
            var firstContent = 0
            // A definition must start with "[" on the first paragraph line;
            // only then is the scanner and its line-ending table needed.
            if registry.contains(.referenceDefinition), let opening = segments.first,
               opening.lowerBound < opening.upperBound, source[opening.lowerBound] == 91 {
                let scanner = ReferenceScanner(source: source, content: segments,
                    endings: paragraphLines.map { lines[$0].range.upperBound }, collectSyntax: collectSyntaxDetails)
                while let reference = scanner.parse(at: firstContent) {
                    let first = paragraphLines.lowerBound + reference.firstLine
                    let last = paragraphLines.lowerBound + reference.endLine - 1
                    let owner = append(.referenceDefinition(reference.definition),
                           range: SourceRange(lines[first].range.lowerBound, lines[last].range.upperBound),
                           segments: (first...last).map { lines[$0].range }, to: active.parent)
                    if let syntax = reference.syntax {
                        scanner.forEachSegment(syntax.label) { builder.record(SyntaxToken("core.reference.label", range: $0, owner: owner)) }
                        scanner.forEachSegment(syntax.destination) {
                            builder.record(SyntaxToken("core.reference.destination", range: $0, owner: owner))
                        }
                        if let title = syntax.title {
                            scanner.forEachSegment(title) { builder.record(SyntaxToken("core.reference.title", range: $0, owner: owner)) }
                        }
                        syntax.markers.forEach { builder.record(SyntaxToken("core.reference.marker", range: $0, owner: owner)) }
                    }
                    firstContent = reference.endLine
                }
            }
            guard firstContent < paragraphLines.count else { return false }
            beginChild()
            let contentStart = paragraphLines.lowerBound + firstContent
            if firstContent > 0 { segments.removeFirst(firstContent) }
            if let last = segments.last { segments[segments.count - 1] = trimmed(last.lowerBound, last.upperBound) }
            let endLine = closingLine ?? (paragraphLines.upperBound - 1)
            let node = append(headingLevel.map { .heading(level: $0) } ?? .paragraph,
                              range: SourceRange(lines[contentStart].range.lowerBound, lines[endLine].range.upperBound),
                              segments: segments, to: active.parent)
            for (position, segment) in segments.enumerated() {
                appendText(segment, to: node)
                if position + 1 < segments.count {
                    let line = lines[contentStart + position]
                    append(.softBreak, range: SourceRange(line.contentRange.upperBound, line.range.upperBound), to: node)
                }
            }
        case .fenced, .indented:
            var end = active.indices.upperBound
            let removal: Int
            let info: String?
            if case .fenced(let fence) = active.kind { removal = fence.indent; info = fence.info.map(decode) }
            else {
                removal = 4
                info = nil
                while end > active.indices.lowerBound && isBlank(end - 1) { end -= 1 }
                if end < active.indices.upperBound,
                   let parent = containers.indices.last { containers[parent].pendingBlank = true }
            }
            let codeLines = active.indices.lowerBound..<end
            var literal: [UInt8] = []
            if let last = codeLines.last {
                literal.reserveCapacity(lines[last].range.upperBound - lines[codeLines.lowerBound].range.lowerBound + 16)
            }
            var segments: [SourceRange] = []
            segments.reserveCapacity(codeLines.count)
            for index in codeLines {
                segments.append(appendCodeContent(index, removing: removal, to: &literal))
            }
            let endLine = closingLine ?? codeLines.last ?? active.start
            let owner = append(.codeBlock(info: info, literal: String(decoding: literal, as: UTF8.self)),
                   range: SourceRange(lines[active.start].range.lowerBound, lines[endLine].range.upperBound),
                   segments: segments, to: active.parent)
            if collectSyntaxDetails, case .fenced(let fence) = active.kind {
                let opening = indentation(active.start).offset
                builder.record(SyntaxToken("core.fence.open", range: SourceRange(opening, opening + fence.count), owner: owner))
                let infoRange = trimmed(opening + fence.count, lines[active.start].contentRange.upperBound)
                builder.record(SyntaxToken("core.fence.info", range: infoRange, owner: owner))
                if let closingLine {
                    let closing = indentation(closingLine).offset
                    var end = closing
                    while end < lines[closingLine].contentRange.upperBound && source[end] == fence.marker { end += 1 }
                    builder.record(SyntaxToken("core.fence.close", range: SourceRange(closing, end), owner: owner))
                }
            }
        case .table:
            finishTable(active)
            openTable = nil
        case .html(let kind):
            let segments = active.indices.map { lines[$0].range }
            var bytes: [UInt8] = []
            for index in active.indices {
                Self.appendSpaces(lines[index].virtualIndentation, to: &bytes)
                appendRepaired(lines[index].contentRange, to: &bytes)
                bytes.append(10)
            }
            let literal = String(decoding: bytes, as: UTF8.self)
            let last = active.indices.upperBound - 1
            append(.htmlBlock(HTMLBlock(kind: kind, literal: literal)),
                   range: SourceRange(lines[active.start].range.lowerBound, lines[last].range.upperBound),
                   segments: segments, to: active.parent)
        }
        return true
    }

    static func quoteContent(_ line: SourceLine, source: [UInt8]) -> SourceLine? {
        quoteMarker(line, source: source)?.content
    }

    private struct QuoteMarker {
        let range: SourceRange
        let content: SourceLine
    }

    private static func quoteMarker(_ line: SourceLine, source: [UInt8]) -> QuoteMarker? {
        var cursor = SourceCursor(line: line)
        guard cursor.skipIndentation(in: source) <= 3, cursor.byte(source) == 62 else { return nil }
        let start = cursor.offset
        cursor.advanceASCII()
        let next = cursor.byte(source)
        if next == 32 || next == 9 { cursor.consumeIndentation(1, in: source) }
        return QuoteMarker(range: SourceRange(start, start + 1), content: cursor.view)
    }

    @inline(__always)
    static func itemContent(_ line: SourceLine, source: [UInt8], padding: Int, acceptsBlank: Bool) -> SourceLine? {
        var cursor = SourceCursor(line: line)
        var probe = cursor
        let indent = probe.skipIndentation(in: source)
        if indent >= padding { cursor.consumeIndentation(padding, in: source) }
        else if acceptsBlank && probe.atEnd { cursor = probe }
        else { return nil }
        return cursor.view
    }

    static func project(_ line: SourceLine, source: [UInt8], prefixes: [ContainerPrefix]) -> SourceLine? {
        var view = line
        for prefix in prefixes {
            switch prefix {
            case .quote:
                guard let next = quoteContent(view, source: source) else { return nil }
                view = next
            case .list: break
            case .item(let padding, let acceptsBlank):
                guard let next = itemContent(view, source: source, padding: padding, acceptsBlank: acceptsBlank) else { return nil }
                view = next
            }
        }
        return view
    }

    struct ListMarker {
        let style: ListStyle
        let padding: Int
        let range: SourceRange
        let content: SourceLine
    }

    func listMarker(_ index: Int, interrupting: Bool) -> ListMarker? {
        var cursor = SourceCursor(line: lines[index])
        let indent = cursor.skipIndentation(in: source)
        guard indent <= 3, let first = cursor.byte(source) else { return nil }
        let markerStart = cursor.offset
        let style: ListStyle
        if first == 42 || first == 43 || first == 45 {
            style = .bullet(marker: first)
            cursor.advanceASCII()
        } else if (48...57).contains(first) {
            var digits = 0
            var start = 0
            while let byte = cursor.byte(source), (48...57).contains(byte), digits < 9 {
                start = start * 10 + Int(byte - 48)
                digits += 1
                cursor.advanceASCII()
            }
            guard let delimiter = cursor.byte(source), delimiter == 46 || delimiter == 41,
                  !interrupting || start == 1 else { return nil }
            style = .ordered(start: start, delimiter: delimiter)
            cursor.advanceASCII()
        } else { return nil }
        let following = cursor.byte(source)
        guard cursor.atEnd || following == 32 || following == 9 else { return nil }
        let width = cursor.offset - markerStart
        var probe = cursor
        let whitespace = probe.skipIndentation(in: source)
        if interrupting && probe.atEnd { return nil }
        let padding: Int
        if whitespace >= 1 && whitespace <= 4 && !probe.atEnd {
            padding = indent + width + whitespace
            cursor = probe
        } else {
            padding = indent + width + 1
            cursor.consumeIndentation(1, in: source)
        }
        return ListMarker(style: style, padding: padding,
            range: SourceRange(markerStart, markerStart + width), content: cursor.view)
    }

    static func sameList(_ lhs: ListStyle, _ rhs: ListStyle) -> Bool {
        switch (lhs, rhs) {
        case (.bullet(let a), .bullet(let b)): a == b
        case (.ordered(_, let a), .ordered(_, let b)): a == b
        default: false
        }
    }
}
