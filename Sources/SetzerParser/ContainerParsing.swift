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

    var prefix: ContainerPrefix {
        switch kind {
        case .quote: .quote
        case .list: .list
        case .item(let padding): .item(padding: padding, acceptsBlank: true)
        }
    }
}

internal struct OpenLeaf {
    enum Kind { case paragraph, fenced(BlockParser.Fence), indented }
    let kind: Kind
    let parent: Int
    let start: Int
    var indices: [Int]
}

extension BlockParser {
    mutating func parse() -> Document {
        var index = 0
        while index < physicalLines.count {
            var view = physicalLines[index]
            var matched = 0
            for container in containers {
                let prefix: ContainerPrefix
                if case .item(let padding) = container.kind {
                    prefix = .item(padding: padding, acceptsBlank: container.childCount > 0)
                } else { prefix = container.prefix }
                guard let next = Self.project(view, source: source, prefixes: [prefix]) else { break }
                view = next
                matched += 1
            }
            lines[index] = view
            let allMatched = matched == containers.count

            if allMatched, let kind = leaf?.kind {
                switch kind {
                case .fenced(let fence):
                    touchContainers(through: index)
                    if closesFence(index, fence) { finishLeaf(closingLine: index) }
                    else { leaf!.indices.append(index) }
                    index += 1
                    continue
                case .indented:
                    if isBlank(index) || indentation(index).columns >= 4 {
                        leaf!.indices.append(index)
                        touchContainers(through: index)
                        index += 1
                        continue
                    }
                case .paragraph:
                    if let level = setextLevel(index) {
                        touchContainers(through: index)
                        finishLeaf(headingLevel: level, closingLine: index)
                        index += 1
                        continue
                    }
                }
            }

            if case .paragraph? = leaf?.kind, !isBlank(index),
               !interruptsParagraph(index, matchedContainers: matched) {
                // Missing quote/item prefixes may only continue an existing
                // paragraph; they cannot extend a fence, heading or code block.
                leaf!.indices.append(index)
                touchContainers(through: index)
                index += 1
                continue
            }
            finishLeaf()
            closeContainers(to: matched)

            if isBlank(index) {
                touchContainers(through: index)
                if let last = containers.indices.last {
                    if case .quote = containers[last].kind { containers[last].pendingBlank = false }
                    else { containers[last].pendingBlank = true }
                }
                index += 1
                continue
            }

            var consumedExtension = false
            var limited = false
            while true {
                // A list without an open item accepts only a compatible marker.
                if let last = containers.last, case .list(let style) = last.kind {
                    if let marker = listMarker(index, interrupting: false), !thematicBreak(index),
                       Self.sameList(style, marker.style) {
                        guard hasRoom(for: 1, at: index) else { closeContainers(to: containers.count - 1); limited = true; break }
                        beginChild()
                        let node = append(.listItem, range: SourceRange(lines[index].range.lowerBound, lines[index].range.lowerBound))
                        containers.append(OpenContainer(node: node, kind: .item(padding: marker.padding),
                                                        start: lines[index].range.lowerBound, end: lines[index].range.upperBound))
                        lines[index] = marker.content
                        continue
                    }
                    closeContainers(to: containers.count - 1)
                    continue
                }
                if let match = extensionMatch(at: index, interrupting: false) {
                    beginChild()
                    let end = index + match.consumedLines
                    append(match.data, range: SourceRange(lines[index].range.lowerBound, physicalLines[end - 1].range.upperBound),
                           segments: match.sourceSegments)
                    touchContainers(through: end - 1)
                    index = end
                    consumedExtension = true
                    break
                }
                if let content = Self.quoteContent(lines[index], source: source) {
                    guard hasRoom(for: 1, at: index) else { limited = true; break }
                    beginChild()
                    let start = lines[index].range.lowerBound
                    let node = append(.blockQuote, range: SourceRange(start, start))
                    containers.append(OpenContainer(node: node, kind: .quote, start: start, end: lines[index].range.upperBound))
                    lines[index] = content
                    if isBlank(index) { break }
                    continue
                }
                if !thematicBreak(index), let marker = listMarker(index, interrupting: false) {
                    guard hasRoom(for: 2, at: index) else { limited = true; break }
                    beginChild()
                    let start = lines[index].range.lowerBound
                    let node = append(.list(ListAttributes(style: marker.style)), range: SourceRange(start, start))
                    containers.append(OpenContainer(node: node, kind: .list(marker.style), start: start, end: lines[index].range.upperBound))
                    // Next iteration opens the first item through the same path
                    // used for subsequent siblings.
                    continue
                }
                break
            }
            if consumedExtension { continue }
            touchContainers(through: index)
            if isBlank(index) { index += 1; continue }
            beginChild()
            let parent = containers.last?.node ?? 0
            if !limited && indentation(index).columns >= 4 {
                leaf = OpenLeaf(kind: .indented, parent: parent, start: index, indices: [index])
            } else if !limited, let fence = openingFence(index) {
                leaf = OpenLeaf(kind: .fenced(fence), parent: parent, start: index, indices: [])
            } else if !limited, let heading = atxHeading(index) {
                let node = append(.heading(level: heading.level), range: lines[index].range,
                                  segments: heading.content.isEmpty ? [] : [heading.content])
                appendText(heading.content, to: node)
            } else if !limited && thematicBreak(index) {
                append(.thematicBreak, range: lines[index].range)
            } else if !limited, let reference = referenceDefinition(index) {
                append(.referenceDefinition(reference), range: lines[index].range)
            } else {
                leaf = OpenLeaf(kind: .paragraph, parent: parent, start: index, indices: [index])
            }
            index += 1
        }
        finishLeaf()
        closeContainers(to: 0)
        return try! builder.build()
    }

