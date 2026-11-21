public import SetzerExtensions
public import SetzerHTML

/// Optional, CSS-neutral HTML policy for parsed alerts and callouts. Use the
/// returned renderer directly or pass it to FootnotesHTMLRenderer.
public enum AdmonitionHTML {
    public static func renderer(_ base: HTMLRenderer = HTMLRenderer(),
                                alertTitles: [Alert.Category: String] = [:],
                                calloutTitles: [String: String] = [:]) -> HTMLRenderer {
        base.addingContextualHooks([
            Alert.kind: { context in
                guard let alert = Alert(context.tree.document, at: context.index) else { return nil }
                let type = alert.category.rawValue.lowercased()
                let title = HTMLRenderer.escape(alertTitles[alert.category] ?? alert.category.defaultTitle)
                let anchors = anchors(context, includeRanges: base.includeSourceRanges)
                return .wrapChildren(open: "<aside class=\"markdown-alert markdown-alert-\(type)\" role=\"note\"\(anchors)>\n<p class=\"markdown-alert-title\">\(title)</p>\n",
                    close: "</aside>\n")
            },
            Callout.kind: { context in
                guard let callout = Callout(context.tree.document, at: context.index) else { return nil }
                let title: String
                if let container = callout.titleNode,
                   let paragraph = context.tree.document.nodes[container].firstChild {
                    title = context.renderChildren(of: paragraph)
                } else { title = HTMLRenderer.escape(calloutTitles[callout.type] ?? callout.title) }
                let anchors = anchors(context, includeRanges: base.includeSourceRanges)
                let attributes = " class=\"callout callout-\(callout.style)\" data-callout=\"\(HTMLRenderer.escape(callout.type))\"\(anchors)"
                if callout.fold == .none {
                    return .wrapChildren(open: "<aside\(attributes)>\n<div class=\"callout-title\">\(title)</div>\n",
                        close: "</aside>\n")
                }
                let open = callout.fold == .expanded ? " open" : ""
                return .wrapChildren(open: "<details\(attributes)\(open)>\n<summary class=\"callout-title\">\(title)</summary>\n",
                    close: "</details>\n")
            },
            Callout.titleKind: { _ in .replace("") },
        ], independent: true)
    }

    private static func anchors(_ context: HTMLRendererContext, includeRanges: Bool) -> String {
        let id = context.sourceAnchorID.map { " id=\"\(HTMLRenderer.escape($0))\"" } ?? ""
        guard includeRanges else { return id }
        return id + " data-source-start=\"\(context.node.range.lowerBound)\" data-source-end=\"\(context.node.range.upperBound)\""
    }
}
