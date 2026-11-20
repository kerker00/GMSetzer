public import SetzerSyntax

/// Runs once after blocks and before the future inline phase, in profile order.
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
    internal func applyTransforms(to input: Document) -> Document {
        var document = input
        for active in resolvedTransforms {
            do {
                let result = try active.rule.transform(document)
                let existing = Set(document.nodes.map(\.kind))
                let existingTokens = Set(document.tokens ?? [])
                guard result.source == document.source,
                      result.nodes.allSatisfy({ node in
                          if case .custom(let kind, _, _) = node.data {
                              return existing.contains(kind) || active.descriptor.nodeKinds.contains(kind)
                          }
                          return true
                      }), (result.tokens ?? []).allSatisfy({ token in
                          existingTokens.contains(token) || active.descriptor.owns(token.role)
                      }), (result.tokens == nil) == (document.tokens == nil) else {
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
}
