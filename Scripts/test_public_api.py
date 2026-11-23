import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("check_public_api", Path(__file__).with_name("check_public_api.py"))
api = importlib.util.module_from_spec(spec)
spec.loader.exec_module(api)


class PublicAPICompatibilityTests(unittest.TestCase):
    def setUp(self):
        self.entry = {"path": ["Renderer", "render(_:)"], "kind": "swift.method",
                      "declaration": "func render(_ source: String) -> String", "conformances": []}
        self.before = {"Example": {"render": self.entry}}

    def test_an_additive_method_does_not_invalidate_existing_clients(self):
        after = {"Example": {"render": self.entry, "prepare": dict(self.entry, path=["Renderer", "prepare(_:)"])}}
        self.assertEqual(api.incompatibilities(self.before, after), [])

    def test_a_removed_method_is_reported(self):
        self.assertEqual(api.incompatibilities(self.before, {"Example": {}}),
                         ["Removed: Example/Renderer.render(_:)"])

    def test_a_new_throwing_requirement_is_reported(self):
        after = {"Example": {"render": dict(self.entry, declaration="func render(_ source: String) throws -> String")}}
        self.assertEqual(api.incompatibilities(self.before, after), ["Changed: Example/Renderer.render(_:)"])

    def test_losing_a_protocol_conformance_is_reported(self):
        before = {"Example": {"render": dict(self.entry, conformances=["Sendable"])}}
        self.assertEqual(api.incompatibilities(before, self.before),
                         ["Lost conformance: Example/Renderer.render(_:)"])

    def test_an_added_enum_case_breaks_existing_exhaustive_switches(self):
        enum = dict(self.entry, path=["Mode"], kind="swift.enum", declaration="enum Mode")
        before = {"Example": {"mode": enum}}
        after = {"Example": {"mode": enum, "new": dict(self.entry, path=["Mode", "new"], kind="swift.enum.case")}}
        self.assertEqual(api.incompatibilities(before, after), ["Added case to existing enum: Example/Mode.new"])

    def test_a_foreign_type_context_is_not_a_removed_public_type(self):
        key = "s:4Core7ProfileV"
        entry = dict(self.entry, path=["Profile"], kind="swift.struct", declaration="struct Profile")
        block = dict(entry, kind="swift.extension", declaration="extension Profile")
        before = {"Core": {key: entry}, "Extras": {"extension": block, "gfm": self.entry}}
        current = {"Core": {key: entry}, "Extras": {"gfm": self.entry}}
        self.assertEqual(api.incompatibilities(before, current), [])

    def test_normalisation_still_rejects_removing_an_extension_member(self):
        key = "s:4Core7ProfileV"
        entry = dict(self.entry, path=["Profile"], kind="swift.struct", declaration="struct Profile")
        block = dict(entry, kind="swift.extension", declaration="extension Profile")
        before = {"Core": {key: entry}, "Extras": {"extension": block, "gfm": self.entry}}
        current = {"Core": {key: entry}, "Extras": {}}
        self.assertEqual(api.incompatibilities(before, current), ["Removed: Extras/Renderer.render(_:)"])

    def test_normalisation_still_rejects_removing_the_defining_type(self):
        key = "s:4Core7ProfileV"
        entry = dict(self.entry, path=["Profile"], kind="swift.struct", declaration="struct Profile")
        block = dict(entry, kind="swift.extension", declaration="extension Profile")
        before = {"Core": {key: entry}, "Extras": {"extension": block}}
        self.assertEqual(api.incompatibilities(before, {"Core": {}, "Extras": {}}), ["Removed: Core/Profile"])

    def test_legacy_sendable_display_needs_exact_source_evidence(self):
        old = dict(self.entry, declaration="typealias Hook = @Sendable (Input) -> Output")
        new = dict(old, declaration="typealias Hook = (Input) -> Output")
        self.assertFalse(api.same_declaration(old, new))
        new["source_declaration"] = "public typealias Hook = @Sendable (Input) -> Output"
        self.assertTrue(api.same_declaration(old, new))
        new["source_declaration"] = "public typealias Hook = (Input) -> Output"
        self.assertFalse(api.same_declaration(old, new))

    def test_sendable_cannot_move_to_a_different_callback_parameter(self):
        old = dict(self.entry, declaration="init(first: @Sendable () -> Void, second: () -> Void)")
        new = dict(old, declaration="init(first: () -> Void, second: () -> Void)",
                   source_declaration="public init(first: () -> Void, second: @Sendable () -> Void)")
        self.assertFalse(api.same_declaration(old, new))

    def test_a_body_annotation_cannot_stand_in_for_the_signature(self):
        lines = ["public init(", "    action: @escaping () -> Void", ") {", "    let work: @Sendable () -> Void", "}"]
        header = api.declaration_source(lines, 0)
        self.assertNotIn("@Sendable", header)
        old = dict(self.entry, declaration="init(action: @escaping @Sendable () -> Void)")
        new = dict(old, declaration="init(action: @escaping () -> Void)", source_declaration=header)
        self.assertFalse(api.same_declaration(old, new))


if __name__ == "__main__":
    unittest.main()
