/// The seven CommonMark HTML block start/end classes. Recognition is distinct
/// from rendering permission; a recognised HTML block is escaped by default.
public enum HTMLBlockKind: Hashable, Sendable {
    case rawText, comment, processingInstruction, declaration, cdata, blockTag, completeTag
}

/// Recognised CommonMark HTML block content; recognition grants no rendering
/// permission. Original byte positions remain on its owning node.
public struct HTMLBlock: Hashable, Sendable {
    public let kind: HTMLBlockKind
    /// Container prefixes removed and line endings normalised to LF.
    public let literal: String

    public init(kind: HTMLBlockKind, literal: String) {
        self.kind = kind
        self.literal = literal
    }
}
