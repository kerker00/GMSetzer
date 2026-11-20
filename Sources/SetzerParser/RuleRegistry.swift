import SetzerSyntax

/// Stable rule identities. Continuation/definition rules share configuration
/// with opening rules; fallback paragraphs remain indispensable core behavior.
public enum CoreBlockRule: String, CaseIterable, Sendable {
    case blockQuote = "core.blockQuote", list = "core.list"
    case indentedCode = "core.indentedCode", fencedCode = "core.fencedCode"
    case atxHeading = "core.atxHeading", thematicBreak = "core.thematicBreak"
    case htmlBlock = "core.htmlBlock", setextHeading = "core.setextHeading"
    case referenceDefinition = "core.referenceDefinition"

    var bit: UInt16 {
        switch self {
        case .blockQuote: 1
        case .list: 2
        case .indentedCode: 4
        case .fencedCode: 8
        case .atxHeading: 16
        case .thematicBreak: 32
        case .htmlBlock: 64
        case .setextHeading: 128
        case .referenceDefinition: 256
        }
    }
}

internal enum RegisteredBlockRule: Sendable {
    case core(CoreBlockRule)
    case custom(Int)
}

internal struct RuleRegistry: Sendable {
    let opening: [RegisteredBlockRule]
    let leaves: [CoreBlockRule]
    let transforms: [ActiveTransform]
    let custom: [ActiveRule]
    let enabled: UInt16
    let issues: [ConfigurationIssue]
    /// First bytes for which an active custom rule may interrupt a paragraph.
    let interruptTriggers: ByteSet
    var inlineRules: [ActiveInlineRule] = []
    var postInlineTransforms: [ActiveTransform] = []

    func contains(_ rule: CoreBlockRule) -> Bool { enabled & rule.bit != 0 }
    @inline(__always)
    func mayInterrupt(_ byte: UInt8) -> Bool { interruptTriggers.contains(byte) }

    static let core = RuleRegistry(opening: [.core(.blockQuote), .core(.list)],
        leaves: [.indentedCode, .fencedCode, .atxHeading, .thematicBreak, .htmlBlock],
        custom: [], transforms: [], enabled: UInt16.max, issues: [])

