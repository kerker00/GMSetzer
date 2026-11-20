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
    case custom(ActiveRule)
    var identifier: String {
        switch self { case .core(let rule): rule.rawValue; case .custom(let rule): rule.identifier }
    }
}

internal struct RuleRegistry: Sendable {
    let opening: [RegisteredBlockRule]
    let leaves: [CoreBlockRule]
    let transforms: [ActiveTransform]
    let custom: [ActiveRule]
    let enabled: UInt16
    let issues: [ConfigurationIssue]

    func contains(_ rule: CoreBlockRule) -> Bool { enabled & rule.bit != 0 }

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
            for identifier in item.blockRules.map(\.identifier) + item.transforms.map(\.identifier) {
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
        var opening: [RegisteredBlockRule] = custom.map { .custom($0) } + Self.core.opening.filter {
            if case .core(let rule) = $0 { return !profile.disabledRules.contains(rule.rawValue) }
            return true
        }
        var leaves = Self.core.leaves.filter { !profile.disabledRules.contains($0.rawValue) }
        var ranks: [String: Int] = [:]
        let orderable = Set(opening.map(\.identifier) + leaves.map(\.rawValue))
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
                let left = ranks[$0.element.identifier] ?? Int.max
                let right = ranks[$1.element.identifier] ?? Int.max
                return left == right ? $0.offset < $1.offset : left < right
            }.map(\.element)
            leaves = leaves.enumerated().sorted {
                let left = ranks[$0.element.rawValue] ?? Int.max
                let right = ranks[$1.element.rawValue] ?? Int.max
                return left == right ? $0.offset < $1.offset : left < right
            }.map(\.element)
        }
        self.opening = opening
        self.leaves = leaves
        self.enabled = CoreBlockRule.allCases.reduce(UInt16(0)) { value, rule in
            profile.disabledRules.contains(rule.rawValue) ? value : value | rule.bit
        }
        self.issues = issues
    }

    private init(opening: [RegisteredBlockRule], leaves: [CoreBlockRule], custom: [ActiveRule], transforms: [ActiveTransform],
                 enabled: UInt16, issues: [ConfigurationIssue]) {
        self.opening = opening; self.leaves = leaves; self.custom = custom
        self.transforms = transforms
        self.enabled = enabled; self.issues = issues
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
