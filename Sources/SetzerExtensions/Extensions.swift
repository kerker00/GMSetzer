public import SetzerParser

extension Profile {
    /// GitHub Flavored Markdown as pinned by the GFM 0.29 corpus: tables, task
    /// lists, strikethrough, extended autolinks, the tag filter and GitHub's
    /// nested-strong rendering. Each feature can be selected on its own.
    public static let gfm = Profile(name: "gfm", extensions: BuiltinExtension.allCases.map {
        ExtensionConfiguration($0.rawValue)
    })
}