    init(profile: Profile, extensions: [MarkdownExtension]) {
        if profile.extensions.isEmpty && profile.disabledRules.isEmpty && profile.ruleOrder.isEmpty && extensions.isEmpty {
            self = .core
            return
        }
        var issues: [ConfigurationIssue] = []
        var implementations: [String: MarkdownExtension] = [:]
        for item in extensions {
            if implementations[item.identifier] != nil {
                issues.append(ConfigurationIssue(.duplicateIdentifier, identifier: item.identifier))
            } else { implementations[item.identifier] = item }
        }
        var selected = Set<String>()
        var custom: [ActiveRule] = []
        var transforms: [ActiveTransform] = []
        var claimedKinds = Set<NodeKind>()
        var claimedRules = Set<String>()
        var known = Set(CoreBlockRule.allCases.map(\.rawValue))
        for item in extensions {
            for identifier in item.blockRules.map(\.identifier) + item.transforms.map(\.identifier) + item.inlineRules.map(\.identifier) + item.postInlineTransforms.map(\.identifier) {
                known.insert(Self.qualified(identifier, owner: item.identifier))
            }
        }
        for rule in profile.disabledRules.sorted() where !known.contains(rule) {
            issues.append(ConfigurationIssue(.unknownRule, identifier: rule))
        }
        for selection in profile.extensions {
            guard selected.insert(selection.identifier).inserted else {
                issues.append(ConfigurationIssue(.duplicateIdentifier, identifier: selection.identifier)); continue
            }
            guard let implementation = implementations[selection.identifier] else {
                issues.append(ConfigurationIssue(.unavailableExtension, identifier: selection.identifier)); continue
            }
            let descriptor = implementation.descriptor
            guard Self.validIdentifier(descriptor.identifier), descriptor.identifier != "core",
                  !descriptor.identifier.hasPrefix("core."), !descriptor.version.isEmpty else {
                issues.append(ConfigurationIssue(.invalidDescriptor, identifier: descriptor.identifier)); continue
            }
            guard descriptor.nodeKinds.allSatisfy({ descriptor.owns($0.name) && !NodeKind.builtins.contains($0) }) else {
                issues.append(ConfigurationIssue(.namespaceViolation, identifier: descriptor.identifier)); continue
            }
            guard claimedKinds.isDisjoint(with: descriptor.nodeKinds) else {
                issues.append(ConfigurationIssue(.duplicateIdentifier, identifier: descriptor.identifier)); continue
            }
            claimedKinds.formUnion(descriptor.nodeKinds)
            var options: [String: SyntaxValue] = [:]
            for (key, spec) in descriptor.options.sorted(by: { $0.key < $1.key }) {
                if key.isEmpty || (spec.type != .integer && spec.integerRange != nil)
                    || !(spec.allowedValues?.allSatisfy(spec.accepts) ?? true) {
                    issues.append(ConfigurationIssue(.invalidOption, identifier: descriptor.identifier, detail: key))
                }
                if let value = spec.defaultValue {
                    if spec.accepts(value) { options[key] = value }
                    else { issues.append(ConfigurationIssue(.invalidOption, identifier: descriptor.identifier, detail: key)) }
                }
            }
            for (key, value) in selection.options.sorted(by: { $0.key < $1.key }) {
                guard let spec = descriptor.options[key] else {
                    issues.append(ConfigurationIssue(.unknownOption, identifier: descriptor.identifier, detail: key)); continue
                }
                guard spec.accepts(value) else {
                    issues.append(ConfigurationIssue(.invalidOption, identifier: descriptor.identifier, detail: key)); continue
                }
                options[key] = value
            }
            for rule in implementation.blockRules {
                let identifier = Self.qualified(rule.identifier, owner: descriptor.identifier)
                guard Self.validIdentifier(identifier), descriptor.owns(identifier) else {
                    issues.append(ConfigurationIssue(.namespaceViolation, identifier: identifier)); continue
                }
                guard claimedRules.insert(identifier).inserted else {
                    issues.append(ConfigurationIssue(.duplicateIdentifier, identifier: identifier)); continue
                }
                if profile.disabledRules.contains(identifier) { continue }
                custom.append(ActiveRule(rule: rule, options: options, order: custom.count,
                    descriptor: descriptor, identifier: identifier))
            }
            for rule in implementation.inlineRules {
                let identifier = Self.qualified(rule.identifier, owner: descriptor.identifier)
                guard Self.validIdentifier(identifier), descriptor.owns(identifier) else {
                    issues.append(ConfigurationIssue(.namespaceViolation, identifier: identifier)); continue
                }
                guard claimedRules.insert(identifier).inserted else {
                    issues.append(ConfigurationIssue(.duplicateIdentifier, identifier: identifier)); continue
                }
                if !profile.disabledRules.contains(identifier) {
                    inlineRules.append(ActiveInlineRule(rule: rule, identifier: identifier, descriptor: descriptor,
                                                        options: options, order: inlineRules.count))
                }
            }
            for rule in implementation.postInlineTransforms {
                let identifier = Self.qualified(rule.identifier, owner: descriptor.identifier)
                guard Self.validIdentifier(identifier), descriptor.owns(identifier) else {
                    issues.append(ConfigurationIssue(.namespaceViolation, identifier: identifier)); continue
                }
                guard claimedRules.insert(identifier).inserted else {
                    issues.append(ConfigurationIssue(.duplicateIdentifier, identifier: identifier)); continue
                }
                if !profile.disabledRules.contains(identifier) {
                    postInlineTransforms.append(ActiveTransform(identifier: identifier, descriptor: descriptor, rule: rule))
                }
            }
            for rule in implementation.transforms {
                let identifier = Self.qualified(rule.identifier, owner: descriptor.identifier)
                guard Self.validIdentifier(identifier), descriptor.owns(identifier) else {
                    issues.append(ConfigurationIssue(.namespaceViolation, identifier: identifier)); continue
                }
                guard claimedRules.insert(identifier).inserted else {
                    issues.append(ConfigurationIssue(.duplicateIdentifier, identifier: identifier)); continue
                }
                if !profile.disabledRules.contains(identifier) {
                    transforms.append(ActiveTransform(identifier: identifier, descriptor: descriptor, rule: rule))
                }
            }
        }
        self.transforms = transforms
        custom.sort { $0.rule.priority == $1.rule.priority ? $0.order < $1.order : $0.rule.priority > $1.rule.priority }
        self.custom = custom
        var opening: [RegisteredBlockRule] = custom.indices.map { .custom($0) } + Self.core.opening.filter {
            if case .core(let rule) = $0 { return !profile.disabledRules.contains(rule.rawValue) }
            return true
        }
        var leaves = Self.core.leaves.filter { !profile.disabledRules.contains($0.rawValue) }
        var ranks: [String: Int] = [:]
        func identifier(_ entry: RegisteredBlockRule) -> String {
            switch entry { case .core(let rule): rule.rawValue; case .custom(let index): custom[index].identifier }
        }
        let orderable = Set(opening.map(identifier) + leaves.map(\.rawValue) + inlineRules.map(\.identifier))
        for identifier in profile.ruleOrder {
            guard orderable.contains(identifier) else {
                issues.append(ConfigurationIssue(.unknownRule, identifier: identifier)); continue
            }
            guard ranks[identifier] == nil else {
                issues.append(ConfigurationIssue(.duplicateIdentifier, identifier: identifier)); continue
            }
            ranks[identifier] = ranks.count
        }
        if !ranks.isEmpty {
            opening = opening.enumerated().sorted {
                let left = ranks[identifier($0.element)] ?? Int.max
                let right = ranks[identifier($1.element)] ?? Int.max
                return left == right ? $0.offset < $1.offset : left < right
            }.map(\.element)
            leaves = leaves.enumerated().sorted {
                let left = ranks[$0.element.rawValue] ?? Int.max
                let right = ranks[$1.element.rawValue] ?? Int.max
                return left == right ? $0.offset < $1.offset : left < right
            }.map(\.element)
        }
        inlineRules.sort {
            let left = ranks[$0.identifier] ?? Int.max
            let right = ranks[$1.identifier] ?? Int.max
            if left != right { return left < right }
            return $0.rule.priority == $1.rule.priority ? $0.order < $1.order : $0.rule.priority > $1.rule.priority
        }
        self.opening = opening
        self.leaves = leaves
        self.enabled = CoreBlockRule.allCases.reduce(UInt16(0)) { value, rule in
            profile.disabledRules.contains(rule.rawValue) ? value : value | rule.bit
        }
        self.issues = issues
        self.interruptTriggers = Self.interruptTriggers(custom)
    }

