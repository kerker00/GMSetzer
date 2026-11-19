/// Deterministic Markdown documents for benchmarks: a realistic mix of
/// headings, paragraphs with emphasis, links and code, lists, quotes, code
/// blocks and tables, repeated up to the requested size.
public enum Corpus {
    public static let block = """
    # Field Notes

    A paragraph with *emphasis*, **strong text**, `inline code` and a [link](https://example.com "Title"). It wraps
    over several lines and mentions an e-mail <someone@example.com> and some_snake_case words.

    ## Lists

    - first item
    - second item with **bold**
      - nested item
    1. ordered
    2. list

    > A quote with *emphasis*
    > over two lines.

    ```swift
    let value = 42
    print(value)
    ```

    | Column | Value |
    | ------ | ----: |
    | a      | 1     |
    | b      | 2     |

    Umlauts äöü, emoji 😀, CJK 日本語 and right-to-left עברית text.


    """

    /// A document of at least `bytes` UTF-8 bytes.
    public static func document(bytes: Int) -> String {
        let unit = block.utf8.count
        return String(repeating: block, count: max(1, (bytes + unit - 1) / unit))
    }
}
