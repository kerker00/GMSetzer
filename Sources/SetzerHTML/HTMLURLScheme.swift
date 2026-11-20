/// An explicit URI scheme permitted in generated links/images. Relative URLs
/// are independent of this set. Names are ASCII-validated and case-insensitive.
public struct HTMLURLScheme: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init?(rawValue: String) {
        let bytes = Array(rawValue.utf8)
        guard let first = bytes.first, (65...90).contains(first) || (97...122).contains(first),
              bytes.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) ||
                  (48...57).contains($0) || $0 == 43 || $0 == 45 || $0 == 46 }) else { return nil }
        self.rawValue = String(decoding: bytes.map { (65...90).contains($0) ? $0 + 32 : $0 }, as: UTF8.self)
    }
    public static let http = HTMLURLScheme(rawValue: "http")!
    public static let https = HTMLURLScheme(rawValue: "https")!
    public static let mailto = HTMLURLScheme(rawValue: "mailto")!
    public static let tel = HTMLURLScheme(rawValue: "tel")!
    public static let ftp = HTMLURLScheme(rawValue: "ftp")!
}
