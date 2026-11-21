import Foundation
import GMSetzer
#if os(Linux)
import Glibc
#endif

func milliseconds(_ duration: Duration) -> Double {
    let parts = duration.components
    return Double(parts.seconds) * 1_000 + Double(parts.attoseconds) / 1e15
}

// Optional Linux instrumentation is loaded only in separate allocator runs.
// All counter lookups happen before the measured parser/renderer operations.
struct AllocationCounter {
    let begin: (@convention(c) () -> Void)?
    let end: (@convention(c) (UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>) -> Void)?
    init() {
        #if os(Linux)
        let handle = dlopen(nil, RTLD_NOW)
        begin = handle.flatMap { dlsym($0, "gm_alloc_begin") }.map {
            unsafeBitCast($0, to: (@convention(c) () -> Void).self)
        }
        end = handle.flatMap { dlsym($0, "gm_alloc_end") }.map {
            unsafeBitCast($0, to: (@convention(c) (UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>) -> Void).self)
        }
        #else
        begin = nil; end = nil
        #endif
    }
    func measure<T>(_ body: () throws -> T) rethrows -> (T, [String: Any]) {
        begin?()
        let start = ContinuousClock.now
        let value = try body()
        let elapsed = milliseconds(start.duration(to: .now))
        var calls: UInt64 = 0, bytes: UInt64 = 0
        end?(&calls, &bytes)
        var metrics: [String: Any] = ["ms": elapsed]
        if begin != nil { metrics["allocation_calls"] = calls; metrics["requested_allocation_bytes"] = bytes }
        return (value, metrics)
    }
}

func corpus(_ name: String, bytes: Int) -> String {
    let unit: String
    switch name {
    case "prose": unit = "A paragraph about a quiet landscape, with *emphasis*, **strong text** and [a link](https://example.com). Words continue across the line to form ordinary prose.\n\n"
    case "small-blocks": unit = "# Heading\n\nx\n\n---\n\n> q\n\n- a\n- b\n\n"
    case "tables": unit = "| Name | Description | Value |\n| :--- | --- | ---: |\n| a | **bold** and `code` | 1 |\n| b | [link](https://example.com) | 2 |\n\n"
    case "long-code":
        let line = "let text = \"<&> ä 😀\" // a single indivisible fenced block\n"
        return "```swift\n" + String(repeating: line, count: max(1, (bytes - 13 + line.utf8.count - 1) / line.utf8.count)) + "```\n"
    case "multibyte": unit = "# 日本語 😀 Überschrift\n\n日本語の文章。 Кириллица, עברית, äöüß, 😀👩🏽‍💻. *強調* und **fett**, [Verweis](https://example.com).\n\n"
    case "extensions":
        var result = "---\ntitle: Measurement\n---\n\n"
        var index = 0
        while result.utf8.count < bytes {
            result += "> [!NOTE]\n> An alert with $x + y$ and a note[^n\(index)].\n\n> [!tip]- Title\n> A callout with **strong text**.\n\n$$\na^2 + b^2 = c^2\n$$\n\n[^n\(index)]: A note with *emphasis* and [link](https://example.com).\n\n"
            index += 1
        }
        return result
    case "mixed": unit = "# Field Notes\n\nA paragraph with *emphasis*, **strong**, `code`, [a link][target], äöü 😀 日本語.\n\n- first item\n- second item\n  - nested item\n\n> A quote with **markup**.\n\n```swift\nlet value = 42\n```\n\n| Column | Value |\n| ------ | ----: |\n| a      | 1     |\n| b      | 2     |\n\n[target]: https://example.com\n\n\n"
    default: fatalError("Unknown corpus: \(name)")
    }
    return String(repeating: unit, count: max(1, (bytes + unit.utf8.count - 1) / unit.utf8.count))
}

func peakRSSKiB() -> Int? {
    #if os(Linux)
    guard let status = try? String(contentsOfFile: "/proc/self/status", encoding: .utf8),
          let line = status.split(separator: "\n").first(where: { $0.hasPrefix("VmHWM:") }) else { return nil }
    return line.split(whereSeparator: { $0 == " " || $0 == "\t" }).dropFirst().first.flatMap { Int($0) }
    #else
    return nil
    #endif
}

let arguments = CommandLine.arguments
let bytes = arguments.count > 1 ? Int(arguments[1]) ?? 0 : 1_000_000
let iterations = arguments.count > 2 ? Int(arguments[2]) ?? 0 : 3
let workload = arguments.count > 3 ? arguments[3] : "mixed"
let syntax = arguments.count > 4 ? arguments[4] : "syntax-off"
let mode = arguments.count > 5 ? arguments[5] : "timing"
guard (1...5_000_000).contains(bytes), (1...9).contains(iterations),
      ["syntax-off", "syntax-on"].contains(syntax),
      ["timing", "parse", "full", "first", "groups", "verify"].contains(mode) else {
    fatalError("Usage: ProgressiveHTMLProbe [bytes: 1...5000000] [iterations: 1...9] [mixed|prose|small-blocks|tables|long-code|multibyte|extensions] [syntax-off|syntax-on] [timing|parse|full|first|groups|verify]")
}
let source = corpus(workload, bytes: bytes)
let implementations = workload == "extensions" ? [Alert.implementation, Callout.implementation,
    FrontMatter.implementation, Footnotes.implementation, Math.implementation] : []
