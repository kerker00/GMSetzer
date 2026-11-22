import GMSetzer

let source = "# Hello\n\n- [x] Built with Swift"
let document = MarkdownParser(profile: .gfm).parse(source)
let html = HTMLRenderer().render(document)

precondition(html.contains("<h1>Hello</h1>"))
precondition(html.contains("type=\"checkbox\""))
print(html)
