# Native analysis messages

> Historical record, archived during 1.0 documentation consolidation. Status,
> counts and plans below describe their original checkpoint. Current contracts
> and workflow are in the [package guide](../README.md) and
> [development handbook](../Development.md).

Merged in PR #17 (`0434ff5`) after v0.4.0; included in the v0.5.0 preview.
`SetzerAnalysis` supplies an optional, Foundation-free
English/German catalogue for the three native findings and their whitespace
fix title. Consumers choose the language explicitly or translate the same
documented keys in their own presentation layer.

## Presentation without reanalysis

```swift
import GMSetzer

let document = MarkdownParser().parse("# Start\n\n### Next\n")
let report = try NativeAnalyzer.analyze(document,
    configuration: NativeAnalysisConfiguration(rules: [.headingLevel]))
if let finding = report.findings.first {
    let text = NativeAnalysisMessages.text(for: finding.message, languageTag: "de-DE")
    // Überschrift überspringt eine Ebene (höchstens Ebene 2 erwartet).
}
```

Call the same function on `fix.message` for a suggested fix title. Choosing a
language does not parse again, modify a finding/fix, change source ranges or
apply an edit. It is not an analysis configuration option and does not change
`NativeAnalysisConfiguration.identity`. The caller owns locale preferences,
UI updates and any cache of presented strings; include the selected language
in such a presentation cache.

There is no `Locale.current`, global language setting, resource bundle,
Foundation import or runtime dependency. Lookup uses the case-insensitive
primary BCP 47 language subtag: `en`, `en-US`, `EN-gb` select English; `de`,
`de-DE`, `DE-ch` select German. Regions do not select separate translations.
The function is not a complete language-tag validator or locale negotiation
service. Empty/unsupported language identifiers and underscore-style identifiers
such as `de_DE` return the message's exact `defaultText`.

## Stable key and argument catalogue

These keys and the names, types and meaning of required arguments form the
consumer translation contract. Additional keys/arguments may be added; an
existing key or required argument must not be repurposed. Display wording may
improve without changing finding identity or meaning. Argument values are
portable `SyntaxValue` values, not text extracted from an English sentence.

| Message key | Required arguments | English text / `defaultText` | German text |
| --- | --- | --- | --- |
| `gmsetzer.heading-level` | `maximumLevel`: `.integer`, 1…6; highest allowed level at this heading, previous heading level + 1, initially 1 | Heading skips a level (expected at most {maximumLevel}). | Überschrift überspringt eine Ebene (höchstens Ebene {maximumLevel} erwartet). |
| `gmsetzer.duplicate-heading` | None | Heading repeats an earlier heading. | Überschrift wiederholt eine frühere Überschrift. |
| `gmsetzer.trailing-whitespace` | None | Trailing whitespace has no Markdown meaning. | Leerraum am Zeilenende hat keine Markdown-Bedeutung. |
| `gmsetzer.remove-trailing-whitespace` | None; suggested fix title | Remove trailing whitespace. | Leerraum am Zeilenende entfernen. |

The braces above document interpolation; the API returns the final plain
string. English default text remains byte-for-byte compatible with v0.4.0.
`heading-level` now includes `maximumLevel` in `DiagnosticMessage.arguments`;
the other messages keep empty argument dictionaries. Parser/provider development
identity is bumped to `0.4.1-dev` because this result metadata changed. This is
not a newly published version tag.

Unknown keys, missing `maximumLevel`, a non-integer value or a value outside
1…6 return the original `defaultText`. Additional arguments are ignored. Old
v0.4.0 heading messages have no structured maximum and therefore keep their
original English text; the lookup does not infer numbers by parsing it.
Other providers' keys are not translated by this catalogue. Lookup never
changes a message key, arguments, the original English fallback, severity,
locations, related locations, fixes or report stamps.

## Validation

`NativeAnalysisMessagesTests` covers the complete finding/fix catalogue,
unchanged English defaults, original-byte fix application, actual heading
sequence arguments, regional/case-insensitive language selection, unsupported
language fallback, unknown keys, missing/wrong-type/out-of-range arguments,
v0.4.0 compatibility and additional consumer metadata. Existing analysis and
both protected specification corpora remain part of the full suite.

Validation on 20 November 2026, branch based on `39055ba`:

| Platform / compiler | Commands | Result |
| --- | --- | --- |
| macOS ARM64 / Apple Swift 6.4.2 (Xcode 27.2) | `swift test`; `swift build -c release` | 123 tests pass (116 library tests, 7 spec/fixture tests); optimized build passes |
| macOS ARM64 / Swift 6.2 | `swift test --disable-xctest` with the compatible SDK/Testing runtime described in [Portability](Portability.md) | All 123 tests pass |
| Existing Linux x86-64 host / Swift 6.4.2 | `swift test`; `swift build -c release` | All 123 tests and optimized build pass |

All runs retain 652/652 CommonMark and 672/672 GFM examples. macOS commands
used `--disable-sandbox` and isolated scratch/cache/config/security/module
directories. Linux ran a source-only copy of this package in a separate
temporary directory; no consumer checkout or new execution environment was
needed. Five new tests cover this step; script tests were not repeated because
no scripts changed. Consumer UI adoption and fresh benchmark/reference series
are not claimed by these local checks. At that implementation-validation stage, no new tag or release was published.

At branch completion, the [PR CI](https://github.com/kerker00/GMSetzer/actions/runs/44785845210)
Linux/Swift 6.2 job also passes; the GitHub macOS job is queued. The
[merged-main CI](https://github.com/kerker00/GMSetzer/actions/runs/44786023211)
is still running. The local macOS runs above are completed evidence and do not
substitute for a completed GitHub macOS job.

Subsequently, that merged-main CI run completed successfully on both
macOS/Swift 6.2.3 and Linux/Swift 6.2, superseding the pending CI status above.