let profile = Profile(name: "probe-\(workload)", extensions:
    (workload == "prose" ? Profile.commonMark.extensions : Profile.gfm.extensions) + implementations.map { ExtensionConfiguration($0.identifier) })
let parser = MarkdownParser(profile: profile, extensions: implementations, collectSyntaxDetails: syntax == "syntax-on")
let math: ContextualHTMLRendererHook = { context in
    Math(context.tree.document, at: context.index).map { .replace("<span class=\"math\">\(HTMLRenderer.escape($0.tex))</span>") }
}
let base = HTMLRenderer(includeSourceRanges: true, sourceAnchorPrefix: "block-",
    hooks: workload == "extensions" ? [FrontMatter.kind: { _, _ in .replace("") }] : [:],
    contextualHooks: workload == "extensions" ? [Math.inlineKind: math, Math.blockKind: math] : [:],
    hookBehavior: .independent)
let footnotes = FootnotesHTMLRenderer(renderer: AdmonitionHTML.renderer(base))
let render: (Document) -> String = workload == "extensions" ? { footnotes.render($0) } : { base.render($0) }
let prepare: (Document) throws -> HTMLRenderPlan = workload == "extensions" ? { try footnotes.prepare($0) } : { try base.prepare($0) }
let counter = AllocationCounter()
var samples: [[String: Any]] = []

@MainActor func sample(_ iteration: Int) throws -> [String: Any] {
    let (document, parseMetrics) = counter.measure { parser.parse(source) }
    var result: [String: Any] = ["parse": parseMetrics, "nodes": document.nodes.count]
    if mode == "parse" { return result }
    if mode == "full" {
        let (html, metrics) = counter.measure { render(document) }
        result["full"] = metrics; result["html_bytes"] = html.utf8.count
        return result
    }
    if mode == "verify" {
        let expected = render(document)
        let plan = try prepare(document)
        var assembled = ""
        try plan.forEachGroup { _, html in assembled += html; return true }
        precondition(assembled == expected, "Grouped HTML differs from full HTML")
        result["exact_html_equal"] = true; result["html_bytes"] = expected.utf8.count
        result["groups"] = plan.groups.count
        return result
    }
    @MainActor func full() {
        let (html, metrics) = counter.measure { render(document) }
        result["full"] = metrics; result["html_bytes"] = html.utf8.count
    }
    @MainActor func grouped() throws {
        let (plan, preparation) = try counter.measure { try prepare(document) }
        let (first, firstMetrics) = try counter.measure {
            try plan.groups.first.map { try plan.renderGroup(at: $0.ordinal) } ?? ""
        }
        result["prepare"] = preparation; result["first"] = firstMetrics
        result["groups"] = plan.groups.count; result["plan_mode"] = String(describing: plan.mode)
        result["first_group_bytes"] = first.utf8.count
        result["largest_group_source_bytes"] = plan.groups.map { $0.sourceRange.count }.max() ?? 0
        result["appendix_groups"] = plan.groups.filter { $0.kind == .appendix }.count
        if mode == "first" { return }
        // Release each later group before requesting the next; never assemble HTML.
        let (restBytes, restMetrics) = try counter.measure {
            var count = 0
            for group in plan.groups.dropFirst() { count += try plan.renderGroup(at: group.ordinal).utf8.count }
            return count
        }
        result["remaining_groups"] = restMetrics
        result["grouped_html_bytes"] = first.utf8.count + restBytes
    }
    if mode == "timing" && iteration % 2 == 0 { full(); try grouped(); result["order"] = "full-first" }
    else { try grouped(); if mode == "timing" { full(); result["order"] = "groups-first" } }
    if let fullBytes = result["html_bytes"] as? Int, let groupBytes = result["grouped_html_bytes"] as? Int {
        precondition(fullBytes == groupBytes)
    }
    return result
}

// Timing warmup is excluded. Fresh-process memory/allocation modes have no warmup.
if mode == "timing" { _ = try sample(-1) }
for iteration in 0..<iterations { samples.append(try sample(iteration)) }
var record: [String: Any] = ["corpus": "progressive-\(workload)-v2", "requested_source_bytes": bytes,
    "source_bytes": source.utf8.count, "iterations": iterations, "mode": mode,
    "syntax_details": syntax == "syntax-on", "profile": workload == "prose" ? "commonmark" : "gfm",
    "m5_extensions": implementations.map { $0.identifier }, "source_ranges": true,
    "source_anchor_prefix": "block-", "group_source_budget": 32_768,
    "allocation_interposition": counter.begin != nil, "samples": samples]
if let rss = peakRSSKiB() { record["process_peak_rss_kib"] = rss }
let json = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys, .prettyPrinted])
print(String(decoding: json, as: UTF8.self))
