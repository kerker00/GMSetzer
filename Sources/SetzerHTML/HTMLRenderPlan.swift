public import SetzerSyntax

/// Hooks default to document-order execution. Opt into independent groups
/// only when every supplied hook is deterministic and has no order-dependent
/// effects. Returned markup must also remain inside the rendered block.
public enum HTMLHookBehavior: Equatable, Sendable {
    case documentOrder
    case independent
}

/// Rejected grouping configuration or a group ordinal outside the plan.
public enum HTMLRenderPlanError: Error, Equatable, Sendable {
    case invalidGroupSize
    case invalidGroupIndex(Int)
}

/// A complete, insertable output group. Ordinals and node indices belong to
/// this plan's immutable document, not to later edits of the source.
public struct HTMLRenderGroup: Hashable, Sendable {
    /// Normal document blocks or a composed extension appendix.
    public enum Kind: Hashable, Sendable { case body, appendix }
    public let ordinal: Int
    public let kind: Kind
    public let sourceRange: SourceRange
    public let nodeIndices: [Int]
}

/// Prepared complete-document context with pull-based HTML output. Preparing
/// does not render hooks, blocks or appendices. Only the requested group is
/// materialised; callers control consumption, scheduling and result lifetime.
public struct HTMLRenderPlan: Sendable {
    /// Whether independently requested structural groups or a single
    /// whole-document fallback preserve the configured output contract.
    public enum Mode: Equatable, Sendable {
        case structural
        case wholeDocument(Fallback)
    }
    /// Why complete-document HTML emission is required for this renderer.
    public enum Fallback: Equatable, Sendable {
        /// Source HTML may open a wrapper in one block and close it in another.
        case rawHTML
        case documentHook
        case documentOrderHooks
    }

    public let groups: [HTMLRenderGroup]
    public let mode: Mode
    /// A soft source-byte budget, not an HTML-byte or memory limit. A block
    /// larger than this budget remains indivisible and is reported as such.
    public let maximumSourceBytesPerGroup: Int
    private let document: Document
    private let renderer: HTMLRenderer
    private let tree: DocumentIndex?
    private let appendix: (@Sendable (_ checkpoint: () throws -> Void) throws -> String)?

    package init(document: Document, renderer: HTMLRenderer, tree: DocumentIndex? = nil,
                 maximumSourceBytesPerGroup: Int,
                 omittingTopLevelKinds: Set<NodeKind> = [],
                 appendix: (@Sendable (_ checkpoint: () throws -> Void) throws -> String)? = nil) throws {
        guard maximumSourceBytesPerGroup > 0 else { throw HTMLRenderPlanError.invalidGroupSize }
        self.document = document
        self.renderer = renderer
        self.tree = renderer.needsContextIndex ? (tree ?? DocumentIndex(document)) : tree
        self.maximumSourceBytesPerGroup = maximumSourceBytesPerGroup
        self.appendix = appendix
        if let fallback = renderer.groupFallback {
            mode = .wholeDocument(fallback)
            groups = [HTMLRenderGroup(ordinal: 0, kind: .body, sourceRange: document.root.range, nodeIndices: [0])]
            return
        }
        mode = .structural
        var result: [HTMLRenderGroup] = []
        var nodes: [Int] = []
        var lower = 0, upper = 0
        func flush() {
            guard !nodes.isEmpty else { return }
            result.append(HTMLRenderGroup(ordinal: result.count, kind: .body,
                                          sourceRange: SourceRange(lower, upper), nodeIndices: nodes))
            nodes = []
        }
        for node in document.children(of: 0) {
            let kind = document.nodes[node].kind
            if omittingTopLevelKinds.contains(kind) || (kind == .referenceDefinition && renderer.omitsReferenceDefinitions) { continue }
            let range = document.nodes[node].range
            let nextLower = nodes.isEmpty ? range.lowerBound : min(lower, range.lowerBound)
            let nextUpper = nodes.isEmpty ? range.upperBound : max(upper, range.upperBound)
            if !nodes.isEmpty && nextUpper - nextLower > maximumSourceBytesPerGroup { flush() }
            if nodes.isEmpty { lower = range.lowerBound; upper = range.upperBound }
            else { lower = min(lower, range.lowerBound); upper = max(upper, range.upperBound) }
            nodes.append(node)
        }
        flush()
        if appendix != nil {
            result.append(HTMLRenderGroup(ordinal: result.count, kind: .appendix,
                                          sourceRange: document.root.range, nodeIndices: []))
        }
        groups = result
    }

    /// Returns one group using global context, regardless of request order.
    /// The checkpoint may throw, for example Task.checkCancellation(). It is
    /// called between renderer events; a single literal or caller hook is
    /// indivisible. Parsing has already completed before this plan exists.
    public func renderGroup(at ordinal: Int, checkpoint: () throws -> Void = {}) throws -> String {
        guard groups.indices.contains(ordinal) else { throw HTMLRenderPlanError.invalidGroupIndex(ordinal) }
        try checkpoint()
        let group = groups[ordinal]
        var html: String
        switch group.kind {
        case .body:
            html = try renderer.renderNodes(document, nodes: group.nodeIndices, tree: tree, checkpoint: checkpoint)
            if case .wholeDocument = mode, let appendix { html += try appendix(checkpoint) }
        case .appendix:
            html = try appendix?(checkpoint) ?? ""
        }
        try checkpoint()
        return html
    }

    /// Visits in document order with no producer queue. Return false to stop
    /// after the current group. Returns the number handed to the consumer.
    @discardableResult
    public func forEachGroup(checkpoint: () throws -> Void = {},
                             _ consume: (HTMLRenderGroup, String) throws -> Bool) throws -> Int {
        var count = 0
        for group in groups {
            let html = try renderGroup(at: group.ordinal, checkpoint: checkpoint)
            count += 1
            guard try consume(group, html) else { break }
        }
        return count
    }
}
