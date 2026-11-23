public import SetzerParser
public import SetzerHTML
import SetzerExtensions

/// Parses Markdown and renders HTML using one parser configuration.
///
/// The default parser uses CommonMark. The default renderer escapes raw HTML,
/// omits comments and rejects dangerous URL schemes. Selected footnotes,
/// alerts and callouts receive their standard HTML presentation automatically.
/// Math remains opaque text unless a caller provides a rendering hook.
///
/// Use the separate parser and renderer APIs when you need to retain a syntax
/// tree, run analysis, localise extension titles or prepare progressive output.
public enum MarkdownHTML {
    /// Renders a string with the supplied parser and HTML policy.
    ///
    /// Configuration is validated before parsing. Providing an implementation
    /// to a parser does not select it: its profile must select the identifier.
    /// Caller-provided renderer hooks return trusted HTML and are not sanitised.
    /// The standard footnote/admonition recipes own their selected node kinds.
    ///
    /// - Parameters:
    ///   - source: The complete Markdown document.
    ///   - parser: The profile, extension implementations, limits and token policy.
    ///   - renderer: The HTML policy and any custom rendering hooks.
    /// - Returns: An HTML fragment, without a page shell or stylesheet.
    /// - Throws: A configuration error if the parser cannot honour its profile.
    public static func render(_ source: String, parser: MarkdownParser = MarkdownParser(),
                              renderer: HTMLRenderer = HTMLRenderer()) throws -> String {
        try render(bytes: Array(source.utf8), parser: parser, renderer: renderer)
    }

    /// Renders original UTF-8 bytes, retaining the parser's replacement policy.
    ///
    /// Malformed sequences are preserved in the temporary document's source;
    /// literals use replacement decoding. A leading BOM is ignored for syntax.
    /// Validation and HTML trust boundaries match the string overload.
    ///
    /// - Parameters:
    ///   - bytes: The complete original source, including any malformed UTF-8.
    ///   - parser: The profile, extension implementations, limits and token policy.
    ///   - renderer: The HTML policy and any custom rendering hooks.
    /// - Returns: An HTML fragment, without a page shell or stylesheet.
    /// - Throws: A configuration error if the parser cannot honour its profile.
    public static func render(bytes: [UInt8], parser: MarkdownParser = MarkdownParser(),
                              renderer: HTMLRenderer = HTMLRenderer()) throws -> String {
        let document = try parser.validated().parse(bytes: bytes)
        let selected = Set(parser.profile.extensions.map(\.identifier))
        let base = selected.contains(Alert.identifier) || selected.contains(Callout.identifier)
            ? AdmonitionHTML.renderer(renderer) : renderer
        if selected.contains(Footnotes.identifier) {
            return FootnotesHTMLRenderer(renderer: base).render(document)
        }
        return base.render(document)
    }
}
