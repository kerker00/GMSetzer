# Select extensions

Use one profile to describe selected grammar and provide implementations separately.

## Profiles and implementations

`Profile.commonMark` is strict CommonMark. `Profile.gfm` selects all shipped
GFM features; the core implements them, so no separate implementation objects
are needed. Other extensions require both a profile selection and a supplied
implementation. Supplying an implementation alone never selects it.

```swift
import GMSetzer

let implementations = [FrontMatter.implementation,
                       Footnotes.implementation, Alert.implementation]
let profile = Profile(name: "writing", extensions: Profile.gfm.extensions +
    implementations.map { ExtensionConfiguration($0.identifier) })
let parser = MarkdownParser(profile: profile, extensions: implementations)
let html = try MarkdownHTML.render("Text[^a].\n\n[^a]: A note.", parser: parser)
```

The same parser profile selects the standard footnote and admonition HTML
recipes in `MarkdownHTML`. Use `FootnotesHTMLRenderer` and `AdmonitionHTML`
directly to localise titles/backlinks, namespace note identifiers, or prepare
progressive output. Those recipes own their selected extension node kinds;
custom presentation should compose the lower-level renderers directly.

## Validate configuration

`MarkdownParser.validated()` throws for unavailable extensions, invalid
options, duplicate identifiers and other configuration issues. `MarkdownHTML`
always validates first. Direct `parse` remains tolerant and exposes
`configurationIssues`; callers must inspect these when using that path.

Profiles can disable named rules and order selected rules. Keep configuration
identity with any cached result; a profile name alone does not identify its
grammar. A `MarkdownDialect` value is a report identity, not an extension switch.

## Extension boundaries

Front matter preserves raw YAML/TOML bytes without deserialising. Math preserves
opaque TeX; the package includes no TeX renderer or script loader. Custom rules
must obey the source projection, ownership, namespacing and validation contracts.
Caller callbacks are trusted code; parser depth limits cannot bound their work.

Front matter retains its existing escaped-text fallback in HTML. To omit
metadata, pass an explicit renderer hook:

```swift
let renderer = HTMLRenderer(hooks: [FrontMatter.kind: { _, _ in .replace("") }])
let html = try MarkdownHTML.render(source, parser: parser, renderer: renderer)
```
