public import SetzerSyntax

/// Runs in profile order, before inlines when registered in `transforms`, or
/// after inline resolution when registered in `postInlineTransforms`.
/// The result must be a validated tree over the exact same bytes. This supports
/// callout/alert recognition without making the block recogniser own inlines.
public struct BlockTransform: Sendable {
    public let identifier: String
    public let transform: @Sendable (Document) throws -> Document

    public init(_ identifier: String, transform: @escaping @Sendable (Document) throws -> Document) {
        self.identifier = identifier
        self.transform = transform
    }
}

internal struct ActiveTransform: Sendable {
    let identifier: String
    let descriptor: ExtensionDescriptor
    let rule: BlockTransform
}

extension MarkdownParser {
    internal func applyTransforms(to input: Document, afterInlines: Bool = false) -> Document {
        var document = input
        for active in afterInlines ? resolvedPostInlineTransforms : resolvedTransforms {
            do {
                let result = try active.rule.transform(document)
                let existing = Set(document.nodes.map(\.kind))
                guard result.source == document.source,
                      result.nodes.allSatisfy({ node in
                          if case .custom(let kind, _, _) = node.data {
                              return existing.contains(kind) || active.descriptor.nodeKinds.contains(kind)
                          }
                          return true
                      }), preservesForeignTokens(result, from: document, descriptor: active.descriptor),
                      (result.tokens == nil) == (document.tokens == nil) else {
                    document = document.reportingInvalidExtension(active.identifier)
                    continue
                }
                document = result
            } catch {
                document = document.reportingInvalidExtension(active.identifier)
            }
        }
        return document
    }

    /// A rebuilt tree may remap owners. Foreign spelling and multiplicity
    /// remain bounded by the input; Document validates each new owner/range.
    private func preservesForeignTokens(_ result: Document, from input: Document,
                                        descriptor: ExtensionDescriptor) -> Bool {
        var available: [TransformTokenSpelling: Int] = [:]
        for token in input.tokens ?? [] where !descriptor.owns(token.role) {
            available[TransformTokenSpelling(token), default: 0] += 1
        }
        for token in result.tokens ?? [] where !descriptor.owns(token.role) {
            let key = TransformTokenSpelling(token)
            guard let count = available[key], count > 0 else { return false }
            available[key] = count - 1
        }
        return true
    }
}

private struct TransformTokenSpelling: Hashable {
    let role: String
    let range: SourceRange
    init(_ token: SyntaxToken) { role = token.role; range = token.range }
}
