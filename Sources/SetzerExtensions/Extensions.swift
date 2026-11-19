public import SetzerParser

/// Syntax extensions beyond CommonMark: GFM (tables, task lists,
/// strikethrough, extended autolinks), footnotes, front matter, math,
/// alerts and callouts. They arrive from milestone M4 on.
extension Profile {
    /// GitHub Flavored Markdown.
    public static let gfm = Profile(name: "gfm")
}