    mutating func interruptsParagraph(_ index: Int, matchedContainers: Int) -> Bool {
        if atxHeading(index) != nil || openingFence(index) != nil || thematicBreak(index) { return true }
        if Self.quoteContent(lines[index], source: source) != nil { return true }
        // At an unmatched outer container this begins a new block there; it
        // does not interrupt that outer container's existing paragraph.
        if listMarker(index, interrupting: matchedContainers == containers.count) != nil { return true }
        return extensionMatch(at: index, interrupting: true, prefixCount: matchedContainers) != nil
    }

    mutating func hasRoom(for count: Int, at index: Int) -> Bool {
        guard containers.count + count <= limits.maximumContainerDepth else {
            builder.report(ParseDiagnostic(.nestingLimitExceeded(limits.maximumContainerDepth), range: lines[index].range))
            return false
        }
        return true
    }

    mutating func touchContainers(through index: Int) {
        for position in containers.indices { containers[position].end = physicalLines[index].range.upperBound }
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
                data = .listItem
                endsBlank = container.pendingBlank || container.lastChildEndsBlank
            }
            try! builder.finish(container.node, data: data, range: SourceRange(container.start, container.end))
            if let parent = containers.indices.last { containers[parent].lastChildEndsBlank = endsBlank }
        }
    }

    mutating func finishLeaf(headingLevel: Int? = nil, closingLine: Int? = nil) {
        guard let active = leaf else { return }
        leaf = nil
        switch active.kind {
        case .paragraph:
            var segments = active.indices.map { index in
                SourceRange(indentation(index).offset, lines[index].contentRange.upperBound)
            }
            if let last = segments.last { segments[segments.count - 1] = trimmed(last.lowerBound, last.upperBound) }
            let endLine = closingLine ?? active.indices.last!
            let node = append(headingLevel.map { .heading(level: $0) } ?? .paragraph,
                              range: SourceRange(lines[active.start].range.lowerBound, lines[endLine].range.upperBound),
                              segments: segments, to: active.parent)
            for (position, segment) in segments.enumerated() {
                appendText(segment, to: node)
                if position + 1 < segments.count {
                    let line = lines[active.indices[position]]
                    append(.softBreak, range: SourceRange(line.contentRange.upperBound, line.range.upperBound), to: node)
                }
            }
        case .fenced, .indented:
            var indices = active.indices
            let removal: Int
            let info: String?
            if case .fenced(let fence) = active.kind { removal = fence.indent; info = fence.info }
            else {
                removal = 4
                info = nil
                while let last = indices.last, isBlank(last) { indices.removeLast() }
                if indices.count < active.indices.count,
                   let parent = containers.indices.last { containers[parent].pendingBlank = true }
            }
            var literal = ""
            var segments: [SourceRange] = []
            for index in indices {
                if case .indented = active.kind, isBlank(index) {
                    literal += "\n"
                    segments.append(lines[index].range)
                } else {
                    let content = codeContent(index, removing: removal)
                    literal += content.literal
                    segments.append(content.range)
                }
            }
            let endLine = closingLine ?? indices.last ?? active.start
            append(.codeBlock(info: info, literal: literal),
                   range: SourceRange(lines[active.start].range.lowerBound, lines[endLine].range.upperBound),
                   segments: segments, to: active.parent)
        }
    }

    static func quoteContent(_ line: SourceLine, source: [UInt8]) -> SourceLine? {
        var cursor = SourceCursor(source: source, line: line)
        guard cursor.skipIndentation() <= 3, cursor.byte == 62 else { return nil }
        cursor.advanceASCII()
        if cursor.byte == 32 || cursor.byte == 9 { cursor.consumeIndentation(1) }
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
                var cursor = SourceCursor(source: source, line: view)
                var probe = cursor
                let indent = probe.skipIndentation()
                if indent >= padding { cursor.consumeIndentation(padding) }
                else if acceptsBlank && probe.atEnd { cursor = probe }
                else { return nil }
                view = cursor.view
            }
        }
        return view
    }

    struct ListMarker {
        let style: ListStyle
        let padding: Int
        let content: SourceLine
    }

    func listMarker(_ index: Int, interrupting: Bool) -> ListMarker? {
        var cursor = SourceCursor(source: source, line: lines[index])
        let indent = cursor.skipIndentation()
        guard indent <= 3, let first = cursor.byte else { return nil }
        let markerStart = cursor.offset
        let style: ListStyle
        if [UInt8(42), 43, 45].contains(first) {
            style = .bullet(marker: first)
            cursor.advanceASCII()
        } else if (48...57).contains(first) {
            var digits = 0
            var start = 0
            while let byte = cursor.byte, (48...57).contains(byte), digits < 9 {
                start = start * 10 + Int(byte - 48)
                digits += 1
                cursor.advanceASCII()
            }
            guard let delimiter = cursor.byte, delimiter == 46 || delimiter == 41,
                  !interrupting || start == 1 else { return nil }
            style = .ordered(start: start, delimiter: delimiter)
            cursor.advanceASCII()
        } else { return nil }
        guard cursor.atEnd || cursor.byte == 32 || cursor.byte == 9 else { return nil }
        let width = cursor.offset - markerStart
        var probe = cursor
        let whitespace = probe.skipIndentation()
        if interrupting && probe.atEnd { return nil }
        let padding: Int
        if whitespace >= 1 && whitespace <= 4 && !probe.atEnd {
            padding = indent + width + whitespace
            cursor = probe
        } else {
            padding = indent + width + 1
            cursor.consumeIndentation(1)
        }
        return ListMarker(style: style, padding: padding, content: cursor.view)
    }

    static func sameList(_ lhs: ListStyle, _ rhs: ListStyle) -> Bool {
        switch (lhs, rhs) {
        case (.bullet(let a), .bullet(let b)): a == b
        case (.ordered(_, let a), .ordered(_, let b)): a == b
        default: false
        }
    }
}
