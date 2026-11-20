import GMSetzer
import Testing

struct SourceIndexTests {
    @Test func originalUnicodeAndCRLFRoundTrips() throws {
        let text = "\u{FEFF}ä😀e\u{301}\t中אב\r\n\0x\ry\nz"
        let source = Array(text.utf8), index = SourceIndex(Array(text.utf8))
        #expect(index.utf16Count == text.utf16.count)
        for offset in 0...source.count {
            if let utf16 = index.utf16Offset(atUTF8Offset: offset) {
                #expect(index.utf8Offset(atUTF16Offset: utf16) == offset)
                let position = try #require(index.position(atUTF8Offset: offset))
                #expect(index.utf8Offset(at: position) == offset)
                #expect(index.sourceRange(for: UTF16Range(location: utf16, length: 0)) == SourceRange(offset, offset))
            }
        }
        #expect(index.utf16Offset(atUTF8Offset: 1) == nil) // BOM interior
        #expect(index.utf8Offset(atUTF16Offset: 3) == nil) // emoji surrogate interior
        let cr = try #require(source.firstIndex(of: 13))
        #expect(index.position(atUTF8Offset: cr)?.column == 10)
        #expect(index.position(atUTF8Offset: cr + 1) == nil)
        #expect(index.utf8Offset(atUTF16Offset: text.prefix { $0 != "\r\n" }.utf16.count + 1) == nil)
        #expect(index.position(atUTF8Offset: cr + 2) == SourcePosition(line: 2, column: 1))
        #expect(index.utf8Offset(at: SourcePosition(line: 1, column: 100)) == nil)
        #expect(index.utf8Offset(at: SourcePosition(line: 0, column: 1)) == nil)
        #expect(index.utf16Offset(atUTF8Offset: -1) == nil)
        #expect(index.utf8Offset(atUTF16Offset: Int.max) == nil)
    }

    @Test func maximalInvalidSubpartsAndCheckpoints() {
        let cases: [[UInt8]] = [[0xE1, 0x80], [0xF0, 0x90, 0x80, 65], [0xED, 0xA0, 0x80],
                               [0xC0, 0xAF], [0x80], [0xF4, 0x90, 0x80, 0x80]]
        for bytes in cases {
            let source = Array(repeating: UInt8(97), count: 127) + bytes + Array("😀\r\nend".utf8)
            let index = SourceIndex(source)
            #expect(index.utf16Count == String(decoding: source, as: UTF8.self).utf16.count)
            for offset in 0...source.count {
                if let unit = index.utf16Offset(atUTF8Offset: offset) {
                    #expect(index.utf8Offset(atUTF16Offset: unit) == offset)
                }
            }
        }
        let longLine = SourceIndex(Array((String(repeating: "ä😀", count: 500) + "\r\nend").utf8))
        #expect(longLine.utf8Offset(at: SourcePosition(line: 1, column: 1001)) == 3000)
        #expect(longLine.utf8Offset(at: SourcePosition(line: 1, column: 1002)) == nil)
        #expect(longLine.utf8Offset(at: SourcePosition(line: 2, column: 4)) == 3005)
        let incomplete = SourceIndex([0xE1, 0x80])
        #expect(incomplete.utf16Offset(atUTF8Offset: 1) == nil)
        #expect(incomplete.utf16Offset(atUTF8Offset: 2) == 1)
        #expect(SourceIndex([]).position(atUTF8Offset: 0) == SourcePosition(line: 1, column: 1))
    }

    @Test func arbitraryBytesAgreeWithStandardLibraryReplacementDecoding() {
        var state: UInt64 = 17
        for _ in 0..<500 {
            var bytes: [UInt8] = []
            for _ in 0..<40 {
                state = state &* 6364136223846793005 &+ 1
                bytes.append(UInt8(truncatingIfNeeded: state >> 32))
            }
            let positions = SourceIndex(bytes)
            let tree = DocumentIndex(MarkdownParser().parse(bytes: bytes))
            #expect(positions.utf16Count == String(decoding: bytes, as: UTF8.self).utf16.count)
            for byte in 0...bytes.count {
                #expect((tree.node(atUTF8Offset: byte) != nil) == (positions.utf16Offset(atUTF8Offset: byte) != nil))
                if let units = positions.utf16Offset(atUTF8Offset: byte) {
                    #expect(String(decoding: bytes[..<byte], as: UTF8.self).utf16.count == units)
                    #expect(positions.utf8Offset(atUTF16Offset: units) == byte)
                }
            }
        }
    }

    @Test func outlineAndCaretAffinityUseOriginalNodes() throws {
        let document = MarkdownParser().parse("# A *ä* ![alt](x)\n\n> ### `B`\n\nnext\n")
        let tree = DocumentIndex(document), outline = tree.outline()
        #expect(outline.map(\.title) == ["A ä alt", "B"])
        #expect(outline.map(\.level) == [1, 3])
        #expect(outline[1].parentHeading == outline[0].node)
        #expect(tree.node(atUTF8Offset: document.source.count) == 0)
        #expect(tree.node(atUTF8Offset: 0, affinity: .upstream) == 0)
        #expect(tree.node(atUTF8Offset: 6) == nil) // inside ä
        let end = outline[0].range.upperBound
        #expect(tree.node(atUTF8Offset: end) == 0)
        let previous = try #require(tree.node(atUTF8Offset: end, affinity: .upstream))
        #expect(previous == outline[0].node || tree.ancestors(of: previous).contains(outline[0].node))
    }
}
