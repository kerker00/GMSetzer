import SetzerSyntax

// M1-C executable API draft. Package-only until M2 integrates core inline
// rules with delimiter resolution; this file does not parse inline syntax.
internal struct InlineContextDraft: Sendable {
    internal let source: [UInt8]
    internal let content: SourceRange
    internal let offset: Int
    internal let protected: Bool
    internal let canOpen: Bool
    internal let canClose: Bool
    internal let runLength: Int
    internal let openers: [DelimiterHandleDraft]
}

/// A value handle, not mutable access to the core's delimiter stack. M2 owns
/// lifetimes and determines eligible handles after code/escape/link handling.
internal struct DelimiterHandleDraft: Hashable, Sendable {
    internal let owner: String
    internal let offset: Int
    internal let width: Int
}

internal enum DelimiterRequestDraft: Sendable {
    case none
    case open(width: Int)
    case close(DelimiterHandleDraft, width: Int)
}

internal struct InlineMatchDraft: Sendable {
    internal let consumed: Int
    internal let data: NodeData
    internal let children: SourceRange?
    internal let delimiter: DelimiterRequestDraft
    internal let tokens: [BlockToken]
}

internal enum InlineContractDraft {
    /// The core must validate before committing either nodes or stack changes.
    /// Subtraction before addition prevents overflow from malformed callbacks.
    internal static func accepts(_ match: InlineMatchDraft, context: InlineContextDraft,
                                descriptor: ExtensionDescriptor) -> Bool {
        guard !context.protected, context.content.upperBound <= context.source.count,
              context.offset >= context.content.lowerBound, context.offset <= context.content.upperBound,
              match.consumed > 0, match.consumed <= context.content.upperBound - context.offset,
              case .custom(let kind, .inline, _) = match.data,
              descriptor.owns(kind.name), descriptor.nodeKinds.contains(kind) else { return false }
        let range = SourceRange(context.offset, context.offset + match.consumed)
        if let children = match.children, !range.contains(children) { return false }
        guard match.tokens.allSatisfy({ descriptor.owns($0.role) && range.contains($0.range) }) else { return false }
        switch match.delimiter {
        case .none: return true
        case .open(let width): return context.canOpen && width > 0 && width <= context.runLength && width <= match.consumed
        case .close(let opener, let width):
            return context.canClose && width > 0 && width <= context.runLength && width <= match.consumed
                && width <= opener.width && opener.owner == descriptor.identifier
                && opener.offset < context.offset && context.openers.contains(opener)
        }
    }
}
