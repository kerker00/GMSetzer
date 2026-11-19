public import SetzerSyntax

/// Renders a `Document` as HTML.
///
/// Safe by default: raw HTML in the source is written as text unless the
/// caller allows it. Milestone M0: renders nothing yet; the renderer grows
/// with the parser.
public struct HTMLRenderer: Sendable {
    public init() {}

    public func render(_ document: Document) -> String {
        ""
    }
}
