public import GMSetzer

extension Corpus {
    /// Selected no-op rule measures shared registry dispatch. The mixed corpus
    /// has no NUL triggers; configuration is resolved outside timed iterations.
    public static func registryParser() -> MarkdownParser {
        let implementation = MarkdownExtension("benchmark", nodeKinds: [], blockRules: [
            BlockRule("noop", trigger: 0) { _ in nil },
        ])
        return MarkdownParser(profile: Profile(name: "registry-probe", extensions: [ExtensionConfiguration("benchmark")]),
                              extensions: [implementation])
    }

    /// Selected inline no-op rule is actually invoked on underscores in the
    /// mixed corpus, then defers to the core emphasis controller.
    public static func inlineRegistryParser() -> MarkdownParser {
        let implementation = MarkdownExtension("benchmark", nodeKinds: [], inlineRules: [
            InlineRule("inlineNoop", trigger: 95) { _ in nil },
        ])
        return MarkdownParser(profile: Profile(name: "inline-registry-probe", extensions: [ExtensionConfiguration("benchmark")]),
                              extensions: [implementation])
    }
}