    /// A rule without a trigger byte may match any line.
    private static func interruptTriggers(_ rules: [ActiveRule]) -> ByteSet {
        var set = ByteSet()
        for active in rules where active.rule.interruptsParagraph {
            if let trigger = active.rule.trigger { set.insert(trigger) } else { return ByteSet(all: true) }
        }
        return set
    }

    private init(opening: [RegisteredBlockRule], leaves: [CoreBlockRule], custom: [ActiveRule], transforms: [ActiveTransform],
                 enabled: UInt16, issues: [ConfigurationIssue]) {
        self.opening = opening; self.leaves = leaves; self.custom = custom
        self.transforms = transforms
        self.enabled = enabled; self.issues = issues
        self.interruptTriggers = Self.interruptTriggers(custom)
    }

    private static func validIdentifier(_ value: String) -> Bool {
        value.utf8.split(separator: 46, omittingEmptySubsequences: false).allSatisfy { part in
            !part.isEmpty && part.allSatisfy { byte in
                (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 95 || byte == 45
            }
        }
    }

    private static func qualified(_ identifier: String, owner: String) -> String {
        identifier.contains(".") || identifier == owner ? identifier : owner + "." + identifier
    }
}

/// A 256-bit membership table for byte dispatch.
internal struct ByteSet: Sendable {
    private var words: (UInt64, UInt64, UInt64, UInt64)

    init(all: Bool = false) {
        let word: UInt64 = all ? .max : 0
        words = (word, word, word, word)
    }

    mutating func insert(_ byte: UInt8) {
        let bit = UInt64(1) << UInt64(byte & 63)
        switch byte >> 6 {
        case 0: words.0 |= bit
        case 1: words.1 |= bit
        case 2: words.2 |= bit
        default: words.3 |= bit
        }
    }

    @inline(__always)
    func contains(_ byte: UInt8) -> Bool {
        let word: UInt64
        switch byte >> 6 {
        case 0: word = words.0
        case 1: word = words.1
        case 2: word = words.2
        default: word = words.3
        }
        return word & (UInt64(1) << UInt64(byte & 63)) != 0
    }
}
