import GMSetzer
@testable import SetzerParser
import Synchronization
import Testing

struct InlineBufferTests {
    @Test func decodingSlicesRespectOffsetsAndDecodeOnlyOnce() {
        let cases: [(String, Bool, Bool, String)] = [
            ("&amp;amp;", true, true, "&amp;"),
            ("\\&amp;", true, true, "&amp;"),
            ("&bsol;*", true, true, "\\*"),
            ("\\* &amp;", false, true, "\\* &"),
            ("\\* &amp;", true, false, "* &amp;"),
            ("\\* &amp;", false, false, "\\* &amp;"),
            ("&#x1F600; &NotEqualTilde;", true, true, "😀 ≂̸"),
            ("&#0; &#xD800; &missing; &amp", true, true, "� � &missing; &amp"),
            ("e\u{301} 日本語\0", true, true, "e\u{301} 日本語�"),
        ]
        for (text, escapes, entities, expected) in cases {
            let raw = Array(text.utf8)
            for offset in [0, 1, 7, 31] {
                let bytes = [UInt8](repeating: 38, count: offset) + raw + Array("&amp;\0".utf8)
                let actual = InlineDecoding.decode(bytes[offset..<(offset + raw.count)], escapes: escapes, entities: entities)
                #expect(actual.utf8.elementsEqual(expected.utf8))
            }
            #expect(InlineDecoding.decode(raw, escapes: escapes, entities: entities).utf8.elementsEqual(expected.utf8))
            #expect(InlineDecoding.decode(text, escapes: escapes, entities: entities).utf8.elementsEqual(expected.utf8))
        }
        for offset in [0, 3, 32] {
            let bytes = [UInt8](repeating: 97, count: offset) + [0xff, 0, 0xc0, 0xaf, 38, 97, 109, 112, 59]
            #expect(InlineDecoding.decode(bytes[offset...]).utf8.elementsEqual("����&".utf8))
            #expect(InlineDecoding.decode(bytes[offset..<offset]).isEmpty)
        }
    }

    @Test func referenceLabelsKeepASCIIAndUnicodeFoldingRules() {
        let cases = [
            (" \tABC\r\n DEF \t", "abc def"),
            ("AZaz09 _-\\&AMP;", "azaz09 _-\\&amp;"),
            ("A\u{000B}B\u{000C}C", "a\u{000B}b\u{000C}c"),
            ("\t\r\n ", ""),
            ("Straße İ Σς", "strasse i\u{307} σσ"),
            ("É E\u{301} A\u{00A0}B", "é e\u{301} a\u{00A0}b"),
        ]
        for (input, expected) in cases {
            #expect(InlineDecoding.label(input).bytes == Array(expected.utf8))
        }
    }

    @Test func retainedInlineContextsKeepBytesAndProjectionAcrossLeafReuse() throws {
        let retained = Mutex<[(InlineContext, String, [SourceRange])]>([])
        let rule = InlineRule("observe", trigger: 36) { context in
            let range = SourceRange(0, context.input.count)
            retained.withLock {
                $0.append((context, String(decoding: context.input, as: UTF8.self),
                           context.originalRanges(for: range) ?? []))
            }
            return nil
        }
        let profile = Profile(name: "observe", extensions: [ExtensionConfiguration("test")])
        let parser = try MarkdownParser(profile: profile,
            extensions: [MarkdownExtension("test", nodeKinds: [], inlineRules: [rule])],
            collectSyntaxDetails: true).validated()
        let source = "> $" + String(repeating: "e\u{301}😀", count: 128)
            + "\r\n> continued\r\n\r\n$short\r\n\r\n- $last *emphasis*\r\n"
        let document = parser.parse(source)
        #expect(document.diagnostics.isEmpty)
        retained.withLock { records in
            #expect(records.count == 3)
            if records.count == 3 {
                // A retained short callback snapshot must not inherit the
                // allocation capacity of an earlier much larger leaf.
                #expect(records[1].0.input.capacity < records[0].0.input.count / 2)
            }
            for (context, expected, ranges) in records {
                #expect(context.input.elementsEqual(expected.utf8))
                #expect(context.source == Array(source.utf8))
                #expect(!ranges.isEmpty)
                #expect(context.originalRanges(for: SourceRange(0, context.input.count)) == ranges)
            }
        }
    }
}
