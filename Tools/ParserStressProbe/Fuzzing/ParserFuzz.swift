import GMSetzer

// Standalone libFuzzer entry point. Compile with coverage instrumentation and
// assertions enabled; this is not part of the package's CLI executable target.
@_cdecl("LLVMFuzzerTestOneInput")
public func fuzzParser(_ data: UnsafePointer<UInt8>?, _ count: Int) -> Int32 {
    guard count <= 4_096 else { return 0 }
    let bytes = Array(UnsafeBufferPointer(start: data, count: count))
    let extensions = [FrontMatter.implementation, Footnotes.implementation, Math.implementation,
                      Alert.implementation, Callout.implementation]
    let profiles = [Profile.commonMark, .gfm,
        Profile(name: "commonmark-m5", extensions: extensions.map { ExtensionConfiguration($0.identifier) }),
        Profile(name: "gfm-m5", extensions: Profile.gfm.extensions + extensions.map { ExtensionConfiguration($0.identifier) })]
    let renderer = FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(HTMLRenderer()))
    for (index, profile) in profiles.enumerated() {
        let implementations: [MarkdownExtension] = index < 2 ? [] : extensions
        let plain = try! MarkdownParser(profile: profile, extensions: implementations).validated().parse(bytes: bytes)
        let annotated = try! MarkdownParser(profile: profile, extensions: implementations,
            collectSyntaxDetails: true).validated().parse(bytes: bytes)
        precondition(plain.source == bytes && annotated.source == bytes)
        precondition(plain.nodes == annotated.nodes && plain.diagnostics == annotated.diagnostics)
        precondition(plain.customLeafFallbacks == annotated.customLeafFallbacks
            && plain.renderingPolicy == annotated.renderingPolicy)
        precondition(!annotated.diagnostics.contains {
            if case .invalidExtensionResult = $0.code { return true }
            return false
        })
        _ = try! Document(source: annotated.source, nodes: annotated.nodes, diagnostics: annotated.diagnostics,
            customLeafFallbacks: annotated.customLeafFallbacks, tokens: annotated.tokens,
            renderingPolicy: annotated.renderingPolicy)
        precondition(SourceIndex(annotated).utf16Count == String(decoding: bytes, as: UTF8.self).utf16.count)
        let expected = renderer.render(plain)
        precondition(renderer.render(annotated) == expected)
        let plan = try! renderer.prepare(annotated, maximumSourceBytesPerGroup: 64)
        let groups = plan.groups.reversed().map { ($0.ordinal, try! plan.renderGroup(at: $0.ordinal)) }
        precondition(groups.sorted { $0.0 < $1.0 }.map(\.1).joined() == expected)
    }
    return 0
}
