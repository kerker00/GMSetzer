import GMSetzer

/// Authored scaling inputs. IDs version the input shape independently of the
/// existing mixed/reference corpora. Generation performs no parsing/rendering.
public enum HardeningWorkload: String, CaseIterable, Sendable {
    case composedM5 = "m5-composed-v1"
    case repeatedFootnotes = "footnotes-repeated-v1"
    case openBrackets = "open-brackets-v1"
    case emphasis = "long-emphasis-v1"
    case unmatchedBackticks = "unmatched-backticks-v1"
    case nesting = "quote-overflow-v1"
    case invalidUTF8 = "invalid-utf8-v1"

    public var usesExtensions: Bool { self == .composedM5 || self == .repeatedFootnotes }
    public var profileName: String {
        switch self {
        case .composedM5: "gfm-all-m5"
        case .repeatedFootnotes: "gfm-footnotes"
        default: "commonmark"
        }
    }

    public func source(minimumBytes: Int) -> [UInt8] {
        precondition((1...1_048_576).contains(minimumBytes))
        var bytes: [UInt8] = []
        bytes.reserveCapacity(minimumBytes + 2_048)
        switch self {
        case .composedM5:
            bytes += Array("---\ntitle: Scaling ä😀\n---\n\n".utf8)
            var index = 0
            repeat {
                let block = """
                # Section \(index)

                Text $x + y$ and a note[^n\(index)].

                > [!NOTE]
                > Alert with **markup**.

                > [!tip]- Title $z$
                > Folded callout body.

                | Name | Value |
                | --- | ---: |
                | ä😀 | 1 |

                $$
                a^2 + b^2
                $$

                ```math
                c + d
                ```

                [^n\(index)]: Note with *emphasis* and [link](https://example.com).


                """
                bytes.append(contentsOf: block.utf8)
                index += 1
            } while bytes.count < minimumBytes
        case .repeatedFootnotes:
            bytes += Array("# Shared note\n\n".utf8)
            let suffix = Array("\n[^shared]: One **shared** note.\n".utf8)
            repeat { bytes += Array("Note[^shared] again[^shared].\n".utf8) }
            while bytes.count + suffix.count < minimumBytes
            bytes += suffix
        case .openBrackets:
            bytes += Array("x ".utf8)
            bytes += Array(repeating: 91, count: max(1, minimumBytes - bytes.count))
        case .emphasis:
            // A multiple of three avoids the rule-of-three rejection. Unequal
            // long runs produce many nested strong nodes and residual text.
            let width = max(3, ((minimumBytes + 5) / 6) * 3)
            bytes += Array("x ".utf8)
            bytes += Array(repeating: 42, count: width)
            bytes.append(97)
            bytes += Array(repeating: 42, count: width - 1)
            bytes += Array("z\n".utf8)
        case .unmatchedBackticks:
            bytes += Array("ticks ".utf8)
            var width = 1
            repeat {
                bytes += Array(repeating: 96, count: width)
                bytes.append(120)
                width += 1
            } while bytes.count < minimumBytes
        case .nesting:
            let unit = Array((String(repeating: "> ", count: 256) + "body\n\n").utf8)
            repeat { bytes += unit } while bytes.count < minimumBytes
        case .invalidUTF8:
            bytes += Array("invalid ".utf8)
            let unit: [UInt8] = [0xff, 0x80, 0xc0, 0xaf, 32, 0, 32, 0xf0, 0x9f, 0x98, 13, 10]
            repeat { bytes += unit } while bytes.count < minimumBytes
        }
        return bytes
    }

    public func parser(collectSyntaxDetails: Bool) throws -> MarkdownParser {
        let implementations: [MarkdownExtension]
        switch self {
        case .composedM5:
            implementations = [FrontMatter.implementation, Footnotes.implementation,
                Math.implementation, Alert.implementation, Callout.implementation]
        case .repeatedFootnotes: implementations = [Footnotes.implementation]
        default: implementations = []
        }
        let profile = usesExtensions
            ? Profile(name: profileName, extensions: Profile.gfm.extensions
                + implementations.map { ExtensionConfiguration($0.identifier) })
            : .commonMark
        return try MarkdownParser(profile: profile, extensions: implementations,
            collectSyntaxDetails: collectSyntaxDetails).validated()
    }

    /// Safe composed output; escaped placeholder math, no formula engine.
    public var renderer: FootnotesHTMLRenderer {
        let math: ContextualHTMLRendererHook = { context in
            Math(context.tree.document, at: context.index).map {
                .replace("<span class=\"math\">\(HTMLRenderer.escape($0.tex))</span>")
            }
        }
        return FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(HTMLRenderer(
            hooks: [FrontMatter.kind: { _, _ in .replace("") }],
            contextualHooks: [Math.inlineKind: math, Math.blockKind: math], hookBehavior: .independent)))
    }
}
