public import SetzerParser

extension Profile {
    /// GFM's explicit selection. Its implementations arrive in M4; until then
    /// the parser reports unavailable rules in `MarkdownParser.configurationIssues`.
    public static let gfm = Profile(name: "gfm", extensions: [
        ExtensionConfiguration("gfm.table"),
        ExtensionConfiguration("gfm.tasklist"),
        ExtensionConfiguration("gfm.strikethrough"),
        ExtensionConfiguration("gfm.autolink"),
        ExtensionConfiguration("gfm.tagfilter"),
    ])
}
